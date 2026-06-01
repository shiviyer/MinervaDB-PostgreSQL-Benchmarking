#!/usr/bin/env bash
# =============================================================================
# MinervaDB PostgreSQL Benchmarking Toolkit
# run-tpcb-benchmark.sh - TPC-B Like OLTP Benchmark using pgbench
# =============================================================================
# The TPC-B benchmark simulates banking transactions with:
#   - UPDATE accounts (debit transaction)
#   - UPDATE branches
#   - UPDATE tellers
#   - INSERT INTO history
#   - SELECT balance
#
# Scale Factor (SF) guidelines:
#   SF 1    =  ~100,000 rows in accounts (small test)
#   SF 100  =  ~10M rows (realistic medium load)
#   SF 1000 =  ~100M rows (large production-like)
# =============================================================================

set -euo pipefail

# =============================================================================
# Default Configuration (override via command line args)
# =============================================================================

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
PG_DBNAME="${PG_DBNAME:-benchdb}"
SCALE_FACTOR="${SCALE_FACTOR:-100}"
CLIENTS="${CLIENTS:-32}"
THREADS="${THREADS:-8}"
DURATION="${DURATION:-300}"         # seconds
WARMUP_DURATION="${WARMUP_DURATION:-60}"
RESULTS_DIR="${RESULTS_DIR:-./results}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
PGPASSWORD="${PGPASSWORD:-}"

# Colors
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

log() { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"; }
success() { echo -e "${GREEN}[$(date +%H:%M:%S)] ✓${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠${NC} $1"; }
error() { echo -e "${RED}[$(date +%H:%M:%S)] ✗${NC} $1"; exit 1; }

# =============================================================================
# Parse Arguments
# =============================================================================

usage() {
    cat << EOF
Usage: $(basename $0) [OPTIONS]

TPC-B (pgbench) Benchmark Runner - MinervaDB PostgreSQL Benchmarking Toolkit

Options:
  -h, --host HOST          PostgreSQL host (default: localhost)
  -p, --port PORT          PostgreSQL port (default: 5432)
  -U, --user USER          PostgreSQL user (default: postgres)
  -d, --dbname DBNAME      Database name (default: benchdb)
  -s, --scale SCALE        Scale factor (default: 100)
  -c, --clients CLIENTS    Number of clients (default: 32)
  -j, --threads THREADS    Number of threads (default: 8)
  -T, --duration SECONDS   Test duration in seconds (default: 300)
  -w, --warmup SECONDS     Warmup duration in seconds (default: 60)
  -o, --output DIR         Results output directory (default: ./results)
  --skip-init              Skip database initialization
  --skip-warmup            Skip warmup phase
  --read-only              Run read-only benchmark variant
  --help                   Show this help

Examples:
  # Quick 5-minute OLTP benchmark
  $(basename $0) -h localhost -s 100 -c 32 -T 300

  # Production-scale 1-hour benchmark
  $(basename $0) -h pg-prod-01 -s 1000 -c 128 -j 32 -T 3600

  # Read-only benchmark
  $(basename $0) -h localhost -s 100 -c 64 --read-only

EOF
    exit 0
}

SKIP_INIT=false
SKIP_WARMUP=false
READ_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host) PG_HOST="$2"; shift 2 ;;
        -p|--port) PG_PORT="$2"; shift 2 ;;
        -U|--user) PG_USER="$2"; shift 2 ;;
        -d|--dbname) PG_DBNAME="$2"; shift 2 ;;
        -s|--scale) SCALE_FACTOR="$2"; shift 2 ;;
        -c|--clients) CLIENTS="$2"; shift 2 ;;
        -j|--threads) THREADS="$2"; shift 2 ;;
        -T|--duration) DURATION="$2"; shift 2 ;;
        -w|--warmup) WARMUP_DURATION="$2"; shift 2 ;;
        -o|--output) RESULTS_DIR="$2"; shift 2 ;;
        --skip-init) SKIP_INIT=true; shift ;;
        --skip-warmup) SKIP_WARMUP=true; shift ;;
        --read-only) READ_ONLY=true; shift ;;
        --help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# =============================================================================
# Setup
# =============================================================================

RESULT_FILE="${RESULTS_DIR}/tpcb-${RUN_ID}"
mkdir -p "${RESULTS_DIR}"

PGBENCH_CONN="-h ${PG_HOST} -p ${PG_PORT} -U ${PG_USER}"

export PGPASSWORD

# =============================================================================
# Pre-flight Checks
# =============================================================================

preflight_checks() {
    log "Running pre-flight checks..."
    
    # Check pgbench availability
    command -v pgbench &>/dev/null || error "pgbench not found. Install PostgreSQL tools."
    
    PGBENCH_VER=$(pgbench --version | awk '{print $NF}')
    log "pgbench version: ${PGBENCH_VER}"
    
    # Test database connection
    psql ${PGBENCH_CONN} -d ${PG_DBNAME} -c "SELECT version();" &>/dev/null || \
        error "Cannot connect to PostgreSQL at ${PG_HOST}:${PG_PORT}"
    
    PG_VERSION=$(psql ${PGBENCH_CONN} -d ${PG_DBNAME} -At -c "SELECT version();")
    log "Connected: ${PG_VERSION}"
    
    # Check available disk space for results
    AVAIL_SPACE=$(df -k "${RESULTS_DIR}" | tail -1 | awk '{print $4}')
    [ "${AVAIL_SPACE}" -lt 1048576 ] && warn "Less than 1GB disk space available for results"
    
    success "Pre-flight checks passed"
}

# =============================================================================
# Collect System Info
# =============================================================================

collect_system_info() {
    log "Collecting system information..."
    
    cat > "${RESULT_FILE}-sysinfo.txt" << EOF
================================================================
MinervaDB PostgreSQL Benchmarking Toolkit - System Info
Run ID: ${RUN_ID}
Timestamp: $(date -Iseconds)
================================================================

--- Benchmark Configuration ---
Host:         ${PG_HOST}:${PG_PORT}
Database:     ${PG_DBNAME}
Scale Factor: ${SCALE_FACTOR}
Clients:      ${CLIENTS}
Threads:      ${THREADS}
Duration:     ${DURATION}s
Warmup:       ${WARMUP_DURATION}s
Read-Only:    ${READ_ONLY}

--- System ---
Hostname:     $(hostname -f)
OS:           $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Kernel:       $(uname -r)
CPU:          $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
CPU Cores:    $(nproc)
RAM Total:    $(free -h | grep Mem | awk '{print $2}')
RAM Free:     $(free -h | grep Mem | awk '{print $4}')

--- PostgreSQL ---
$(psql ${PGBENCH_CONN} -d ${PG_DBNAME} -c "SELECT version();")

--- Key PostgreSQL Settings ---
$(psql ${PGBENCH_CONN} -d ${PG_DBNAME} -c "
SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name IN (
    'shared_buffers', 'effective_cache_size', 'work_mem',
    'maintenance_work_mem', 'max_connections', 'max_worker_processes',
    'max_parallel_workers', 'checkpoint_completion_target',
    'wal_buffers', 'synchronous_commit', 'random_page_cost',
    'seq_page_cost', 'effective_io_concurrency', 'autovacuum'
)
ORDER BY name;
")
EOF
    success "System info collected: ${RESULT_FILE}-sysinfo.txt"
}

# =============================================================================
# Initialize Database
# =============================================================================

initialize_database() {
    if [ "${SKIP_INIT}" = "true" ]; then
        warn "Skipping database initialization (--skip-init)"
        return 0
    fi
    
    log "Initializing pgbench database (scale factor: ${SCALE_FACTOR})..."
    log "This creates $((SCALE_FACTOR * 100000)) rows in accounts table"
    
    # Create database if not exists
    psql ${PGBENCH_CONN} -d postgres -c "CREATE DATABASE ${PG_DBNAME};" 2>/dev/null || true
    
    # Initialize pgbench schema
    INIT_START=$(date +%s)
    pgbench ${PGBENCH_CONN} \
        --initialize \
        --scale=${SCALE_FACTOR} \
        --foreign-keys \
        "${PG_DBNAME}" 2>&1 | tee "${RESULT_FILE}-init.log"
    INIT_END=$(date +%s)
    INIT_DURATION=$((INIT_END - INIT_START))
    
    log "Initialization completed in ${INIT_DURATION} seconds"
    
    # Post-init: VACUUM ANALYZE
    log "Running VACUUM ANALYZE on pgbench tables..."
    psql ${PGBENCH_CONN} -d "${PG_DBNAME}" -c "
        VACUUM ANALYZE pgbench_accounts;
        VACUUM ANALYZE pgbench_branches;
        VACUUM ANALYZE pgbench_tellers;
        VACUUM ANALYZE pgbench_history;
    " 2>&1
    
    # Checkpoint to flush dirty pages
    psql ${PGBENCH_CONN} -d "${PG_DBNAME}" -c "CHECKPOINT;" 2>&1
    
    success "Database initialized and analyzed"
}

# =============================================================================
# Run Benchmark
# =============================================================================

run_warmup() {
    if [ "${SKIP_WARMUP}" = "true" ]; then
        warn "Skipping warmup phase"
        return 0
    fi
    
    log "Running warmup phase (${WARMUP_DURATION}s)..."
    
    BENCH_FLAGS="--client=${CLIENTS} --jobs=${THREADS} --time=${WARMUP_DURATION}"
    [ "${READ_ONLY}" = "true" ] && BENCH_FLAGS="${BENCH_FLAGS} --select-only"
    
    pgbench ${PGBENCH_CONN} ${BENCH_FLAGS} \
        --no-vacuum \
        --progress=10 \
        "${PG_DBNAME}" > /dev/null 2>&1
    
    # Wait for system to stabilize
    sleep 5
    success "Warmup complete"
}

run_benchmark() {
    log "Starting TPC-B benchmark..."
    log "Configuration: ${CLIENTS} clients, ${THREADS} threads, ${DURATION}s duration"
    
    BENCH_FLAGS="--client=${CLIENTS} --jobs=${THREADS} --time=${DURATION}"
    [ "${READ_ONLY}" = "true" ] && BENCH_FLAGS="${BENCH_FLAGS} --select-only"
    
    # Collect pg_stat_bgwriter before
    psql ${PGBENCH_CONN} -d "${PG_DBNAME}" -c "
        SELECT 'BEFORE' as phase, * FROM pg_stat_bgwriter;
    " >> "${RESULT_FILE}-pgstats.txt" 2>&1
    
    # Run the benchmark
    log "Benchmark running... (check progress every 30s)"
    BENCH_START=$(date +%s)
    
    pgbench ${PGBENCH_CONN} ${BENCH_FLAGS} \
        --no-vacuum \
        --report-per-command \
        --progress=30 \
        --log \
        --log-prefix="${RESULT_FILE}-pgbench-log" \
        "${PG_DBNAME}" 2>&1 | tee "${RESULT_FILE}-results.txt"
    
    BENCH_END=$(date +%s)
    ACTUAL_DURATION=$((BENCH_END - BENCH_START))
    
    # Collect pg_stat_bgwriter after
    psql ${PGBENCH_CONN} -d "${PG_DBNAME}" -c "
        SELECT 'AFTER' as phase, * FROM pg_stat_bgwriter;
    " >> "${RESULT_FILE}-pgstats.txt" 2>&1
    
    # Collect pg_stat_database
    psql ${PGBENCH_CONN} -d "${PG_DBNAME}" -c "
        SELECT datname, numbackends, xact_commit, xact_rollback,
               blks_read, blks_hit, 
               round(blks_hit::numeric/(blks_hit+blks_read+1)*100, 2) as cache_hit_pct,
               deadlocks, conflicts
        FROM pg_stat_database
        WHERE datname = '${PG_DBNAME}';
    " >> "${RESULT_FILE}-pgstats.txt" 2>&1
    
    success "Benchmark completed in ${ACTUAL_DURATION} seconds"
}

# =============================================================================
# Parse and Display Results
# =============================================================================

display_results() {
    log "Parsing results..."
    
    TPS=$(grep "^tps" "${RESULT_FILE}-results.txt" | head -1 | awk '{print $3}' | tr -d '(')
    LATENCY_AVG=$(grep "latency average" "${RESULT_FILE}-results.txt" | awk '{print $3}')
    LATENCY_STDDEV=$(grep "latency stddev" "${RESULT_FILE}-results.txt" | awk '{print $3}' || echo "N/A")
    INITIAL_CONN=$(grep "initial connection" "${RESULT_FILE}-results.txt" | awk '{print $4}' || echo "N/A")
    
    echo ""
    echo -e "${BOLD}================================================================${NC}"
    echo -e "${BOLD}  MinervaDB PostgreSQL TPC-B Benchmark Results${NC}"
    echo -e "${BOLD}================================================================${NC}"
    printf "  %-30s %s\n" "Run ID:" "${RUN_ID}"
    printf "  %-30s %s\n" "Host:" "${PG_HOST}:${PG_PORT}/${PG_DBNAME}"
    printf "  %-30s %s\n" "Scale Factor:" "${SCALE_FACTOR}"
    printf "  %-30s %s\n" "Clients:" "${CLIENTS}"
    printf "  %-30s %s\n" "Threads:" "${THREADS}"
    printf "  %-30s %s\n" "Duration:" "${DURATION}s"
    echo "  --------------------------------"
    printf "  %-30s ${GREEN}%s TPS${NC}\n" "Throughput (TPS):" "${TPS}"
    printf "  %-30s %s ms\n" "Avg Latency:" "${LATENCY_AVG}"
    printf "  %-30s %s ms\n" "Latency Std Dev:" "${LATENCY_STDDEV}"
    printf "  %-30s %s ms\n" "Initial Conn Time:" "${INITIAL_CONN}"
    echo -e "${BOLD}================================================================${NC}"
    echo ""
    echo "  Full results: ${RESULT_FILE}-results.txt"
    echo "  System info:  ${RESULT_FILE}-sysinfo.txt"
    echo "  PG stats:     ${RESULT_FILE}-pgstats.txt"
    echo ""
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo ""
    echo -e "${BOLD}MinervaDB PostgreSQL Benchmarking Toolkit${NC}"
    echo -e "TPC-B OLTP Benchmark | Run ID: ${RUN_ID}"
    echo "================================================================"
    echo ""
    
    preflight_checks
    collect_system_info
    initialize_database
    run_warmup
    run_benchmark
    display_results
    
    success "Benchmark complete! Results in: ${RESULTS_DIR}/"
}

main "$@"
