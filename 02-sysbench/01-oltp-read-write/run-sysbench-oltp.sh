#!/usr/bin/env bash
# =============================================================================
# MinervaDB PostgreSQL Benchmarking Toolkit
# run-sysbench-oltp.sh - sysbench OLTP Read/Write Benchmark
# =============================================================================
# sysbench OLTP benchmark for PostgreSQL includes:
#   - SELECT (point lookups and range scans)
#   - INSERT, UPDATE (indexed + non-indexed), DELETE
#   - BEGIN/COMMIT transaction pairs
#
# This gives a more comprehensive view of OLTP performance than TPC-B,
# with configurable read/write mix and secondary index operations.
# =============================================================================

set -euo pipefail

# =============================================================================
# Defaults
# =============================================================================

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
PG_DBNAME="${PG_DBNAME:-benchdb}"
PGPASSWORD="${PGPASSWORD:-}"

TABLES="${TABLES:-10}"
TABLE_SIZE="${TABLE_SIZE:-1000000}"  # Rows per table
THREADS="${THREADS:-32}"
DURATION="${DURATION:-300}"
WARMUP="${WARMUP:-60}"
REPORT_INTERVAL="${REPORT_INTERVAL:-30}"
PERCENTILE="${PERCENTILE:-99}"
RESULTS_DIR="${RESULTS_DIR:-./results}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"

MODE="${MODE:-read_write}"  # read_write, read_only, write_only, point_select

# Colors
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

log() { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"; }
success() { echo -e "${GREEN}[$(date +%H:%M:%S)] ✓${NC} $1"; }
error() { echo -e "${RED}[$(date +%H:%M:%S)] ✗${NC} $1"; exit 1; }

# =============================================================================
# Parse arguments
# =============================================================================

usage() {
cat << 'EOF'
Usage: run-sysbench-oltp.sh [OPTIONS]

sysbench OLTP Benchmark - MinervaDB PostgreSQL Benchmarking Toolkit

Options:
  --host HOST         PostgreSQL host (default: localhost)
  --port PORT         PostgreSQL port (default: 5432)
  --user USER         PostgreSQL user (default: postgres)
  --password PASS     PostgreSQL password
  --dbname DBNAME     Database name (default: benchdb)
  --tables N          Number of tables (default: 10)
  --table-size N      Rows per table (default: 1,000,000)
  --threads N         Number of threads (default: 32)
  --duration SECS     Benchmark duration (default: 300)
  --mode MODE         Workload: read_write|read_only|write_only|point_select
  --output DIR        Results directory (default: ./results)
  --skip-prepare      Skip database preparation
  --skip-cleanup      Skip cleanup after benchmark

Examples:
  # Standard read/write OLTP
  ./run-sysbench-oltp.sh --host localhost --threads 32 --duration 300

  # Read-only benchmark
  ./run-sysbench-oltp.sh --host localhost --mode read_only --threads 64

  # Large-scale benchmark
  ./run-sysbench-oltp.sh --host localhost --tables 50 --table-size 5000000 --threads 128
EOF
exit 0
}

SKIP_PREPARE=false
SKIP_CLEANUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --host) PG_HOST="$2"; shift 2 ;;
        --port) PG_PORT="$2"; shift 2 ;;
        --user) PG_USER="$2"; shift 2 ;;
        --password) PGPASSWORD="$2"; shift 2 ;;
        --dbname) PG_DBNAME="$2"; shift 2 ;;
        --tables) TABLES="$2"; shift 2 ;;
        --table-size) TABLE_SIZE="$2"; shift 2 ;;
        --threads) THREADS="$2"; shift 2 ;;
        --duration) DURATION="$2"; shift 2 ;;
        --mode) MODE="$2"; shift 2 ;;
        --output) RESULTS_DIR="$2"; shift 2 ;;
        --skip-prepare) SKIP_PREPARE=true; shift ;;
        --skip-cleanup) SKIP_CLEANUP=true; shift ;;
        --help) usage ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

mkdir -p "${RESULTS_DIR}"
RESULT_FILE="${RESULTS_DIR}/sysbench-${MODE}-${RUN_ID}"
export PGPASSWORD

# =============================================================================
# sysbench connection parameters
# =============================================================================

SYSBENCH_COMMON="\
  --db-driver=pgsql \
  --pgsql-host=${PG_HOST} \
  --pgsql-port=${PG_PORT} \
  --pgsql-user=${PG_USER} \
  --pgsql-db=${PG_DBNAME} \
  --tables=${TABLES} \
  --table-size=${TABLE_SIZE}"

[ -n "${PGPASSWORD}" ] && SYSBENCH_COMMON="${SYSBENCH_COMMON} --pgsql-password=${PGPASSWORD}"

# Determine sysbench test name
case "${MODE}" in
    read_write)    SYSBENCH_TEST="oltp_read_write" ;;
    read_only)     SYSBENCH_TEST="oltp_read_only" ;;
    write_only)    SYSBENCH_TEST="oltp_write_only" ;;
    point_select)  SYSBENCH_TEST="oltp_point_select" ;;
    *)  error "Invalid mode: ${MODE}" ;;
esac

# =============================================================================
# Pre-flight
# =============================================================================

preflight() {
    log "Pre-flight checks..."
    command -v sysbench &>/dev/null || error "sysbench not found. Run: sudo bash 00-prerequisites/install-dependencies.sh"
    SYSBENCH_VER=$(sysbench --version 2>&1 | head -1)
    log "sysbench: ${SYSBENCH_VER}"
    
    psql -h ${PG_HOST} -p ${PG_PORT} -U ${PG_USER} -d ${PG_DBNAME} -c "SELECT 1;" > /dev/null || \
        error "Cannot connect to PostgreSQL"
    
    success "Pre-flight passed"
}

# =============================================================================
# Collect system info
# =============================================================================

collect_sysinfo() {
    cat > "${RESULT_FILE}-sysinfo.txt" << EOF
MinervaDB PostgreSQL Benchmarking Toolkit - sysbench Run
=========================================================
Timestamp:    $(date -Iseconds)
Run ID:       ${RUN_ID}
Mode:         ${MODE} (${SYSBENCH_TEST})
Host:         ${PG_HOST}:${PG_PORT}/${PG_DBNAME}
Tables:       ${TABLES}
Table Size:   ${TABLE_SIZE} rows
Threads:      ${THREADS}
Duration:     ${DURATION}s
Warmup:       ${WARMUP}s

PostgreSQL Version:
$(psql -h ${PG_HOST} -p ${PG_PORT} -U ${PG_USER} -d ${PG_DBNAME} -At -c "SELECT version();")
EOF
    success "System info saved"
}

# =============================================================================
# Prepare benchmark tables
# =============================================================================

prepare_tables() {
    if [ "${SKIP_PREPARE}" = "true" ]; then
        warn "Skipping table preparation"
        return
    fi
    
    log "Preparing sysbench tables..."
    log "Creating ${TABLES} tables with ${TABLE_SIZE} rows each..."
    log "Total rows: $(( TABLES * TABLE_SIZE ))"
    
    sysbench ${SYSBENCH_TEST} ${SYSBENCH_COMMON} prepare 2>&1 | \
        tee "${RESULT_FILE}-prepare.log"
    
    # Analyze tables for better query planning
    log "Analyzing sysbench tables..."
    psql -h ${PG_HOST} -p ${PG_PORT} -U ${PG_USER} -d ${PG_DBNAME} << 'ANALYZEEOF'
DO $$
DECLARE
    t RECORD;
BEGIN
    FOR t IN SELECT tablename FROM pg_tables WHERE tablename LIKE 'sbtest%'
    LOOP
        EXECUTE 'ANALYZE ' || t.tablename;
    END LOOP;
END;
$$;
CHECKPOINT;
ANALYZEEOF
    
    success "Tables prepared and analyzed"
}

# =============================================================================
# Warmup
# =============================================================================

warmup() {
    log "Warming up caches (${WARMUP}s)..."
    sysbench ${SYSBENCH_TEST} ${SYSBENCH_COMMON} \
        --threads=${THREADS} \
        --time=${WARMUP} \
        run > /dev/null 2>&1
    success "Warmup complete"
}

# =============================================================================
# Run benchmark
# =============================================================================

run_benchmark() {
    log "Starting sysbench ${MODE} benchmark..."
    log "Threads: ${THREADS} | Duration: ${DURATION}s | Tables: ${TABLES} x ${TABLE_SIZE} rows"
    
    sysbench ${SYSBENCH_TEST} ${SYSBENCH_COMMON} \
        --threads=${THREADS} \
        --time=${DURATION} \
        --report-interval=${REPORT_INTERVAL} \
        --percentile=${PERCENTILE} \
        run 2>&1 | tee "${RESULT_FILE}-results.txt"
    
    success "Benchmark complete"
}

# =============================================================================
# Parse and display results
# =============================================================================

display_results() {
    echo ""
    echo -e "${BOLD}================================================================${NC}"
    echo -e "${BOLD}  MinervaDB sysbench OLTP Benchmark Results${NC}"
    echo -e "${BOLD}================================================================${NC}"
    
    grep -E "^transactions:|^queries:|^Latency|avg:|min:|max:|95th|99th|^General|^SQL" \
        "${RESULT_FILE}-results.txt" | head -25
    
    echo -e "${BOLD}================================================================${NC}"
    echo ""
    echo "  Results: ${RESULT_FILE}-results.txt"
}

# =============================================================================
# Cleanup
# =============================================================================

cleanup() {
    if [ "${SKIP_CLEANUP}" = "true" ]; then
        log "Skipping cleanup (--skip-cleanup)"
        return
    fi
    
    log "Cleaning up sysbench tables..."
    sysbench ${SYSBENCH_TEST} ${SYSBENCH_COMMON} cleanup > /dev/null 2>&1 || true
    success "Cleanup done"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo -e "${BOLD}MinervaDB PostgreSQL Benchmarking Toolkit — sysbench${NC}"
    echo "Run ID: ${RUN_ID} | Mode: ${MODE}"
    echo ""
    
    preflight
    collect_sysinfo
    prepare_tables
    warmup
    run_benchmark
    display_results
    cleanup
    
    success "sysbench benchmark complete!"
}

main "$@"
