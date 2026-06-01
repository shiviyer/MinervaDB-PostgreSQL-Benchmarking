# Capacity Planning Runbook
## MinervaDB PostgreSQL Benchmarking Toolkit

**Document Type:** Runbook  
**Version:** 1.0.0  
**PostgreSQL Versions:** 15, 16, 17, 18  
**Estimated Completion Time:** 4–8 hours (full engagement)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Phase 1: Workload Discovery](#2-phase-1-workload-discovery)
3. [Phase 2: Baseline Benchmarking](#3-phase-2-baseline-benchmarking)
4. [Phase 3: Sizing Calculations](#4-phase-3-sizing-calculations)
5. [Phase 4: Storage Planning](#5-phase-4-storage-planning)
6. [Phase 5: Connection Planning](#6-phase-5-connection-planning)
7. [Phase 6: Growth Projections](#7-phase-6-growth-projections)
8. [Phase 7: Cloud Instance Sizing](#8-phase-7-cloud-instance-sizing)
9. [Decision Matrix](#9-decision-matrix)
10. [Output Deliverables](#10-output-deliverables)

---

## 1. Overview

This runbook guides you through a systematic PostgreSQL capacity planning engagement. The output is a hardware/infrastructure sizing recommendation based on empirical benchmarking data and workload analysis.

### When to Use This Runbook

- New PostgreSQL deployment (greenfield)
- Migration from another database (Oracle, MySQL, SQL Server)
- Scaling an existing PostgreSQL deployment
- Cloud provider selection or instance type selection
- Annual capacity review

### Prerequisites

- [ ] Access to existing application profiling data (if available)
- [ ] PostgreSQL benchmark environment with representative schema
- [ ] `MinervaDB-PostgreSQL-Benchmarking` toolkit installed
- [ ] System monitoring tools (htop, iostat, vmstat)
- [ ] At least 2 hours of dedicated benchmark time

---

## 2. Phase 1: Workload Discovery

### 2.1 Gather Workload Requirements

Complete the following questionnaire before any benchmarking:

```
WORKLOAD DISCOVERY QUESTIONNAIRE
================================

Application Profile:
  Application Type:         [ ] Web App  [ ] API  [ ] Analytics  [ ] Mixed
  Peak Users (concurrent):  _______
  Peak TPS (expected):      _______
  Read/Write Ratio:         _______ % reads / _______ % writes
  
Transaction Profile:
  Average transaction time: _______ ms (SLA requirement)
  P95 latency target:       _______ ms
  P99 latency target:       _______ ms
  Acceptable error rate:    _______ %
  
Data Profile:
  Current database size:    _______ GB
  Row count (largest table):_______
  Data growth rate:         _______ GB/month
  Data retention period:    _______ months
  
Availability Requirements:
  Uptime SLA:               _______ % (e.g., 99.9%)
  RTO (Recovery Time):      _______ minutes
  RPO (Recovery Point):     _______ minutes
  Replication needed:       [ ] Yes - [ ] Streaming  [ ] Logical  [ ] No
  
Maintenance Windows:
  VACUUM/maintenance:       [ ] Allowed during business hours  [ ] Off-hours only
  Deployment windows:       _______
```

### 2.2 Analyze Existing Query Patterns (if migrating)

If you have an existing database, extract the workload profile:

```sql
-- From existing PostgreSQL (requires pg_stat_statements)
-- Top 20 queries by total time
SELECT
    left(query, 100) AS query_preview,
    calls,
    round(total_exec_time::numeric, 2) AS total_ms,
    round(mean_exec_time::numeric, 2) AS avg_ms,
    round(stddev_exec_time::numeric, 2) AS stddev_ms,
    round(min_exec_time::numeric, 2) AS min_ms,
    round(max_exec_time::numeric, 2) AS max_ms,
    rows,
    round(rows::numeric / calls, 1) AS avg_rows,
    shared_blks_hit,
    shared_blks_read,
    round(shared_blks_hit::numeric / 
          NULLIF(shared_blks_hit + shared_blks_read, 0) * 100, 2) AS cache_hit_pct
FROM pg_stat_statements
WHERE calls > 100
ORDER BY total_exec_time DESC
LIMIT 20;
```

```sql
-- Current connection utilization
SELECT
    state,
    wait_event_type,
    wait_event,
    count(*) AS count
FROM pg_stat_activity
WHERE pid != pg_backend_pid()
GROUP BY state, wait_event_type, wait_event
ORDER BY count DESC;
```

```sql
-- Table sizes (identify largest tables)
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) AS index_size,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;
```

```sql
-- Cache hit ratio (target > 99%)
SELECT
    'Buffer Cache' AS cache_type,
    round(
        sum(blks_hit)::numeric / 
        NULLIF(sum(blks_hit) + sum(blks_read), 0) * 100, 2
    ) AS hit_ratio_pct
FROM pg_stat_database
WHERE datname NOT IN ('template0', 'template1', 'postgres');
```

### 2.3 Workload Classification

Based on discovery, classify the workload:

| Metric | OLTP | Mixed | OLAP |
|--------|------|-------|------|
| Transaction duration | < 100ms | 100ms-10s | > 10s |
| Read/Write ratio | 60-80% reads | 50/50 | 90%+ reads |
| Row count per query | < 1,000 | 1K-100K | > 100K |
| Concurrency | High (100+) | Medium | Low (1-20) |
| JIT compilation | Off | Optional | On |
| Parallel workers | Low | Medium | High |

---

## 3. Phase 2: Baseline Benchmarking

### 3.1 Initialize Benchmark Environment

```bash
# Clone the toolkit
git clone https://github.com/shiviyer/MinervaDB-PostgreSQL-Benchmarking.git
cd MinervaDB-PostgreSQL-Benchmarking

# Install dependencies
sudo bash 00-prerequisites/install-dependencies.sh

# Validate environment
bash 00-prerequisites/environment-validation.sh \
  --host YOUR_PG_HOST \
  --port 5432 \
  --user postgres \
  --dbname capacitydb
```

### 3.2 TPC-B OLTP Baseline

```bash
# Run TPC-B at different scale factors and client counts
# This creates throughput/latency curves

for SCALE in 10 50 100 500; do
  for CLIENTS in 1 4 8 16 32 64 128; do
    echo "Running: Scale=${SCALE}, Clients=${CLIENTS}"
    bash 01-pgbench/01-tpc-b-oltp/run-tpcb-benchmark.sh \
      --host YOUR_PG_HOST \
      --scale ${SCALE} \
      --clients ${CLIENTS} \
      --threads $(nproc) \
      --duration 120 \
      --skip-init \
      --output results/capacity-planning/
  done
done
```

### 3.3 Read-Only Throughput Ceiling

```bash
# Determine max read throughput
bash 01-pgbench/02-read-only/run-readonly-benchmark.sh \
  --host YOUR_PG_HOST \
  --scale 100 \
  --clients 128 \
  --threads 16 \
  --duration 300
```

### 3.4 Write Throughput Ceiling

```bash
# Determine max write throughput
bash 01-pgbench/03-write-heavy/run-write-benchmark.sh \
  --host YOUR_PG_HOST \
  --scale 100 \
  --clients 64 \
  --threads 16 \
  --duration 300
```

### 3.5 I/O Benchmarking

```bash
# Test raw storage I/O performance
# Sequential read
fio --name=seq-read --ioengine=libaio --iodepth=128 \
    --rw=read --bs=128k --direct=1 --size=10G \
    --filename=/var/lib/postgresql/fio-test \
    --runtime=60 --time_based

# Random read (IOPS)
fio --name=rand-read --ioengine=libaio --iodepth=128 \
    --rw=randread --bs=8k --direct=1 --size=10G \
    --filename=/var/lib/postgresql/fio-test \
    --runtime=60 --time_based

# Random write (WAL simulation)
fio --name=rand-write --ioengine=libaio --iodepth=32 \
    --rw=randwrite --bs=8k --direct=1 --size=10G \
    --filename=/var/lib/postgresql/fio-test \
    --runtime=60 --time_based
```

---

## 4. Phase 3: Sizing Calculations

### 4.1 CPU Sizing

```
CPU SIZING WORKSHEET
====================

Step 1: Determine peak TPS requirement
  Peak TPS:                     _______ TPS

Step 2: From benchmark results, find TPS per core
  Measured TPS:                 _______
  CPU cores used:               _______
  TPS per core:                 _______ (= Measured TPS / cores)

Step 3: Calculate required cores for peak TPS
  Required cores:               _______ (= Peak TPS / TPS-per-core)

Step 4: Add headroom (20-30% for growth + OS overhead)
  Recommended cores:            _______ (= Required cores * 1.3)

Step 5: Round up to nearest standard server (8, 16, 32, 64, 96)
  Final CPU recommendation:     _______ cores
```

**Rule of Thumb:**
- 1 core supports approximately 500-2,000 OLTP TPS (depends on workload)
- OLAP queries benefit from parallel workers (1 query = N cores)
- Reserve 2 cores minimum for OS + PostgreSQL background processes

### 4.2 Memory Sizing

```
MEMORY SIZING WORKSHEET
========================

Component                          Formula                      Value
---------                          -------                      -----
shared_buffers                     25% of total RAM             _______ GB
effective_cache_size               75% of total RAM             _______ GB
work_mem (per sort operation)      128MB / max_connections      _______ MB
Peak work_mem (all concurrent)     work_mem * connections       _______ GB
maintenance_work_mem               RAM / 16 (max 8GB)           _______ GB
OS buffer cache                    10-15% of RAM                _______ GB
Connection overhead                10MB * max_connections       _______ GB
                                   ----------------------------
TOTAL RAM REQUIRED:                sum of above                 _______ GB

Recommended RAM:                   Total * 1.25 (25% headroom)  _______ GB
```

**Critical Rule:** shared_buffers must fit your "hot dataset" in memory for optimal performance. If your working set is 200GB, you need at minimum 200GB RAM with shared_buffers = 50GB.

### 4.3 Benchmark-to-Production Scaling

Use your benchmark results to extrapolate production needs:

```bash
# From benchmark results, extract TPS at different client counts
python3 tools/result-analyzer.py \
  --input results/capacity-planning/ \
  --mode tps-curve \
  --output reports/tps-saturation-curve.png
```

Look for the "knee of the curve" — the point where adding more clients no longer increases TPS. That is your server's throughput ceiling.

---

## 5. Phase 4: Storage Planning

### 5.1 Storage Capacity

```
STORAGE SIZING WORKSHEET
=========================

Current database size:            _______ GB
Index overhead (typically 30%):   _______ GB  (= DB size * 0.30)
WAL storage (7-day retention):    _______ GB  (= Daily WAL * 7)
Temporary file space:             _______ GB  (= RAM * 2)
Backup storage (local):           _______ GB  (= DB size * 3)
OS + PostgreSQL binaries:         50 GB
System headroom (20%):            _______ GB
                                  ------------------
TOTAL STORAGE REQUIRED:           _______ GB

Recommended storage:              _______ GB (round up to nearest tier)
```

### 5.2 IOPS Requirements

```bash
# Measure current I/O from production (if available)
iostat -x 1 60 | awk '/^sd|^nvme/ {print $1, "read_iops:", $4, "write_iops:", $5}'

# From pgbench results, estimate production IOPS
# Rule: Each TPS generates approximately 2-10 IOPS (depends on shared_buffers hit rate)
```

| Workload Type | IOPS per 1,000 TPS |
|---------------|-------------------|
| Heavy cache hit (>99%) | 100-500 IOPS |
| Medium cache hit (95%) | 500-2,000 IOPS |
| Low cache hit (<90%) | 2,000-10,000 IOPS |

### 5.3 Storage Type Recommendations

| IOPS Requirement | Storage Type | Example |
|------------------|-------------|---------|
| < 10,000 IOPS | SATA SSD | Enterprise SATA SSD |
| 10,000 - 100,000 IOPS | NVMe SSD | Intel P4610, Samsung PM983 |
| > 100,000 IOPS | NVMe RAID or SAN | All-NVMe array |

---

## 6. Phase 5: Connection Planning

### 6.1 Connection Pool Sizing

**Never set max_connections > 500 without PgBouncer/Odyssey in front.**

```
CONNECTION PLANNING WORKSHEET
==============================

Application threads/workers:       _______
Peak concurrent DB connections:    _______ (typically 2-5x app threads)
PgBouncer pool_size per database:  _______ (= available CPU cores * 5)
PgBouncer max_client_conn:         _______ (= 10x pool_size)
PostgreSQL max_connections:        _______ (= pool_size + 20 overhead)
```

### 6.2 PgBouncer Configuration Template

```ini
# pgbouncer.ini - MinervaDB Capacity Planning Template
[databases]
* = host=127.0.0.1 port=5432

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432

# Pool mode: transaction (best for OLTP), session (for app compatibility)
pool_mode = transaction

# Max server connections to PostgreSQL
server_pool_size = 100          # = CPU cores * 5

# Max client connections from applications
max_client_conn = 2000

# Connection lifetime settings
server_lifetime = 3600
server_idle_timeout = 600
client_idle_timeout = 0

# Authentication
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt

# Stats
stats_period = 60
```

---

## 7. Phase 6: Growth Projections

### 7.1 Capacity Growth Model

```bash
# Run growth projection calculator
python3 05-capacity-planning/05-growth-projections/growth-calculator.py \
  --current-size 500 \
  --monthly-growth-rate 15 \
  --projection-months 36 \
  --current-tps 5000 \
  --tps-growth-rate 20
```

### 7.2 12-Month Capacity Forecast

| Metric | Current | +6 Months | +12 Months | +24 Months |
|--------|---------|-----------|------------|------------|
| Database Size | ___GB | ___GB | ___GB | ___GB |
| Peak TPS | ___ | ___ | ___ | ___ |
| Required CPU | ___c | ___c | ___c | ___c |
| Required RAM | ___GB | ___GB | ___GB | ___GB |
| Required Storage | ___GB | ___GB | ___GB | ___GB |

---

## 8. Phase 7: Cloud Instance Sizing

### 8.1 AWS RDS / Aurora PostgreSQL

| TPS Range | Instance Type | vCPU | RAM | Storage |
|-----------|---------------|------|-----|---------|
| 0-500 | db.t3.large | 2 | 8GB | gp3 100GB |
| 500-2,000 | db.r6g.xlarge | 4 | 32GB | gp3 500GB |
| 2,000-10,000 | db.r6g.4xlarge | 16 | 128GB | gp3 2TB |
| 10,000-50,000 | db.r6g.16xlarge | 64 | 512GB | io1 10TB |
| 50,000+ | Aurora Serverless v2 | auto | auto | auto |

### 8.2 Google Cloud SQL / AlloyDB

| TPS Range | Instance Type | vCPU | RAM |
|-----------|---------------|------|-----|
| 0-1,000 | db-n1-standard-4 | 4 | 15GB |
| 1,000-5,000 | db-n1-highmem-8 | 8 | 52GB |
| 5,000-25,000 | db-n1-highmem-32 | 32 | 208GB |
| 25,000+ | AlloyDB | auto | auto |

### 8.3 Azure Database for PostgreSQL Flexible

| TPS Range | SKU | vCPU | RAM |
|-----------|-----|------|-----|
| 0-1,000 | Standard_D4ds_v5 | 4 | 16GB |
| 1,000-10,000 | Standard_D16ds_v5 | 16 | 64GB |
| 10,000-50,000 | Standard_D64ds_v5 | 64 | 256GB |
| 50,000+ | Memory Optimized | 96+ | 384GB+ |

---

## 9. Decision Matrix

Use this matrix to finalize your sizing recommendation:

| Factor | Weight | Your Score (1-5) | Weighted Score |
|--------|--------|-----------------|----------------|
| Peak TPS headroom (>30%) | 25% | ___ | ___ |
| Memory for working set | 25% | ___ | ___ |
| Storage IOPS headroom | 20% | ___ | ___ |
| Connection handling | 15% | ___ | ___ |
| 12-month growth buffer | 15% | ___ | ___ |
| **Total** | **100%** | | **___/5.0** |

Score interpretation:
- 4.0-5.0: Configuration is right-sized
- 3.0-3.9: Adequate, monitor growth closely  
- 2.0-2.9: Undersized, plan upgrade within 6 months
- < 2.0: Critically undersized, upgrade immediately

---

## 10. Output Deliverables

After completing this runbook, produce the following:

### 10.1 Generate Capacity Planning Report

```bash
python3 tools/report-generator.py \
  --template reports/templates/capacity-planning-template.md \
  --results-dir results/capacity-planning/ \
  --output reports/capacity-planning-$(date +%Y%m%d).md
```

### 10.2 Checklist

- [ ] Workload discovery questionnaire completed
- [ ] Peak TPS measured via benchmark
- [ ] CPU sizing calculation documented
- [ ] Memory sizing calculation documented
- [ ] Storage IOPS requirements confirmed
- [ ] Connection pool strategy defined
- [ ] 12-month growth projections modeled
- [ ] Cloud instance type (if applicable) selected
- [ ] Final recommendation documented
- [ ] postgresql.conf profile selected from `07-postgresql-configurations/`

---

## References

- PostgreSQL Official Documentation: https://www.postgresql.org/docs/
- MinervaDB PostgreSQL Blog: https://minervadb.com/blog
- pgbench documentation: `man pgbench` or `pgbench --help`
- HammerDB TPC-C Guide: https://www.hammerdb.com/docs/

---

*MinervaDB PostgreSQL Benchmarking Toolkit | https://minervadb.com*
