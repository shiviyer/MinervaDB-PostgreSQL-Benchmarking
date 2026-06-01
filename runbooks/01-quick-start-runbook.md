# Quick Start Runbook
## MinervaDB PostgreSQL Benchmarking Toolkit

**Estimated Time:** 15–30 minutes  
**Goal:** Run your first PostgreSQL benchmark and understand the results  
**Difficulty:** Beginner  

---

## What You'll Accomplish

By the end of this runbook, you will have:
- ✅ Cloned and set up the toolkit
- ✅ Validated your PostgreSQL environment
- ✅ Run a standard TPC-B OLTP benchmark
- ✅ Interpreted the results
- ✅ Saved a benchmark report

---

## Prerequisites

Before starting, ensure you have:

- [ ] PostgreSQL 15, 16, 17, or 18 running
- [ ] `psql` command-line client installed
- [ ] `git` installed
- [ ] Sudo/root access (for system tuning)
- [ ] At least 10GB free disk space
- [ ] Network access (for downloading tools)

---

## Step 1: Clone the Toolkit (2 minutes)

```bash
# Clone the repository
git clone https://github.com/shiviyer/MinervaDB-PostgreSQL-Benchmarking.git
cd MinervaDB-PostgreSQL-Benchmarking

# Verify the structure
ls -la
```

**Expected output:**
```
total 84
drwxr-xr-x  15 user user  4096 Jun  1 2026 .
drwxr-xr-x   8 user user  4096 Jun  1 2026 ..
drwxr-xr-x   2 user user  4096 Jun  1 2026 00-prerequisites
drwxr-xr-x   5 user user  4096 Jun  1 2026 01-pgbench
...
-rw-r--r--   1 user user 24576 Jun  1 2026 README.md
```

---

## Step 2: Install Dependencies (5 minutes)

```bash
# Make scripts executable
chmod +x 00-prerequisites/*.sh
chmod +x examples/*.sh
chmod +x tools/*.sh

# Install all required tools
sudo bash 00-prerequisites/install-dependencies.sh

# Expected output:
# [SUCCESS] pgbench: installed
# [SUCCESS] sysbench: installed
# [SUCCESS] Python dependencies installed
```

> **Note:** If pgbench is already installed with PostgreSQL, most dependencies will be skipped.

---

## Step 3: Validate Your Environment (2 minutes)

```bash
# Replace 'localhost' with your PostgreSQL host if different
# Set PGPASSWORD if your PostgreSQL requires a password
export PGPASSWORD="your_postgres_password"

bash 00-prerequisites/environment-validation.sh \
  --host localhost \
  --port 5432 \
  --user postgres \
  --dbname postgres
```

**Expected output:**
```
==================================================================
  MinervaDB PostgreSQL Benchmarking Toolkit
  Environment Validation
==================================================================

--- Benchmark Tools ---
  ✓ pgbench: 16.2
  ✓ psql: 16.2
  ✓ git: 2.39.0
  ✓ python3: 3.10.12
  ✓ jq: 1.6

--- PostgreSQL Connection ---
  ✓ Connection to localhost:5432/postgres: OK
  ✓ PostgreSQL version: 16.2 (supported)

--- PostgreSQL Configuration ---
  ✓ shared_buffers: 2048MB (>= 1GB)
  ✓ max_connections: 200 (adequate)

--- System Configuration ---
  ✓ Total RAM: 64GB (>=16GB recommended)
  ✓ CPU cores: 16
  ✓ Available disk space: 500GB (>=50GB)

  ✓ Environment is fully validated and ready for benchmarking!
```

**If you see FAILED items:** Fix them before proceeding. Common fixes:
- Connection failed: Check PGPASSWORD, pg_hba.conf
- shared_buffers too small: Adjust in postgresql.conf and reload

---

## Step 4: Apply OS Tuning (Optional but Recommended) (2 minutes)

```bash
# Apply OS-level tuning for accurate benchmark results
sudo bash 00-prerequisites/system-tuning.sh

# Key changes:
# - Disables Transparent Huge Pages (THP)
# - Sets CPU governor to 'performance'
# - Optimizes I/O scheduler for your disk type
# - Sets kernel network parameters

# Note: Reboot for full effect, but most settings apply immediately
```

---

## Step 5: Run Your First Benchmark (10 minutes)

```bash
# Create benchmark database
export PGPASSWORD="your_postgres_password"
psql -h localhost -U postgres -c "CREATE DATABASE benchdb;"

# Run the quick OLTP benchmark
# This creates 10 million rows, warms up for 60s, then runs for 5 minutes
bash examples/example-quick-oltp.sh \
  --host localhost \
  --scale 100 \
  --clients 32 \
  --duration 300
```

**You'll see output like:**
```
==================================================================
  MinervaDB PostgreSQL Benchmarking Toolkit
  Quick OLTP Benchmark Example
==================================================================

  PostgreSQL:   localhost:5432/benchdb
  Scale Factor: 100
  Clients:      32
  Duration:     300s
  Results:      results/quick-oltp-20260601-120000

==================================================================
Step 1/5: Validating PostgreSQL connection...
  ✓ Connected successfully
Step 2/5: Initializing benchmark data (scale=100)...
  Creating 10000000 accounts rows...
  ✓ Benchmark data initialized
Step 3/5: Warming up (60 seconds)...
  ✓ Warmup complete
Step 4/5: Resetting PostgreSQL statistics...
  ✓ Statistics reset
Step 5/5: Running OLTP benchmark (300s)...

...progress every 30s...

tps = 8742.135 (without initial connection time)
latency average = 3.660 ms
latency stddev = 2.14 ms
```

---

## Step 6: Understand Your Results (5 minutes)

### Reading TPS (Transactions Per Second)

The most important metric is **TPS**:

```
tps = 8742.135 (without initial connection time)
```

**What this means:**
- Your PostgreSQL server processed **8,742 transactions per second**
- This is a TPC-B transaction (5 SQL statements per transaction)
- So actual SQL operations = 8,742 × 5 = **43,710 SQL/second**

**TPS Reference:**

| TPS Range | Hardware Profile |
|-----------|----------------|
| < 500 | Small VM (2 cores, 4GB RAM) |
| 500 - 2,000 | Development server (4-8 cores) |
| 2,000 - 10,000 | Mid-tier server (16 cores, 64GB) |
| 10,000 - 50,000 | Production server (32+ cores, 128GB+) |
| 50,000+ | Enterprise hardware |

### Reading Latency

```
latency average = 3.660 ms
latency stddev = 2.14 ms
```

- **3.660ms average** = transactions complete in about 3.7ms on average
- **2.14ms stddev** = latency is fairly consistent (stddev < avg is good)

### Reading Cache Hit Ratio

In `results/quick-oltp-*/pg-stats.txt`:
```
cache_hit_pct
--------------
    99.87
```
- **99.87%** = Almost everything is served from memory buffer cache (excellent!)
- If this is below 99%, increase `shared_buffers`

---

## Step 7: Run More Benchmarks

### Quick Read-Only Test

```bash
pgbench -h localhost -U postgres \
  --select-only -c 64 -j 16 -T 120 \
  --no-vacuum --progress=30 \
  benchdb
```

### Full Benchmark Suite

```bash
bash tools/benchmark-orchestrator.sh \
  --host localhost \
  --scale 100 \
  --suite oltp \
  --duration 300
```

### Capacity Planning Sweep

```bash
# Find TPS saturation point across client counts
bash tools/benchmark-orchestrator.sh \
  --host localhost \
  --scale 100 \
  --suite capacity \
  --max-clients 128
```

---

## Step 8: Analyze and Report

```bash
# Analyze all results
python3 tools/result-analyzer.py \
  --input results/ \
  --mode summary

# Generate a markdown report
python3 tools/result-analyzer.py \
  --input results/ \
  --format json \
  --output results/benchmark-data.json
```

---

## Next Steps

Depending on your goal:

| Goal | Next Runbook |
|------|-------------|
| Comprehensive OLTP benchmark | [02-oltp-benchmark-runbook.md](02-oltp-benchmark-runbook.md) |
| Analytics/reporting workloads | [03-olap-benchmark-runbook.md](03-olap-benchmark-runbook.md) |
| Hardware sizing & planning | [04-capacity-planning-runbook.md](04-capacity-planning-runbook.md) |
| Cloud instance selection | [05-cloud-sizing-runbook.md](05-cloud-sizing-runbook.md) |
| Detect performance regressions | [06-performance-regression-runbook.md](06-performance-regression-runbook.md) |
| Pre/post upgrade comparison | [08-postgresql-upgrade-benchmark-runbook.md](08-postgresql-upgrade-benchmark-runbook.md) |

---

## Troubleshooting

### "createdb: database already exists"
```bash
psql -h localhost -U postgres -c "DROP DATABASE IF EXISTS benchdb;"
psql -h localhost -U postgres -c "CREATE DATABASE benchdb;"
```

### "could not connect to server"
- Check PostgreSQL is running: `sudo systemctl status postgresql`
- Check PGPASSWORD is set correctly
- Check pg_hba.conf allows local connections

### "pgbench: not found"
```bash
sudo bash 00-prerequisites/install-dependencies.sh
```

### TPS is very low (< 100)
- Check `synchronous_commit` setting
- Verify `shared_buffers` is at least 25% of RAM
- Check if disk I/O is saturated: `iostat -x 1 10`

---

## Congratulations!

You've successfully run your first PostgreSQL benchmark with the MinervaDB PostgreSQL Benchmarking Toolkit!

For enterprise-grade benchmarking, refer to the full runbooks in the `runbooks/` directory.

---

*MinervaDB PostgreSQL Benchmarking Toolkit v1.0.0 | https://minervadb.com*
