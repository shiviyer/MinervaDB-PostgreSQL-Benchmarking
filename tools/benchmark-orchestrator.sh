#!/usr/bin/env bash
# =============================================================================
# MinervaDB PostgreSQL Benchmarking Toolkit
# benchmark-orchestrator.sh - Master Benchmark Orchestration Script
# =============================================================================
# This is the main entry point for running comprehensive benchmark suites.
# It orchestrates multiple benchmark scenarios in sequence, collects results,
# and produces a consolidated report.
#
# USAGE:
#   bash tools/benchmark-orchestrator.sh [OPTIONS]
#
# QUICK START:
#   # Run full benchmark suite (all scenarios)
#   bash tools/benchmark-orchestrator.sh --host localhost --scale 100
#
#   # Run only OLTP benchmarks
#   bash tools/benchmark-orchestrator.sh --host localhost --suite oltp
#
#   # Run capacity planning sweep
#   bash tools/benchmark-orchestrator.sh --host localhost --suite capacity
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(dirname "${SCRIPT_DIR}")"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RUN_ID="benchmark-${TIMESTAMP}"

# Defaults
PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
PG_DBNAME="${PG_DBNAME:-benchdb}"
SCALE_FACTOR=100
SUITE="oltp"         # oltp, olap, mixed, capacity, full
DURATION=300
MAX_CLIENTS=128
RESULTS_DIR="${TOOLKIT_DIR}/results/${RUN_ID}"
REPORT_DIR="${TOOLKIT_DIR}/reports"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()     { echo -e "${BLUE}[$(date +%H:%M:%S)] INFO${NC} $1"; }
success() { echo -e "${GREEN}[$(date +%H:%M:%S)] ✓${NC} $1"; }
warn()    { echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠${NC} $1"; }
error()   { echo -e "${RED}[$(date +%H:%M:%S)] ✗${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}\n"; }

# =============================================================================
# Parse Arguments
# =============================================================================

usage() {
cat << 'EOF'
MinervaDB PostgreSQL Benchmarking Toolkit - Orchestrator

USAGE:
  bash tools/benchmark-orchestrator.sh [OPTIONS]

OPTIONS:
  -h, --host HOST         PostgreSQL host (default: localhost)
  -p, --port PORT         PostgreSQL port (default: 5432)
  -U, --user USER         PostgreSQL user (default: postgres)
  -d, --dbname DBNAME     Database name (default: benchdb)
  -s, --scale SCALE       Scale factor (default: 100)
  -S, --suite SUITE       Benchmark suite: oltp|olap|mixed|capacity|full (default: oltp)
  -T, --duration SECS     Duration per test (default: 300)
  -c, --max-clients N     Maximum clients for concurrency sweep (default: 128)
  -o, --output DIR        Results directory
  --dry-run               Show what would run without executing
  --help                  Show this help

SUITES:
  oltp      TPC-B, sysbench OLTP, read-only, write-heavy
  olap      TPC-H, analytical queries, parallel query
  mixed     Concurrent OLTP + OLAP workloads
  capacity  Multi-client concurrency sweep for capacity planning
  full      All of the above (estimated: 2-4 hours)

EXAMPLES:
  # Quick OLTP benchmark (5 minutes)
  bash tools/benchmark-orchestrator.sh --host localhost --suite oltp --duration 300

  # Full capacity planning run (2+ hours)
  bash tools/benchmark-orchestrator.sh --host pg-prod --scale 500 --suite capacity

  # Full benchmark suite
  bash tools/benchmark-orchestrator.sh --host localhost --scale 1000 --suite full

EOF
exit 0
}

DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host) PG_HOST="$2"; shift 2 ;;
        -p|--port) PG_PORT="$2"; shift 2 ;;
        -U|--user) PG_USER="$2"; shift 2 ;;
        -d|--dbname) PG_DBNAME="$2"; shift 2 ;;
        -s|--scale) SCALE_FACTOR="$2"; shift 2 ;;
        -S|--suite) SUITE="$2"; shift 2 ;;
        -T|--duration) DURATION="$2"; shift 2 ;;
        -c|--max-clients) MAX_CLIENTS="$2"; shift 2 ;;
        -o|--output) RESULTS_DIR="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

PGBENCH_CONN="-h ${PG_HOST} -p ${PG_PORT} -U ${PG_USER}"
mkdir -p "${RESULTS_DIR}" "${REPORT_DIR}"

# =============================================================================
# Banner
# =============================================================================

print_banner() {
cat << EOF

${BOLD}╔══════════════════════════════════════════════════════════════╗
║      MinervaDB PostgreSQL Benchmarking Toolkit               ║
║      Enterprise-Grade Benchmark Orchestrator v1.0.0          ║
║      https://minervadb.com                                    ║
╚══════════════════════════════════════════════════════════════╝${NC}

  Run ID:       ${RUN_ID}
  Suite:        ${SUITE}
  PostgreSQL:   ${PG_HOST}:${PG_PORT}/${PG_DBNAME}
  Scale Factor: ${SCALE_FACTOR}
  Duration:     ${DURATION}s per test
  Max Clients:  ${MAX_CLIENTS}
  Results Dir:  ${RESULTS_DIR}
  Timestamp:    $(date -Iseconds)

EOF
}

# =============================================================================
# Helper: Run benchmark with tracking
# =============================================================================

BENCHMARK_LOG="${RESULTS_DIR}/orchestrator.log"
COMPLETED_BENCHMARKS=()
FAILED_BENCHMARKS=()

run_benchmark() {
    local name="$1"
    local cmd="$2"
    
    log "Starting: ${name}"
    echo "$(date): START - ${name}" >> "${BENCHMARK_LOG}"
    
    if [ "${DRY_RUN}" = "true" ]; then
        echo "  DRY RUN: ${cmd}"
        COMPLETED_BENCHMARKS+=("${name}")
        return 0
    fi
    
    local start=$(date +%s)
    if eval "${cmd}" >> "${RESULTS_DIR}/${name// /-}.log" 2>&1; then
        local end=$(date +%s)
        local elapsed=$((end - start))
        success "${name} completed in ${elapsed}s"
        echo "$(date): COMPLETE - ${name} (${elapsed}s)" >> "${BENCHMARK_LOG}"
        COMPLETED_BENCHMARKS+=("${name}")
    else
        warn "${name} FAILED (check ${RESULTS_DIR}/${name// /-}.log)"
        echo "$(date): FAILED - ${name}" >> "${BENCHMARK_LOG}"
        FAILED_BENCHMARKS+=("${name}")
    fi
}

# =============================================================================
# Benchmark Suites
# =============================================================================

run_oltp_suite() {
    section "OLTP Benchmark Suite"
    
    # Initialize database
    log "Initializing pgbench database (scale=${SCALE_FACTOR})..."
    pgbench ${PGBENCH_CONN} \
        --initialize --scale=${SCALE_FACTOR} --foreign-keys \
        "${PG_DBNAME}" 2>&1 | tee "${RESULTS_DIR}/pgbench-init.log"
    
    psql ${PGBENCH_CONN} -d "${PG_DBNAME}" -c "
        VACUUM ANALYZE pgbench_accounts;
        VACUUM ANALYZE pgbench_branches;  
        VACUUM ANALYZE pgbench_tellers;
        CHECKPOINT;
    " > /dev/null
    
    # TPC-B standard OLTP
    run_benchmark "tpcb-32clients" \
        "pgbench ${PGBENCH_CONN} -c 32 -j 8 -T ${DURATION} --no-vacuum --progress=60 '${PG_DBNAME}'"
    
    # Read-only
    run_benchmark "tpcb-readonly-64clients" \
        "pgbench ${PGBENCH_CONN} --select-only -c 64 -j 16 -T ${DURATION} --no-vacuum '${PG_DBNAME}'"
    
    # Write-heavy (INSERT only via custom script)
    run_benchmark "tpcb-16clients" \
        "pgbench ${PGBENCH_CONN} -c 16 -j 4 -T ${DURATION} --no-vacuum '${PG_DBNAME}'"
}

run_capacity_suite() {
    section "Capacity Planning - Concurrency Sweep"
    
    log "Running concurrency sweep from 1 to ${MAX_CLIENTS} clients..."
    log "This will create a TPS vs. latency curve for capacity planning"
    
    for CLIENTS in 1 2 4 8 16 32 64 ${MAX_CLIENTS}; do
        THREADS=$(( CLIENTS < 16 ? CLIENTS : 16 ))
        run_benchmark "sweep-${CLIENTS}clients" \
            "pgbench ${PGBENCH_CONN} -c ${CLIENTS} -j ${THREADS} -T 120 --no-vacuum --progress=30 '${PG_DBNAME}'"
        sleep 5  # Allow system to recover between tests
    done
}

run_olap_suite() {
    section "OLAP / Analytics Benchmark Suite"
    
    # Create analytics test schema
    psql ${PGBENCH_CONN} -d "${PG_DBNAME}" << 'OLAPEOF'
CREATE TABLE IF NOT EXISTS olap_orders (
    order_id BIGSERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date DATE NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    total_amount NUMERIC(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    region VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
) PARTITION BY RANGE (order_date);

CREATE TABLE IF NOT EXISTS olap_orders_2023 PARTITION OF olap_orders
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE IF NOT EXISTS olap_orders_2024 PARTITION OF olap_orders
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE IF NOT EXISTS olap_orders_2025 PARTITION OF olap_orders
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE INDEX IF NOT EXISTS idx_olap_orders_customer ON olap_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_olap_orders_product ON olap_orders(product_id);
CREATE INDEX IF NOT EXISTS idx_olap_orders_region ON olap_orders(region);

INSERT INTO olap_orders (customer_id, order_date, product_id, quantity, unit_price, status, region)
SELECT
    (random() * 100000)::int + 1,
    ('2023-01-01'::date + (random() * 730)::int),
    (random() * 10000)::int + 1,
    (random() * 100)::int + 1,
    (random() * 1000 + 10)::numeric(10,2),
    (ARRAY['pending','completed','shipped','cancelled'])[(random()*3)::int+1],
    (ARRAY['North','South','East','West','Central'])[(random()*4)::int+1]
FROM generate_series(1, 5000000);

ANALYZE olap_orders;
OLAPEOF
    
    # OLAP Query benchmarks
    run_benchmark "olap-aggregation" \
        "psql ${PGBENCH_CONN} -d '${PG_DBNAME}' -c "SELECT region, date_trunc('month', order_date) AS month, count(*), sum(total_amount), avg(total_amount) FROM olap_orders GROUP BY 1, 2 ORDER BY 1, 2;""
    
    run_benchmark "olap-window-functions" \
        "psql ${PGBENCH_CONN} -d '${PG_DBNAME}' -c "SELECT region, customer_id, total_amount, rank() OVER (PARTITION BY region ORDER BY total_amount DESC), sum(total_amount) OVER (PARTITION BY region) AS region_total FROM olap_orders LIMIT 100;""
    
    run_benchmark "olap-parallel-seq-scan" \
        "psql ${PGBENCH_CONN} -d '${PG_DBNAME}' -c "SET max_parallel_workers_per_gather=4; SELECT region, count(*), sum(total_amount) FROM olap_orders WHERE status='completed' GROUP BY region;""
}

run_mixed_suite() {
    section "Mixed OLTP + OLAP Concurrent Workload"
    
    warn "Mixed workload: Running OLTP and OLAP queries concurrently"
    warn "This simulates a real-world mixed-use PostgreSQL deployment"
    
    # Start OLAP background job
    psql ${PGBENCH_CONN} -d "${PG_DBNAME}" -c "
        SELECT count(*), avg(abalance) FROM pgbench_accounts;
        SELECT sum(bbalance) FROM pgbench_branches;
    " &
    OLAP_PID=$!
    
    # Run OLTP concurrently
    run_benchmark "mixed-oltp-foreground" \
        "pgbench ${PGBENCH_CONN} -c 16 -j 4 -T ${DURATION} --no-vacuum '${PG_DBNAME}'"
    
    wait ${OLAP_PID} 2>/dev/null || true
}

# =============================================================================
# Print Final Summary
# =============================================================================

print_summary() {
    local total=$(( ${#COMPLETED_BENCHMARKS[@]} + ${#FAILED_BENCHMARKS[@]} ))
    
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗"
    echo "║                  BENCHMARK SUITE COMPLETE                    ║"
    echo -e "╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Run ID:     ${RUN_ID}"
    echo "  Suite:      ${SUITE}"
    echo "  Total:      ${total} benchmarks"
    echo -e "  Completed:  ${GREEN}${#COMPLETED_BENCHMARKS[@]}${NC}"
    echo -e "  Failed:     ${RED}${#FAILED_BENCHMARKS[@]}${NC}"
    echo ""
    
    if [ ${#COMPLETED_BENCHMARKS[@]} -gt 0 ]; then
        echo -e "  ${GREEN}Completed Benchmarks:${NC}"
        for b in "${COMPLETED_BENCHMARKS[@]}"; do
            echo "    ✓ ${b}"
        done
    fi
    
    if [ ${#FAILED_BENCHMARKS[@]} -gt 0 ]; then
        echo -e "  ${RED}Failed Benchmarks:${NC}"
        for b in "${FAILED_BENCHMARKS[@]}"; do
            echo "    ✗ ${b}"
        done
    fi
    
    echo ""
    echo "  Results directory: ${RESULTS_DIR}/"
    echo ""
    echo "  Next steps:"
    echo "    python3 tools/result-analyzer.py --input ${RESULTS_DIR}/"
    echo "    python3 tools/report-generator.py --input ${RESULTS_DIR}/ --output ${REPORT_DIR}/"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    print_banner
    
    # Validate connection
    psql ${PGBENCH_CONN} -d "${PG_DBNAME}" -c "SELECT 1;" > /dev/null || \
        error "Cannot connect to PostgreSQL at ${PG_HOST}:${PG_PORT}"
    
    # Run selected suite
    case "${SUITE}" in
        oltp)     run_oltp_suite ;;
        olap)     run_olap_suite ;;
        mixed)    run_oltp_suite; run_mixed_suite ;;
        capacity) run_oltp_suite; run_capacity_suite ;;
        full)     run_oltp_suite; run_olap_suite; run_mixed_suite; run_capacity_suite ;;
        *)        error "Unknown suite: ${SUITE}. Use: oltp|olap|mixed|capacity|full" ;;
    esac
    
    print_summary
}

main "$@"
