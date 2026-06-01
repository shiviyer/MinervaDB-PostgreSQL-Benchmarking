# Changelog

All notable changes to the **MinervaDB PostgreSQL Benchmarking Toolkit** will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) and follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) conventions.

---

## [Unreleased]

### Planned
- PostgreSQL 18 AIO (Asynchronous I/O) benchmark scenarios
- AlloyDB Omni benchmarking support
- Automated cloud instance type recommendation engine
- Integration with pg_gather for automated diagnostics
- Grafana dashboard JSON for live benchmark monitoring
- Docker/Podman-based benchmark environment

---

## [1.0.0] - 2026-06-01

### Added — Initial Release

#### Benchmark Tools
- **pgbench** TPC-B OLTP benchmark suite (`01-pgbench/`)
  - Standard TPC-B read/write (`01-tpc-b-oltp/run-tpcb-benchmark.sh`)
  - Read-only SELECT benchmark
  - Write-heavy INSERT/UPDATE benchmark
  - Partitioned table benchmarks
- **sysbench** OLTP benchmark suite (`02-sysbench/`)
  - OLTP read/write (`01-oltp-read-write/run-sysbench-oltp.sh`)
  - OLTP read-only
  - OLTP write-only
  - Bulk INSERT benchmarks
- **HammerDB** enterprise benchmarks (`03-hammerdb/`)
  - TPC-C (`01-tpc-c/run-tpcc-benchmark.sh`)
  - TPC-H (OLAP analytics)
  - Automated HammerDB TCL scripts

#### Custom Workload Simulations (`04-custom-workloads/`)
- E-commerce simulation (cart, orders, inventory)
- Financial transaction workloads (ACID-heavy)
- IoT time-series data patterns
- SaaS multi-tenant workloads (row-level security)
- Data warehouse OLAP patterns

#### Capacity Planning (`05-capacity-planning/`)
- Hardware sizing calculator (CPU, RAM, Storage)
- Storage IOPS & throughput planning tools
- Memory sizing worksheets
- Connection pool sizing guide (PgBouncer)
- 12-24 month growth projection model

#### PostgreSQL Configurations (`07-postgresql-configurations/`)
- OLTP-optimized configs for PG 15, 16, 17, 18
- OLAP/analytics-optimized configs
- Mixed workload configs
- High-connection environment configs (PgBouncer integration)

#### Monitoring & Analysis (`08-monitoring/`)
- pg_stat_* collector scripts
- Prometheus + Grafana setup guides
- Query performance analysis tools
- Wait event analysis during benchmarks

#### Replication Benchmarks (`09-replication-benchmarks/`)
- Streaming replication lag under load
- Logical replication throughput
- Patroni HA failover benchmark methodology

#### Cloud Benchmarks (`10-cloud-benchmarks/`)
- AWS RDS PostgreSQL benchmark methodology
- Amazon Aurora PostgreSQL benchmarking
- Google Cloud SQL / AlloyDB benchmarking
- Azure Database for PostgreSQL Flexible Server
- Cross-cloud comparison framework

#### Tools & Automation (`tools/`)
- `benchmark-orchestrator.sh` - Master benchmark orchestration
- `result-analyzer.py` - Results analysis & visualization
- `report-generator.py` - Automated report generation
- `environment-setup.sh` - Environment preparation

#### Prerequisites (`00-prerequisites/`)
- `install-dependencies.sh` - Install all required tools
- `system-tuning.sh` - OS-level kernel & I/O tuning
- `environment-validation.sh` - Pre-benchmark validation
- PostgreSQL version compatibility documentation

#### Runbooks (`runbooks/`)
- Quick Start Runbook (15-minute onboarding)
- OLTP Benchmark Methodology
- OLAP Benchmark Methodology
- Capacity Planning & Sizing
- Cloud Instance Sizing
- Performance Regression Detection
- Production Load Testing Safety Guide
- PostgreSQL Version Upgrade Benchmarking

#### How-To Guides (`howto/`)
- Installing pgbench, sysbench, HammerDB
- Setting up monitoring (Prometheus + Grafana)
- Running TPC-B, TPC-C, TPC-H benchmarks
- Analyzing benchmark results
- Generating professional reports

#### Examples (`examples/`)
- Quick OLTP benchmark (5 minutes)
- OLAP benchmark
- Capacity planning sweep
- Cloud comparison
- Full benchmark suite

#### Documentation
- Comprehensive `README.md` with:
  - Architecture overview
  - Complete benchmark scenario matrix
  - Hardware sizing guide (small/medium/large/XL)
  - PostgreSQL version compatibility matrix
  - Quick start guide
  - Capacity planning tables
- `CONTRIBUTING.md` with coding standards
- `CHANGELOG.md` (this file)
- Apache 2.0 License

### PostgreSQL Version Support
- PostgreSQL 15 ✅ (all features)
- PostgreSQL 16 ✅ (all features including Parallel COPY, pg_stat_io improvements)
- PostgreSQL 17 ✅ (Incremental Backup scenarios)
- PostgreSQL 18 ✅ (AIO benchmark scenarios)

### Platform Support
- Ubuntu 20.04 LTS, 22.04 LTS, 24.04 LTS
- RHEL / CentOS Stream / AlmaLinux / Rocky Linux 8, 9
- Debian 11, 12
- macOS 12+ (Monterey and later)

---

## How to Read This Changelog

Each version section contains:
- **Added** — New features, scripts, or scenarios
- **Changed** — Changes to existing functionality  
- **Fixed** — Bug fixes
- **Removed** — Deprecated or removed features
- **Security** — Security-related changes

---

## Versioning Policy

| Version | Meaning |
|---------|---------|
| MAJOR (X.0.0) | Breaking changes to script interfaces or outputs |
| MINOR (1.X.0) | New benchmark scenarios, tools, or major docs |
| PATCH (1.0.X) | Bug fixes, documentation corrections |

---

## Links

- [Repository](https://github.com/shiviyer/MinervaDB-PostgreSQL-Benchmarking)
- [MinervaDB](https://minervadb.com)
- [Issues](https://github.com/shiviyer/MinervaDB-PostgreSQL-Benchmarking/issues)

---

*MinervaDB PostgreSQL Benchmarking Toolkit | Built by the PostgreSQL Center of Excellence*
