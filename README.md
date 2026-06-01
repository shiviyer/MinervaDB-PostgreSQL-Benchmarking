<div align="center">

<img src="https://img.shields.io/badge/PostgreSQL-15%20|%2016%20|%2017%20|%2018-316192?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL">
<img src="https://img.shields.io/badge/License-Apache%202.0-blue?style=for-the-badge" alt="License">
<img src="https://img.shields.io/badge/Enterprise-Grade-gold?style=for-the-badge" alt="Enterprise Grade">
<img src="https://img.shields.io/badge/MinervaDB-Toolkit-red?style=for-the-badge" alt="MinervaDB">
<img src="https://img.shields.io/badge/Status-Production%20Ready-brightgreen?style=for-the-badge" alt="Production Ready">

# MinervaDB PostgreSQL Benchmarking Toolkit

### Enterprise-Grade Performance Benchmarking, Capacity Planning & Sizing for PostgreSQL 15–18

**Built by [MinervaDB](https://minervadb.com) | The PostgreSQL Center of Excellence**

[Quick Start](#-quick-start) • [Documentation](#-documentation) • [Benchmarking Scenarios](#-benchmarking-scenarios) • [Runbooks](#-runbooks) • [Contributing](#-contributing)

---

</div>

## Overview

The **MinervaDB PostgreSQL Benchmarking Toolkit** is a comprehensive, production-ready collection of scripts, runbooks, automation tools, and documentation designed for database engineers, DBAs, architects, and capacity planners who need to accurately benchmark PostgreSQL deployments at enterprise scale.

This toolkit covers every critical dimension of PostgreSQL performance assessment — from raw OLTP throughput and OLAP analytical query performance to realistic mixed-workload simulation, connection pooling behavior, replication lag under load, storage I/O saturation, and memory pressure testing.

### Why This Toolkit?

| Challenge | This Toolkit Solves |
|-----------|-------------------|
| Inconsistent benchmark methodology | Standardized, repeatable test harness |
| No baseline for capacity planning | Hardware sizing matrices for PG 15-18 |
| Tool fragmentation (pgbench, sysbench, HammerDB) | Unified orchestration layer |
| Missing production workload realism | Replay-based benchmarking with pg_replay |
| Undocumented tuning baselines | Pre-validated postgresql.conf profiles |
| No cloud-to-on-prem comparison | Multi-environment benchmark normalization |

---

## Repository Structure

```
MinervaDB-PostgreSQL-Benchmarking/
├── README.md                          # This file
├── LICENSE                            # Apache 2.0
├── CHANGELOG.md                       # Version history
├── CONTRIBUTING.md                    # Contribution guidelines
│
├── 00-prerequisites/                  # Environment setup & prerequisites
│   ├── install-dependencies.sh        # Install all required tools
│   ├── system-tuning.sh              # OS-level tuning for benchmarking
│   ├── postgres-versions.md          # PG 15-18 version compatibility notes
│   └── environment-validation.sh     # Validate benchmark environment
│
├── 01-pgbench/                        # pgbench - Built-in PostgreSQL benchmarking
│   ├── README.md
│   ├── 01-tpc-b-oltp/                # TPC-B like OLTP benchmark
│   ├── 02-read-only/                 # Read-only SELECT performance
│   ├── 03-write-heavy/               # Write-intensive workloads
│   ├── 04-custom-scripts/            # Custom pgbench SQL scripts
│   └── 05-partitioned-tables/        # Benchmarking partitioned tables
│
├── 02-sysbench/                       # sysbench PostgreSQL benchmarks
│   ├── README.md
│   ├── 01-oltp-read-write/           # OLTP read/write mixed
│   ├── 02-oltp-read-only/            # Read-only OLTP
│   ├── 03-oltp-write-only/           # Write-only OLTP
│   └── 04-bulk-insert/               # Bulk data loading
│
├── 03-hammerdb/                       # HammerDB TPC-C and TPC-H
│   ├── README.md
│   ├── 01-tpc-c/                     # TPC-C OLTP benchmark
│   ├── 02-tpc-h/                     # TPC-H analytical benchmark
│   └── 03-automation/                # Automated HammerDB scripts
│
├── 04-custom-workloads/               # Custom enterprise workload scripts
│   ├── README.md
│   ├── 01-ecommerce-simulation/      # E-commerce workload patterns
│   ├── 02-financial-transactions/    # Financial OLTP workloads
│   ├── 03-iot-timeseries/            # IoT / time-series data patterns
│   ├── 04-saas-multitenant/          # Multi-tenant SaaS workloads
│   └── 05-data-warehouse/            # OLAP / DWH query patterns
│
├── 05-capacity-planning/              # Capacity planning & sizing
│   ├── README.md
│   ├── 01-sizing-calculator/         # Hardware sizing calculator
│   ├── 02-storage-planning/          # Storage IOPS & throughput planning
│   ├── 03-memory-sizing/             # Shared buffers & memory planning
│   ├── 04-connection-planning/       # Connection pool sizing
│   └── 05-growth-projections/        # Data growth & capacity projections
│
├── 06-performance-baselines/          # Establishing performance baselines
│   ├── README.md
│   ├── 01-tps-baselines/             # Transactions-per-second baselines
│   ├── 02-latency-baselines/         # Query latency percentile baselines
│   ├── 03-throughput-baselines/      # Throughput baselines
│   └── 04-resource-baselines/        # CPU, memory, I/O baselines
│
├── 07-postgresql-configurations/      # Validated postgresql.conf profiles
│   ├── README.md
│   ├── pg15-oltp-optimized.conf      # PG 15 OLTP tuned config
│   ├── pg16-oltp-optimized.conf      # PG 16 OLTP tuned config
│   ├── pg17-oltp-optimized.conf      # PG 17 OLTP tuned config
│   ├── pg18-oltp-optimized.conf      # PG 18 OLTP tuned config
│   ├── pg15-olap-optimized.conf      # PG 15 OLAP/DWH tuned config
│   ├── pg16-olap-optimized.conf      # PG 16 OLAP/DWH tuned config
│   ├── pg-mixed-workload.conf        # Mixed OLTP+OLAP config
│   └── pg-high-connection.conf       # High-connection environment config
│
├── 08-monitoring/                     # Monitoring & metrics collection
│   ├── README.md
│   ├── 01-pg-stat-collector/         # pg_stat_* data collection scripts
│   ├── 02-prometheus-exporters/      # Prometheus & Grafana setup
│   ├── 03-query-analysis/            # Query performance analysis
│   └── 04-wait-events/               # Wait event analysis during benchmarks
│
├── 09-replication-benchmarks/         # Replication performance testing
│   ├── README.md
│   ├── 01-streaming-replication/     # Streaming replication lag benchmarks
│   ├── 02-logical-replication/       # Logical replication throughput
│   └── 03-patroni-ha/               # Patroni HA failover benchmarks
│
├── 10-cloud-benchmarks/               # Cloud provider benchmarks
│   ├── README.md
│   ├── 01-aws-rds/                   # AWS RDS PostgreSQL benchmarks
│   ├── 02-aws-aurora/                # Amazon Aurora PostgreSQL
│   ├── 03-gcp-cloudsql/              # Google Cloud SQL PostgreSQL
│   ├── 04-azure-flexible/            # Azure Database for PostgreSQL
│   └── 05-cloud-comparison/          # Cross-cloud benchmark comparison
│
├── runbooks/                          # Step-by-step operational runbooks
│   ├── 01-quick-start-runbook.md
│   ├── 02-oltp-benchmark-runbook.md
│   ├── 03-olap-benchmark-runbook.md
│   ├── 04-capacity-planning-runbook.md
│   ├── 05-cloud-sizing-runbook.md
│   ├── 06-performance-regression-runbook.md
│   ├── 07-production-load-test-runbook.md
│   └── 08-postgresql-upgrade-benchmark-runbook.md
│
├── howto/                             # How-to guides
│   ├── howto-install-pgbench.md
│   ├── howto-install-sysbench.md
│   ├── howto-install-hammerdb.md
│   ├── howto-setup-monitoring.md
│   ├── howto-run-tpc-b.md
│   ├── howto-run-tpc-c.md
│   ├── howto-run-tpc-h.md
│   ├── howto-custom-workload.md
│   ├── howto-analyze-results.md
│   └── howto-generate-reports.md
│
├── examples/                          # Ready-to-run examples
│   ├── example-quick-oltp.sh
│   ├── example-olap-benchmark.sh
│   ├── example-capacity-planning.sh
│   ├── example-cloud-comparison.sh
│   └── example-full-benchmark-suite.sh
│
├── reports/                           # Report templates & sample outputs
│   ├── templates/
│   │   ├── benchmark-report-template.md
│   │   └── capacity-planning-template.md
│   └── sample-outputs/
│       ├── sample-oltp-results.txt
│       └── sample-olap-results.txt
│
└── tools/                             # Supporting utilities
    ├── benchmark-orchestrator.sh      # Master benchmark orchestration
    ├── result-analyzer.py             # Results analysis & visualization
    ├── report-generator.py            # Automated report generation
    └── environment-setup.sh           # Environment preparation script
```

---

## Quick Start

### Prerequisites

- PostgreSQL 15, 16, 17, or 18 installed and running
- Linux/macOS (Ubuntu 20.04+, RHEL/CentOS 8+, macOS 12+)
- Minimum 4 CPU cores, 16GB RAM for meaningful results
- `git`, `bash`, `python3`, `psql` available

### Step 1: Clone the Repository

```bash
git clone https://github.com/shiviyer/MinervaDB-PostgreSQL-Benchmarking.git
cd MinervaDB-PostgreSQL-Benchmarking
```

### Step 2: Install Dependencies

```bash
chmod +x 00-prerequisites/install-dependencies.sh
sudo bash 00-prerequisites/install-dependencies.sh
```

### Step 3: Validate Your Environment

```bash
bash 00-prerequisites/environment-validation.sh \
  --host localhost \
  --port 5432 \
  --user postgres \
  --dbname benchdb
```

### Step 4: Run Your First Benchmark

```bash
# Quick OLTP benchmark (TPC-B, 60 seconds)
bash examples/example-quick-oltp.sh \
  --host localhost \
  --scale 100 \
  --clients 32 \
  --duration 60
```

### Step 5: View Results

```bash
python3 tools/result-analyzer.py --input results/ --output reports/
```

---

## Benchmarking Scenarios

### OLTP Benchmarks

| Scenario | Tool | Description | Script |
|----------|------|-------------|--------|
| TPC-B (Standard OLTP) | pgbench | Standard banking OLTP simulation | `01-pgbench/01-tpc-b-oltp/` |
| TPC-C (OLTP Complex) | HammerDB | Full TPC-C with 9 transaction types | `03-hammerdb/01-tpc-c/` |
| Read-Only (Point SELECT) | pgbench | High-concurrency read performance | `01-pgbench/02-read-only/` |
| Write-Heavy (INSERT/UPDATE) | pgbench | Write saturation testing | `01-pgbench/03-write-heavy/` |
| E-Commerce Simulation | Custom | Cart, orders, inventory workloads | `04-custom-workloads/01-ecommerce/` |
| Financial Transactions | Custom | ACID-heavy financial patterns | `04-custom-workloads/02-financial/` |
| SaaS Multi-Tenant | Custom | Row-level security + schema isolation | `04-custom-workloads/04-saas/` |

### OLAP / Analytics Benchmarks

| Scenario | Tool | Description | Script |
|----------|------|-------------|--------|
| TPC-H | HammerDB | Standard decision-support benchmark (22 queries) | `03-hammerdb/02-tpc-h/` |
| IoT Time-Series | Custom | High-insert time-series + range aggregations | `04-custom-workloads/03-iot-timeseries/` |
| Data Warehouse | Custom | Star schema, aggregations, window functions | `04-custom-workloads/05-data-warehouse/` |
| Parallel Query | Custom | pg_parallel_workers tuning benchmark | `04-custom-workloads/` |

### Mixed Workload Benchmarks

| Scenario | Description | Script |
|----------|-------------|--------|
| OLTP + OLAP Concurrent | 80% OLTP / 20% OLAP simultaneous | `04-custom-workloads/` |
| Peak Load Simulation | Ramping load from 10 to 1000 clients | `tools/benchmark-orchestrator.sh` |
| Connection Pool Stress | PgBouncer / pgpool-II saturation | `08-monitoring/` |
| Replication Lag Under Load | Replication delay vs write throughput | `09-replication-benchmarks/` |

---

## Documentation

### Runbooks

| Runbook | Description |
|---------|-------------|
| [Quick Start Runbook](runbooks/01-quick-start-runbook.md) | Get up and running in 15 minutes |
| [OLTP Benchmark Runbook](runbooks/02-oltp-benchmark-runbook.md) | Full OLTP benchmark methodology |
| [OLAP Benchmark Runbook](runbooks/03-olap-benchmark-runbook.md) | Analytics benchmark methodology |
| [Capacity Planning Runbook](runbooks/04-capacity-planning-runbook.md) | Size your PostgreSQL infrastructure |
| [Cloud Sizing Runbook](runbooks/05-cloud-sizing-runbook.md) | Choose the right cloud instance type |
| [Performance Regression Runbook](runbooks/06-performance-regression-runbook.md) | Detect and investigate regressions |
| [Production Load Test Runbook](runbooks/07-production-load-test-runbook.md) | Safe production load testing |
| [PG Upgrade Benchmark Runbook](runbooks/08-postgresql-upgrade-benchmark-runbook.md) | Benchmark before/after PG upgrades |

### How-To Guides

| Guide | Description |
|-------|-------------|
| [Install pgbench](howto/howto-install-pgbench.md) | pgbench setup and configuration |
| [Install sysbench](howto/howto-install-sysbench.md) | sysbench PostgreSQL driver setup |
| [Install HammerDB](howto/howto-install-hammerdb.md) | HammerDB TPC-C/TPC-H setup |
| [Setup Monitoring](howto/howto-setup-monitoring.md) | Prometheus + Grafana dashboard |
| [Run TPC-B](howto/howto-run-tpc-b.md) | TPC-B benchmark step-by-step |
| [Run TPC-C](howto/howto-run-tpc-c.md) | TPC-C benchmark step-by-step |
| [Run TPC-H](howto/howto-run-tpc-h.md) | TPC-H benchmark step-by-step |
| [Analyze Results](howto/howto-analyze-results.md) | Interpreting benchmark output |
| [Generate Reports](howto/howto-generate-reports.md) | Creating professional reports |

---

## Capacity Planning

### Hardware Sizing Guide (PostgreSQL 15-18)

#### Small Deployment (< 1,000 TPS)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 4 cores | 8 cores (Intel Xeon / AMD EPYC) |
| RAM | 16 GB | 32 GB |
| Storage | 500 GB NVMe SSD | 1 TB NVMe SSD (RAID 10) |
| Network | 1 Gbps | 10 Gbps |
| `shared_buffers` | 4 GB | 8 GB |
| `effective_cache_size` | 12 GB | 24 GB |

#### Medium Deployment (1,000 – 10,000 TPS)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 16 cores | 32 cores |
| RAM | 64 GB | 128 GB |
| Storage | 4 TB NVMe SSD | 8 TB NVMe (RAID 10) |
| Network | 10 Gbps | 25 Gbps |
| `shared_buffers` | 16 GB | 32 GB |
| `effective_cache_size` | 48 GB | 96 GB |

#### Large Deployment (10,000+ TPS)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 64 cores | 128+ cores |
| RAM | 256 GB | 512 GB + |
| Storage | 16 TB NVMe | All-NVMe SAN |
| Network | 25 Gbps | 100 Gbps |
| `shared_buffers` | 64 GB | 128 GB |
| `effective_cache_size` | 192 GB | 384 GB |

---

## PostgreSQL Version Compatibility

| Feature | PG 15 | PG 16 | PG 17 | PG 18 |
|---------|-------|-------|-------|-------|
| Merge Command | ✅ | ✅ | ✅ | ✅ |
| Logical Replication (partition) | ✅ | ✅ | ✅ | ✅ |
| pg_stat_io | ✅ | ✅ | ✅ | ✅ |
| Parallel COPY | ❌ | ✅ | ✅ | ✅ |
| pg_stat_wal improvements | ❌ | ✅ | ✅ | ✅ |
| Incremental Backup | ❌ | ❌ | ✅ | ✅ |
| AIO (Async I/O) | ❌ | ❌ | ❌ | ✅ |
| Improved VACUUM | ✅ | ✅ | ✅ | ✅ |

---

## Contributing

We welcome contributions from the community! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting pull requests.

### How to Contribute

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-benchmark-scenario`
3. Add your scripts with documentation
4. Ensure all scripts follow our coding standards
5. Submit a pull request

---

## Support & Community

- **GitHub Issues**: [Report bugs or request features](https://github.com/shiviyer/MinervaDB-PostgreSQL-Benchmarking/issues)
- **MinervaDB Website**: [https://minervadb.com](https://minervadb.com)
- **Twitter/X**: [@thewebscaledba](https://twitter.com/thewebscaledba)

---

## License

This toolkit is licensed under the **Apache License 2.0**. See [LICENSE](LICENSE) for details.

---

<div align="center">

**Built with expertise by [MinervaDB](https://minervadb.com) — The PostgreSQL Center of Excellence**

*Empowering DBAs and Architects to build high-performance PostgreSQL systems*

</div>
