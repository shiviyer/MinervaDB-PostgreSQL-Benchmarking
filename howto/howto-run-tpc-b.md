# How to Run TPC-B Benchmarks
## MinervaDB PostgreSQL Benchmarking Toolkit

**Tool:** pgbench  
**Standard:** TPC-B (Transaction Processing Performance Council Benchmark B)  
**Workload Type:** OLTP  
**PostgreSQL:** 15, 16, 17, 18

---

## What is TPC-B?

TPC-B is a standardized OLTP benchmark that simulates banking transactions. Each transaction consists of:

1. `UPDATE accounts SET abalance = abalance + :delta WHERE aid = :aid`
2. `UPDATE tellers SET tbalance = tbalance + :delta WHERE tid = :tid`
3. `UPDATE branches SET bbalance = bbalance + :delta WHERE bid = :bid`
4. `INSERT INTO history(tid, bid, aid, delta, mtime) VALUES (...)`
5. `SELECT abalance FROM accounts WHERE aid = :aid`

Each transaction touches 4 tables with random row selections — testing index performance, WAL throughput, buffer cache efficiency, and lock management simultaneously.

---

## Prerequisites

### 1. Install pgbench

pgbench is included with PostgreSQL. Verify it's installed:

```bash
pgbench --version
# Expected: pgbench (PostgreSQL) 16.x
```

If not installed:
```bash
# Ubuntu/Debian
sudo apt-get install postgresql-client-16

# RHEL/CentOS
sudo dnf install postgresql16
```

### 2. Create benchmark database

```bash
sudo -u postgres createdb benchdb
```

### 3. Enable extensions (recommended)

```sql
\c benchdb
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_buffercache;
```

---

## Step 1: Choose Your Scale Factor

Scale factor determines database size:

| Scale Factor | pgbench_accounts rows | Approximate size |
|---|---|---|
| 1 | 100,000 | ~15 MB |
| 10 | 1,000,000 | ~150 MB |
| 100 | 10,000,000 | ~1.5 GB |
| 1,000 | 100,000,000 | ~15 GB |
| 10,000 | 1,000,000,000 | ~150 GB |

**Rule:** Choose scale factor so the working set exceeds your `shared_buffers` for a realistic benchmark. If `shared_buffers` = 8GB, use SF ≥ 1000.

---

## Step 2: Initialize the Database

```bash
# Basic initialization
pgbench -h localhost -U postgres --initialize --scale=100 benchdb

# With foreign keys (more realistic, slower init)
pgbench -h localhost -U postgres --initialize --scale=100 --foreign-keys benchdb

# With unlogged tables (fastest init, not durable)
pgbench -h localhost -U postgres --initialize --scale=100 --unlogged-tables benchdb
```

**Verify initialization:**
```sql
SELECT relname, n_live_tup 
FROM pg_stat_user_tables 
WHERE relname LIKE 'pgbench%'
ORDER BY relname;
```

**Post-initialization VACUUM:**
```bash
psql -h localhost -U postgres benchdb -c "
VACUUM ANALYZE pgbench_accounts;
VACUUM ANALYZE pgbench_branches;
VACUUM ANALYZE pgbench_tellers;
CHECKPOINT;
"
```

---

## Step 3: Run the Benchmark

### Quick Test (60 seconds)

```bash
pgbench -h localhost -U postgres \
  -c 16 -j 4 -T 60 \
  --no-vacuum --progress=10 \
  benchdb
```

### Standard OLTP Benchmark (5 minutes)

```bash
pgbench -h localhost -U postgres \
  -c 32 -j 8 -T 300 \
  --no-vacuum --progress=30 \
  benchdb
```

### Production-Grade Benchmark (1 hour)

```bash
pgbench -h localhost -U postgres \
  -c 128 -j 32 -T 3600 \
  --no-vacuum --progress=60 \
  --log --log-prefix=results/pgbench-prod \
  benchdb
```

### Read-Only Benchmark

```bash
pgbench -h localhost -U postgres \
  --select-only \
  -c 64 -j 16 -T 300 \
  --progress=30 \
  benchdb
```

### Using the Toolkit Script

```bash
bash 01-pgbench/01-tpc-b-oltp/run-tpcb-benchmark.sh \
  --host localhost \
  --scale 100 \
  --clients 32 \
  --threads 8 \
  --duration 300 \
  --output results/
```

---

## Step 4: Understanding pgbench Parameters

| Parameter | Description | Recommendation |
|-----------|-------------|----------------|
| `-c N` (--client) | Number of clients | Start with CPU cores * 2 |
| `-j N` (--jobs) | Number of threads | Match physical CPU cores |
| `-T N` (--time) | Duration in seconds | 300s minimum for stable results |
| `--no-vacuum` | Skip vacuum during test | Always use for benchmarks |
| `--progress=N` | Progress report every N seconds | 30-60s for visibility |
| `-s N` (--scale) | Scale factor | See table above |
| `--log` | Write per-transaction log | Use for latency distribution analysis |
| `--sampling-rate` | Sample rate for --log | 0.01 for large benchmarks |

---

## Step 5: Understanding the Output

Sample pgbench output:
```
pgbench (16.2)
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 100
query mode: simple
number of clients: 32
number of threads: 8
maximum number of tries: 1
duration: 300 s
number of transactions actually processed: 1847239
number of failed transactions: 0 (0.000%)
latency average = 5.194 ms
latency stddev = 3.847 ms
initial connection time = 42.981 ms
tps = 6157.268 (without initial connection time)
```

**Key metrics explained:**

- **tps**: Transactions per second — primary throughput metric
- **latency average**: Mean transaction response time
- **latency stddev**: Standard deviation — high stddev = inconsistent performance
- **number of failed transactions**: Should be 0 for a healthy benchmark

---

## Step 6: Collect PostgreSQL Statistics

Run immediately after the benchmark:

```sql
-- Buffer cache hit ratio (should be > 99%)
SELECT 
    datname,
    blks_hit,
    blks_read,
    round(blks_hit::numeric / NULLIF(blks_hit+blks_read,0) * 100, 2) AS cache_hit_pct
FROM pg_stat_database
WHERE datname = 'benchdb';

-- Checkpoint statistics
SELECT
    checkpoints_timed,
    checkpoints_req,
    round(checkpoint_write_time/1000,1) AS write_seconds,
    round(checkpoint_sync_time/1000,1) AS sync_seconds,
    buffers_checkpoint,
    buffers_clean,
    buffers_backend
FROM pg_stat_bgwriter;

-- Top queries
SELECT calls, round(mean_exec_time::numeric,2) AS avg_ms,
       round(max_exec_time::numeric,2) AS max_ms,
       left(query, 80) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC LIMIT 10;
```

---

## Step 7: Concurrency Sweep

Find the saturation point (where more clients don't increase TPS):

```bash
for CLIENTS in 1 2 4 8 16 32 64 128 256; do
    THREADS=$(( CLIENTS < 16 ? CLIENTS : 16 ))
    echo -n "Clients=${CLIENTS}: "
    pgbench -h localhost -U postgres \
        -c ${CLIENTS} -j ${THREADS} -T 120 \
        --no-vacuum benchdb 2>&1 | grep "^tps"
    sleep 5
done
```

---

## Common Scenarios

### Pre/Post Configuration Change Test

```bash
# BEFORE change
pgbench -h localhost -U postgres -c 32 -j 8 -T 300 --no-vacuum benchdb \
    2>&1 | tee results/before-config-change.txt

# Apply configuration change
psql -U postgres -c "ALTER SYSTEM SET shared_buffers = '8GB';"
psql -U postgres -c "SELECT pg_reload_conf();"

# AFTER change
pgbench -h localhost -U postgres -c 32 -j 8 -T 300 --no-vacuum benchdb \
    2>&1 | tee results/after-config-change.txt

# Compare
diff results/before-config-change.txt results/after-config-change.txt
```

### PostgreSQL Version Comparison

```bash
# Run on PG 15
PG_HOST=pg15-server bash 01-pgbench/01-tpc-b-oltp/run-tpcb-benchmark.sh \
    --host pg15-server --scale 100 --clients 32 --output results/pg15/

# Run on PG 16
PG_HOST=pg16-server bash 01-pgbench/01-tpc-b-oltp/run-tpcb-benchmark.sh \
    --host pg16-server --scale 100 --clients 32 --output results/pg16/

# Analyze and compare
python3 tools/result-analyzer.py --input results/ --mode comparison
```

---

## Troubleshooting

### "could not connect to server"
- Verify PostgreSQL is running: `sudo systemctl status postgresql`
- Check pg_hba.conf allows the connection
- Verify PGPASSWORD is set correctly

### Low TPS (much lower than expected)
- Check `synchronous_commit` setting (try `off` for max throughput)
- Verify `shared_buffers` is properly sized
- Check for lock contention: `SELECT * FROM pg_stat_activity WHERE wait_event IS NOT NULL;`
- Verify I/O scheduler (SSD should use `none` or `mq-deadline`)

### High latency variance
- Check for checkpoint I/O spikes in postgresql.log
- Verify THP is disabled
- Check for autovacuum interference: `SELECT * FROM pg_stat_progress_vacuum;`

---

## See Also

- [Runbook: OLTP Benchmark](../runbooks/02-oltp-benchmark-runbook.md)
- [Runbook: Capacity Planning](../runbooks/04-capacity-planning-runbook.md)
- [How To: Analyze Results](howto-analyze-results.md)
- [PostgreSQL Config: pg16-oltp-optimized.conf](../07-postgresql-configurations/pg16-oltp-optimized.conf)

---

*MinervaDB PostgreSQL Benchmarking Toolkit | https://minervadb.com*
