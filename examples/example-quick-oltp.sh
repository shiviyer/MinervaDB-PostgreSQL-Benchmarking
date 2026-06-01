#!/usr/bin/env bash
# =============================================================================
# MinervaDB PostgreSQL Benchmarking Toolkit
# example-quick-oltp.sh - Quick OLTP Benchmark Example
# =============================================================================
# DESCRIPTION:
#   Ready-to-run example for a quick OLTP performance benchmark.
#   Perfect for:
#     - First-time benchmarking
#     - Quick health checks
#     - CI/CD pipeline integration
#     - Pre/post configuration change testing
#
# USAGE:
#   bash examples/example-quick-oltp.sh [--host HOST] [--scale N] [--clients N]
#
# EXAMPLE RUNS:
#   # Default (localhost, scale=100, 32 clients, 5 minutes)
#   bash examples/example-quick-oltp.sh
#
#   # Custom host and scale
#   bash examples/example-quick-oltp.sh --host pg-server-01 --scale 500 --clients 64
#
#   # Quick smoke test (60 seconds)
#   bash examples/example-quick-oltp.sh --duration 60 --scale 10
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(dirname "${SCRIPT_DIR}")"

# Default parameters
PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
PG_DBNAME="${PG_DBNAME:-benchdb}"
SCALE_FACTOR=100
CLIENTS=32
THREADS=8
DURATION=300
RESULTS_DIR="${TOOLKIT_DIR}/results/quick-oltp-$(date +%Y%m%d-%H%M%S)"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --host) PG_HOST="$2"; shift 2 ;;
        --port) PG_PORT="$2"; shift 2 ;;
        --user) PG_USER="$2"; shift 2 ;;
        --scale) SCALE_FACTOR="$2"; shift 2 ;;
        --clients) CLIENTS="$2"; shift 2 ;;
        --duration) DURATION="$2"; shift 2 ;;
        --output) RESULTS_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

mkdir -p "${RESULTS_DIR}"

echo "=================================================================="
echo "  MinervaDB PostgreSQL Benchmarking Toolkit"
echo "  Quick OLTP Benchmark Example"
echo "=================================================================="
echo ""
echo "  PostgreSQL:  ${PG_HOST}:${PG_PORT}/${PG_DBNAME}"
echo "  Scale Factor: ${SCALE_FACTOR}"
echo "  Clients:      ${CLIENTS}"
echo "  Duration:     ${DURATION}s"
echo "  Results:      ${RESULTS_DIR}"
echo ""
echo "=================================================================="

# Step 1: Validate connection
echo "Step 1/5: Validating PostgreSQL connection..."
psql -h ${PG_HOST} -p ${PG_PORT} -U ${PG_USER} -d ${PG_DBNAME} \
     -c "SELECT version();" -At || {
    echo "ERROR: Cannot connect to PostgreSQL"
    echo "  Ensure PostgreSQL is running and credentials are correct"
    echo "  Set PGPASSWORD environment variable if needed"
    exit 1
}
echo "  ✓ Connected successfully"

# Step 2: Initialize benchmark data
echo ""
echo "Step 2/5: Initializing benchmark data (scale=${SCALE_FACTOR})..."
echo "  Creating $((SCALE_FACTOR * 100000)) accounts rows..."
pgbench -h ${PG_HOST} -p ${PG_PORT} -U ${PG_USER} \
        --initialize --scale=${SCALE_FACTOR} --foreign-keys \
        "${PG_DBNAME}" 2>&1 | tail -5
echo "  ✓ Benchmark data initialized"

# Step 3: Warmup
echo ""
echo "Step 3/5: Warming up (60 seconds)..."
pgbench -h ${PG_HOST} -p ${PG_PORT} -U ${PG_USER} \
        -c ${CLIENTS} -j ${THREADS} -T 60 \
        --no-vacuum --progress=30 \
        "${PG_DBNAME}" > /dev/null 2>&1
echo "  ✓ Warmup complete"

# Step 4: Reset statistics
echo ""
echo "Step 4/5: Resetting PostgreSQL statistics..."
psql -h ${PG_HOST} -p ${PG_PORT} -U ${PG_USER} -d ${PG_DBNAME} \
     -c "SELECT pg_stat_reset(); SELECT pg_stat_statements_reset();" \
     > /dev/null 2>&1 || true
echo "  ✓ Statistics reset"

# Step 5: Run benchmark
echo ""
echo "Step 5/5: Running OLTP benchmark (${DURATION}s)..."
echo "  Progress will be reported every 30 seconds..."
echo ""

RESULT_FILE="${RESULTS_DIR}/pgbench-results.txt"

pgbench -h ${PG_HOST} -p ${PG_PORT} -U ${PG_USER} \
        -c ${CLIENTS} -j ${THREADS} -T ${DURATION} \
        --no-vacuum \
        --progress=30 \
        "${PG_DBNAME}" 2>&1 | tee "${RESULT_FILE}"

# Collect final statistics
psql -h ${PG_HOST} -p ${PG_PORT} -U ${PG_USER} -d ${PG_DBNAME} << 'STATSEOF' >> "${RESULTS_DIR}/pg-stats.txt"
\echo '=== Buffer Cache Hit Ratio ==='
SELECT datname,
       round(blks_hit::numeric / NULLIF(blks_hit + blks_read, 0) * 100, 2) AS cache_hit_pct
FROM pg_stat_database WHERE datname = current_database();

\echo '=== Checkpoint Stats ==='
SELECT checkpoints_timed, checkpoints_req,
       round(checkpoint_write_time/1000, 1) AS write_s,
       round(checkpoint_sync_time/1000, 1) AS sync_s
FROM pg_stat_bgwriter;

\echo '=== Top Queries ==='
SELECT calls, round(mean_exec_time::numeric,1) AS avg_ms,
       left(query, 60) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC LIMIT 10;
STATSEOF

# Display summary
echo ""
echo "=================================================================="
echo "  BENCHMARK RESULTS SUMMARY"
echo "=================================================================="
echo ""
grep -E "^tps|latency average|latency stddev" "${RESULT_FILE}" || true
echo ""
echo "  Results saved to: ${RESULTS_DIR}/"
echo ""
echo "  Files:"
echo "    - pgbench-results.txt  : Raw pgbench output"
echo "    - pg-stats.txt         : PostgreSQL statistics"
echo ""
echo "  Next Steps:"
echo "    - Run full benchmark suite: bash tools/benchmark-orchestrator.sh"
echo "    - Analyze results: python3 tools/result-analyzer.py --input ${RESULTS_DIR}/"
echo "    - Generate report: python3 tools/report-generator.py --input ${RESULTS_DIR}/"
echo ""
echo "  Documentation: https://github.com/shiviyer/MinervaDB-PostgreSQL-Benchmarking"
echo "=================================================================="
