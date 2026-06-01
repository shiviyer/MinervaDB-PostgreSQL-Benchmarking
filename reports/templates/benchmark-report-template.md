# PostgreSQL Benchmarking Report

<!-- 
MinervaDB PostgreSQL Benchmarking Toolkit
Benchmark Report Template v1.0.0

Instructions:
1. Fill in all fields marked with [REQUIRED]
2. Remove unused sections
3. Replace placeholder values with actual results
4. Generate using: python3 tools/report-generator.py
-->

---

**Report Title:** [REQUIRED: e.g., "PostgreSQL 16 OLTP Performance Benchmark"]  
**Prepared By:** [REQUIRED: Engineer Name / Team]  
**Organization:** [REQUIRED: Company/Organization]  
**Date:** [REQUIRED: YYYY-MM-DD]  
**Version:** 1.0  
**Classification:** [Internal / Confidential / Public]  
**Toolkit Version:** MinervaDB PostgreSQL Benchmarking Toolkit v1.0.0  

---

## Executive Summary

[REQUIRED: 3-5 sentence summary of benchmark purpose, methodology, and key findings]

**Key Results:**

| Metric | Result | Target | Assessment |
|--------|--------|--------|------------|
| Peak TPS | [value] | [target] | [Pass/Fail] |
| Avg Latency | [value] ms | [target] ms | [Pass/Fail] |
| P99 Latency | [value] ms | [target] ms | [Pass/Fail] |
| Cache Hit % | [value]% | > 99% | [Pass/Fail] |
| Error Rate | [value]% | < 0.01% | [Pass/Fail] |

**Recommendation:** [Approve / Conditional Approval / Reject / Further Investigation Required]

---

## 1. Test Objectives

### 1.1 Goals

[REQUIRED: List the specific goals of this benchmark engagement]

- Measure peak OLTP throughput (TPS) for the production workload
- Validate latency SLAs under peak load
- Identify performance bottlenecks before production deployment
- [Add additional goals]

### 1.2 Success Criteria

| Criterion | Target | Mandatory? |
|-----------|--------|-----------|
| Peak TPS | > [N] TPS | Yes |
| P50 Latency | < [N] ms | Yes |
| P95 Latency | < [N] ms | Yes |
| P99 Latency | < [N] ms | Yes |
| Error Rate | < 0.01% | Yes |
| Cache Hit | > 99% | Recommended |

---

## 2. Test Environment

### 2.1 Server Hardware

**PostgreSQL Server:**

| Component | Specification |
|-----------|--------------|
| Server Model | [e.g., Dell PowerEdge R750] |
| CPU | [e.g., 2x Intel Xeon Gold 6354 (18 cores each, 36 total)] |
| RAM | [e.g., 256 GB DDR4 3200 MHz ECC] |
| Storage | [e.g., 4x 3.84 TB NVMe SSD (RAID 10)] |
| Network | [e.g., 25 Gbps Mellanox ConnectX-6] |
| OS | [e.g., Ubuntu 22.04.3 LTS (kernel 5.15.0-88)] |

**Client/Load Generator:**

| Component | Specification |
|-----------|--------------|
| CPU | [e.g., 2x Intel Xeon Gold 6248R (24 cores)] |
| RAM | [e.g., 64 GB] |
| Network | [e.g., 25 Gbps] |

### 2.2 PostgreSQL Configuration

**PostgreSQL Version:** [e.g., 16.2]

**Key Configuration Parameters:**

| Parameter | Value | Default | Rationale |
|-----------|-------|---------|-----------|
| shared_buffers | [value] | 128MB | [reason] |
| effective_cache_size | [value] | 4GB | [reason] |
| work_mem | [value] | 4MB | [reason] |
| max_connections | [value] | 100 | [reason] |
| synchronous_commit | [value] | on | [reason] |
| checkpoint_completion_target | [value] | 0.5 | [reason] |
| wal_buffers | [value] | auto | [reason] |
| max_parallel_workers | [value] | 8 | [reason] |

*Full postgresql.conf: [link to config file]*

### 2.3 OS Configuration

| Setting | Value | Optimal? |
|---------|-------|---------|
| Transparent Huge Pages | disabled | ✅ |
| CPU Governor | performance | ✅ |
| I/O Scheduler | none (NVMe) | ✅ |
| vm.swappiness | 1 | ✅ |
| vm.dirty_ratio | 10 | ✅ |

---

## 3. Benchmark Methodology

### 3.1 Tools Used

| Tool | Version | Purpose |
|------|---------|---------|
| pgbench | [version] | TPC-B OLTP benchmark |
| sysbench | [version] | OLTP read/write validation |
| HammerDB | [version] | TPC-C enterprise OLTP |
| fio | [version] | Storage I/O benchmarking |

### 3.2 Test Scenarios

| Scenario | Tool | Scale | Clients | Duration |
|----------|------|-------|---------|----------|
| TPC-B Standard | pgbench | [SF] | [N] | [N]s |
| TPC-B Read-Only | pgbench | [SF] | [N] | [N]s |
| sysbench OLTP R/W | sysbench | [N] tables | [N] threads | [N]s |
| TPC-C | HammerDB | [N] warehouses | [N] VUs | [N]min |

### 3.3 Test Sequence

1. System tuning applied (see environment-validation.sh output)
2. Database initialized and VACUUM ANALYZE performed
3. 60-second warmup run (results discarded)
4. pg_stat_statements reset before each test
5. Benchmark executed with progress reporting every 30s
6. pg_stat_bgwriter, pg_stat_database collected post-test
7. 10-minute cool-down between tests

---

## 4. Results

### 4.1 TPC-B Results (pgbench)

**Test Parameters:** Scale=[SF], Clients=[N], Threads=[N], Duration=[N]s

```
[PASTE: pgbench output here]
```

**Summary:**

| Metric | Value |
|--------|-------|
| TPS (excl. conn) | [value] |
| TPS (incl. conn) | [value] |
| Avg Latency | [value] ms |
| Latency Std Dev | [value] ms |
| Transactions Processed | [value] |
| Failed Transactions | [value] ([%]) |

### 4.2 Concurrency Sweep Results

| Clients | TPS | Avg Lat (ms) | P99 Lat (ms) | Notes |
|---------|-----|-------------|-------------|-------|
| 1 | [value] | [value] | [value] | |
| 4 | [value] | [value] | [value] | |
| 8 | [value] | [value] | [value] | |
| 16 | [value] | [value] | [value] | |
| 32 | [value] | [value] | [value] | Optimal |
| 64 | [value] | [value] | [value] | |
| 128 | [value] | [value] | [value] | Saturation |
| 256 | [value] | [value] | [value] | Over-saturated |

**Saturation Point:** [N] clients at [N] TPS

### 4.3 sysbench OLTP Results

```
[PASTE: sysbench output here]
```

### 4.4 TPC-C Results (HammerDB)

| Metric | Value |
|--------|-------|
| NOPM (New Orders/Min) | [value] |
| tpmC (Trans/Min C) | [value] |
| Warehouses | [value] |
| Virtual Users | [value] |

---

## 5. PostgreSQL Statistics Analysis

### 5.1 Buffer Cache Performance

| Metric | Value | Assessment |
|--------|-------|------------|
| Cache Hit Ratio | [value]% | [Good/Warning/Critical] |
| Blocks Read (disk) | [value] | |
| Blocks Hit (cache) | [value] | |

### 5.2 Checkpoint Statistics

| Metric | Value | Notes |
|--------|-------|-------|
| Checkpoints (timed) | [value] | |
| Checkpoints (requested) | [value] | High = WAL pressure |
| Checkpoint Write Time | [value]s | |
| Checkpoint Sync Time | [value]s | |

### 5.3 Top Queries During Benchmark

| Rank | Calls | Avg (ms) | Max (ms) | Query |
|------|-------|----------|---------|-------|
| 1 | [N] | [ms] | [ms] | UPDATE accounts ... |
| 2 | [N] | [ms] | [ms] | UPDATE tellers ... |
| 3 | [N] | [ms] | [ms] | SELECT abalance ... |

---

## 6. Storage I/O Analysis

| Test | IOPS | Throughput | Latency |
|------|------|-----------|---------|
| Sequential Read | [value] | [value] MB/s | [value] ms |
| Random Read | [value] | [value] MB/s | [value] ms |
| Sequential Write | [value] | [value] MB/s | [value] ms |
| Random Write | [value] | [value] MB/s | [value] ms |

---

## 7. Findings & Analysis

### 7.1 Performance Highlights

- [REQUIRED: List key positive findings]

### 7.2 Performance Concerns

- [REQUIRED: List any concerns or bottlenecks identified]

### 7.3 Bottleneck Analysis

[REQUIRED: Identify the primary performance bottleneck(s)]

The primary bottleneck during this test was: [e.g., CPU bound / I/O bound / lock contention / network]

Evidence: [explain what data points indicate this]

---

## 8. Recommendations

### 8.1 Immediate Recommendations

| Priority | Recommendation | Impact | Effort |
|----------|---------------|--------|--------|
| Critical | [action] | [High/Med/Low] | [High/Med/Low] |
| High | [action] | | |
| Medium | [action] | | |

### 8.2 Configuration Tuning

[List specific postgresql.conf changes recommended]

```
# Recommended changes to postgresql.conf
[parameter] = [recommended_value]  # Current: [current_value] | Reason: [reason]
```

### 8.3 Infrastructure Recommendations

[Any hardware, OS, or infrastructure changes recommended]

---

## 9. Conclusion

[REQUIRED: 2-3 paragraph conclusion]

The benchmark results [demonstrate / do not demonstrate] that the target system can [meet / not meet] the defined performance requirements of [N] TPS with [N]ms P99 latency.

[Approval statement or next steps]

---

## Appendix A: Raw Command Output

### pgbench Initialization
```
[paste output]
```

### pgbench Benchmark Run
```
[paste output]
```

### System Info
```
[paste from environment-validation.sh output]
```

---

## Appendix B: Full Configuration Files

*See attached postgresql.conf*

---

*Generated with MinervaDB PostgreSQL Benchmarking Toolkit v1.0.0*  
*https://github.com/shiviyer/MinervaDB-PostgreSQL-Benchmarking*  
*MinervaDB — The PostgreSQL Center of Excellence | https://minervadb.com*
