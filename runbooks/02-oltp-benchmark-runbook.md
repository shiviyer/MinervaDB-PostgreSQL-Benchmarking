# OLTP Benchmark Runbook
## MinervaDB PostgreSQL Benchmarking Toolkit

**Document Type:** Runbook  
**Benchmark Type:** OLTP (Online Transaction Processing)  
**Tools:** pgbench, sysbench, HammerDB (TPC-C)  
**PostgreSQL Versions:** 15, 16, 17, 18  
**Estimated Time:** 2–4 hours

---

## Table of Contents

1. [Overview & Goals](#1-overview--goals)
2. [Pre-Benchmark Checklist](#2-pre-benchmark-checklist)
3. [Environment Preparation](#3-environment-preparation)
4. [Benchmark Tier 1: Quick TPC-B (pgbench)](#4-benchmark-tier-1-quick-tpc-b-pgbench)
5. [Benchmark Tier 2: sysbench OLTP](#5-benchmark-tier-2-sysbench-oltp)
6. [Benchmark Tier 3: TPC-C (HammerDB)](#6-benchmark-tier-3-tpc-c-hammerdb)
7. [Custom Workload Simulation](#7-custom-workload-simulation)
8. [Result Collection & Analysis](#8-result-collection--analysis)
9. [Interpreting Results](#9-interpreting-results)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Overview & Goals

### What This Runbook Covers

This runbook provides a standardized methodology for OLTP performance benchmarking of PostgreSQL 15-18. Following this runbook ensures:

- **Reproducible results** across different hardware and configurations
- **Comparable metrics** between PostgreSQL versions and configurations
- **Production-realistic workloads** that reflect real application patterns
- **Documented methodology** for audit and review purposes

### Key Metrics Captured

| Metric | Description | Good Target |
|--------|-------------|-------------|
| TPS | Transactions per second (throughput) | Workload-specific |
| P50 Latency | Median response time | < 10ms OLTP |
| P95 Latency | 95th percentile response time | < 50ms OLTP |
| P99 Latency | 99th percentile response time | < 100ms OLTP |
| P99.9 Latency | 99.9th percentile response time | < 500ms OLTP |
| Error Rate | Failed transactions / total | < 0.01% |
| Cache Hit % | Buffer cache hit ratio | > 99% |

### Benchmark Duration Guidelines

| Purpose | Duration | Clients |
|---------|----------|---------|
| Quick smoke test | 60s | 8 |
| Development benchmark | 300s (5 min) | 16-32 |
| CI/CD regression test | 600s (10 min) | 32 |
| Production capacity benchmark | 3600s (1 hour) | Match peak |
| Endurance/soak test | 86400s (24 hours) | Peak load |

---

## 2. Pre-Benchmark Checklist

Complete ALL items before starting:

### Server Preparation
- [ ] OS kernel parameters applied (`bash 00-prerequisites/system-tuning.sh`)
- [ ] THP (Transparent Huge Pages) disabled
- [ ] CPU governor set to `performance`
- [ ] No other workloads running on the server
- [ ] Sufficient disk space (at least 50GB free for data + results)
- [ ] NTP synchronized (for accurate timestamps)

### PostgreSQL Preparation
- [ ] PostgreSQL version verified (`psql --version`)
- [ ] Target postgresql.conf profile applied
- [ ] `pg_stat_statements` extension enabled
- [ ] `pg_stat_io` available (PG 16+)
- [ ] autovacuum configured appropriately
- [ ] CHECKPOINT run immediately before benchmark

### Benchmark Tool Preparation
- [ ] pgbench version verified (`pgbench --version`)
- [ ] sysbench version verified (`sysbench --version`)
- [ ] HammerDB installed at `/opt/HammerDB/` (for TPC-C)
- [ ] Results directory created and writeable
- [ ] Monitoring tools ready (iostat, vmstat, pg_stat_activity)

---

## 3. Environment Preparation

### 3.1 Apply PostgreSQL Configuration

```bash
# For OLTP workloads, use the OLTP-optimized config
# Select the config for your PostgreSQL version:
sudo cp 07-postgresql-configurations/pg16-oltp-optimized.conf \
    /etc/postgresql/16/main/postgresql.conf

# Reload configuration
sudo -u postgres psql -c "SELECT pg_reload_conf();"

# Verify key settings
sudo -u postgres psql -c "
SELECT name, setting, unit
FROM pg_settings
WHERE name IN ('shared_buffers', 'work_mem', 'max_connections', 
               'synchronous_commit', 'wal_buffers', 'checkpoint_completion_target')
ORDER BY name;
"
```

### 3.2 Create Benchmark Database

```bash
# Create benchmark database with optimal settings
sudo -u postgres psql << 'EOF'
CREATE DATABASE benchdb
    WITH ENCODING = 'UTF8'
         LC_COLLATE = 'en_US.UTF-8'
         LC_CTYPE = 'en_US.UTF-8'
         TEMPLATE = template0;

-- Enable pg_stat_statements for query analysis
\c benchdb
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_buffercache;

-- Reset stats for clean baseline
SELECT pg_stat_reset();
SELECT pg_stat_statements_reset();
EOF
```

### 3.3 Validate Connection

```bash
bash 00-prerequisites/environment-validation.sh \
  --host localhost \
  --port 5432 \
  --user postgres \
  --dbname benchdb
```

---

## 4. Benchmark Tier 1: Quick TPC-B (pgbench)

### 4.1 Initialize Database

```bash
# Scale factor guide:
# SF=1: 100K rows (development/smoke test)
# SF=100: 10M rows (standard benchmark)
# SF=1000: 100M rows (large/production-like)

SCALE=100
PGPASSWORD=yourpassword pgbench \
  -h localhost -p 5432 -U postgres \
  --initialize \
  --scale=${SCALE} \
  --foreign-keys \
  benchdb

# Verify data loaded
psql -h localhost -U postgres benchdb -c "
SELECT 
    relname AS table,
    pg_size_pretty(pg_relation_size(relid)) AS size,
    n_live_tup AS rows
FROM pg_stat_user_tables
WHERE relname LIKE 'pgbench%'
ORDER BY relname;
"

# Post-load VACUUM ANALYZE
psql -h localhost -U postgres benchdb -c "
VACUUM ANALYZE pgbench_accounts;
VACUUM ANALYZE pgbench_branches;
VACUUM ANALYZE pgbench_tellers;
CHECKPOINT;
"
```

### 4.2 Run Standard OLTP Benchmark

```bash
bash 01-pgbench/01-tpc-b-oltp/run-tpcb-benchmark.sh \
  --host localhost \
  --scale 100 \
  --clients 32 \
  --threads 8 \
  --duration 300 \
  --output results/oltp/
```

### 4.3 Run Concurrency Sweep

```bash
# Test at multiple client counts to find saturation point
for CLIENTS in 1 2 4 8 16 32 64 128 256; do
    echo "--- Testing ${CLIENTS} clients ---"
    pgbench \
      -h localhost -U postgres \
      -c ${CLIENTS} \
      -j $(( CLIENTS < 16 ? CLIENTS : 16 )) \
      -T 120 \
      --no-vacuum \
      --progress=30 \
      benchdb 2>&1 | grep -E "tps|latency" | tee -a results/concurrency-sweep.txt
    sleep 10
done
```

### 4.4 Read-Only Benchmark

```bash
pgbench \
  -h localhost -U postgres \
  --select-only \
  -c 64 -j 16 -T 300 \
  --progress=30 \
  benchdb
```

---

## 5. Benchmark Tier 2: sysbench OLTP

### 5.1 Prepare sysbench

```bash
# Create sysbench test tables
sysbench oltp_read_write \
  --db-driver=pgsql \
  --pgsql-host=localhost \
  --pgsql-port=5432 \
  --pgsql-user=postgres \
  --pgsql-password=yourpassword \
  --pgsql-db=benchdb \
  --tables=10 \
  --table-size=1000000 \
  prepare
```

### 5.2 Run sysbench Read-Write

```bash
sysbench oltp_read_write \
  --db-driver=pgsql \
  --pgsql-host=localhost \
  --pgsql-port=5432 \
  --pgsql-user=postgres \
  --pgsql-password=yourpassword \
  --pgsql-db=benchdb \
  --tables=10 \
  --table-size=1000000 \
  --threads=32 \
  --time=300 \
  --report-interval=30 \
  --percentile=99 \
  run 2>&1 | tee results/oltp/sysbench-rw-$(date +%Y%m%d-%H%M%S).txt
```

### 5.3 Run sysbench Read-Only

```bash
sysbench oltp_read_only \
  --db-driver=pgsql \
  --pgsql-host=localhost \
  --pgsql-user=postgres \
  --pgsql-password=yourpassword \
  --pgsql-db=benchdb \
  --tables=10 \
  --table-size=1000000 \
  --threads=64 \
  --time=300 \
  --report-interval=30 \
  run
```

---

## 6. Benchmark Tier 3: TPC-C (HammerDB)

TPC-C is the gold standard for OLTP benchmarking. It includes 9 transaction types simulating a warehouse/order management system.

### 6.1 Create TPC-C Schema

```bash
cd /opt/HammerDB
./hammerdb << 'EOF'
dbset db pg
dbset bm TPC-C
diset connection pg_host localhost
diset connection pg_port 5432
diset connection pg_user postgres
diset connection pg_pass yourpassword
diset tpcc pg_count_ware 100
diset tpcc pg_num_vu 8
diset tpcc pg_superuser postgres
diset tpcc pg_superuserpass yourpassword
diset tpcc pg_defaultdbase benchdb
buildschema
waittocomplete
exit
EOF
```

### 6.2 Run TPC-C Benchmark

```bash
bash 03-hammerdb/01-tpc-c/run-tpcc-benchmark.sh \
  --host localhost \
  --warehouses 100 \
  --virtual-users 32 \
  --duration 600 \
  --output results/oltp/
```

---

## 7. Custom Workload Simulation

### 7.1 E-Commerce Simulation

```bash
bash 04-custom-workloads/01-ecommerce-simulation/run-ecommerce-bench.sh \
  --host localhost \
  --clients 50 \
  --duration 300
```

### 7.2 Financial Transactions Simulation

```bash
bash 04-custom-workloads/02-financial-transactions/run-financial-bench.sh \
  --host localhost \
  --clients 32 \
  --duration 300
```

---

## 8. Result Collection & Analysis

### 8.1 Collect PostgreSQL Statistics

```sql
-- Run IMMEDIATELY after benchmark completes

-- Top queries during benchmark
SELECT
    calls,
    round(mean_exec_time::numeric, 2) AS avg_ms,
    round(max_exec_time::numeric, 2) AS max_ms,
    left(query, 80) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- Wait events during benchmark
SELECT
    wait_event_type,
    wait_event,
    count(*) AS count
FROM pg_stat_activity
WHERE state != 'idle'
GROUP BY 1, 2
ORDER BY 3 DESC;

-- Buffer cache efficiency
SELECT
    datname,
    blks_hit,
    blks_read,
    round(blks_hit::numeric / NULLIF(blks_hit + blks_read, 0) * 100, 2) AS cache_hit_pct
FROM pg_stat_database
WHERE datname = 'benchdb';
```

### 8.2 Generate Analysis Report

```bash
python3 tools/result-analyzer.py \
  --input results/oltp/ \
  --type oltp \
  --output reports/

python3 tools/report-generator.py \
  --template reports/templates/benchmark-report-template.md \
  --results-dir results/oltp/ \
  --output reports/oltp-benchmark-$(date +%Y%m%d).md
```

---

## 9. Interpreting Results

### 9.1 TPS Interpretation

```
TPS INTERPRETATION GUIDE
=========================

< 100 TPS    → Very low throughput. Check: connection issues, heavy locking, 
               missing indexes, synchronous_commit=on bottleneck.

100-1,000    → Acceptable for small deployments. Common for 4-8 core servers
               with moderate workloads.

1,000-10,000 → Good performance for mid-tier hardware (16-32 cores, 64-128GB RAM).
               Typical for production OLTP.

10,000-50,000 → High performance. Enterprise-grade hardware, optimized configs,
                possibly PgBouncer in front.

50,000+      → Exceptional. Requires NVMe storage, many cores, large RAM,
               and highly optimized application design.
```

### 9.2 Latency Interpretation

| Latency | Assessment | Action |
|---------|------------|--------|
| P50 < 5ms | Excellent | No action needed |
| P50 5-20ms | Good | Minor tuning possible |
| P50 > 50ms | Concerning | Investigate indexes, query plans |
| P99 < 50ms | Excellent | No action needed |
| P99 50-200ms | Acceptable | Monitor for degradation |
| P99 > 500ms | Problematic | Investigate locking, vacuum, bloat |

### 9.3 Cache Hit Ratio

| Cache Hit % | Assessment |
|------------|------------|
| > 99.9% | Excellent — data fits in memory |
| 99-99.9% | Good — mostly in cache |
| 95-99% | Monitor — some I/O pressure |
| < 95% | Problem — increase shared_buffers or add RAM |

---

## 10. Troubleshooting

### Problem: TPS is much lower than expected

```sql
-- Check for lock waits
SELECT
    blocked.pid,
    blocked.query AS blocked_query,
    blocking.pid AS blocking_pid,
    blocking.query AS blocking_query
FROM pg_stat_activity AS blocked
JOIN pg_stat_activity AS blocking ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE NOT blocked.granted;

-- Check for long-running transactions
SELECT pid, now() - xact_start AS duration, state, query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY xact_start
LIMIT 10;
```

### Problem: High latency variance (high stddev)

- Check for checkpoint I/O spikes: `grep "checkpoint" postgresql.log`
- Check autovacuum interference: `SELECT * FROM pg_stat_progress_vacuum;`
- Verify THP is disabled: `cat /sys/kernel/mm/transparent_hugepage/enabled`

### Problem: High error rate

```sql
-- Check for deadlocks
SELECT deadlocks FROM pg_stat_database WHERE datname = 'benchdb';

-- Check for connection rejections
grep "FATAL" postgresql.log | tail -20
```

---

*MinervaDB PostgreSQL Benchmarking Toolkit | Version 1.0.0 | https://minervadb.com*
