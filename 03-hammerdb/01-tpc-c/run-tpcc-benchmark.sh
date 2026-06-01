#!/usr/bin/env bash
# =============================================================================
# MinervaDB PostgreSQL Benchmarking Toolkit
# run-tpcc-benchmark.sh - HammerDB TPC-C Benchmark
# =============================================================================
# TPC-C is the industry standard OLTP benchmark. It includes 9 transaction types:
#   - New Order (45%) - Process new customer orders
#   - Payment (43%) - Process customer payments  
#   - Order Status (4%) - Query order status
#   - Delivery (4%) - Process pending deliveries
#   - Stock Level (4%) - Check inventory
#
# The key metric is NOPM (New Orders Per Minute) — higher is better.
# tpmC (transactions per minute C) is also reported.
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
PG_DBNAME="${PG_DBNAME:-tpcc_benchdb}"
PGPASSWORD="${PGPASSWORD:-}"

HAMMERDB_HOME="${HAMMERDB_HOME:-/opt/HammerDB}"
WAREHOUSES="${WAREHOUSES:-100}"
VIRTUAL_USERS="${VIRTUAL_USERS:-32}"
RAMPUP_MINUTES="${RAMPUP_MINUTES:-2}"
DURATION_MINUTES="${DURATION_MINUTES:-10}"
RESULTS_DIR="${RESULTS_DIR:-./results}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

log() { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"; }
success() { echo -e "${GREEN}[$(date +%H:%M:%S)] ✓${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠${NC} $1"; }
error() { echo -e "${RED}[$(date +%H:%M:%S)] ✗${NC} $1"; exit 1; }

# =============================================================================
# Parse arguments
# =============================================================================

usage() {
cat << 'EOF'
Usage: run-tpcc-benchmark.sh [OPTIONS]

HammerDB TPC-C Benchmark - MinervaDB PostgreSQL Benchmarking Toolkit

Options:
  --host HOST          PostgreSQL host (default: localhost)
  --port PORT          PostgreSQL port (default: 5432)
  --user USER          PostgreSQL user (default: postgres)
  --dbname DBNAME      Database name (default: tpcc_benchdb)
  --warehouses N       Number of TPC-C warehouses (default: 100)
  --virtual-users N    Number of virtual users (default: 32)
  --rampup MINUTES     Ramp-up time in minutes (default: 2)
  --duration MINUTES   Test duration in minutes (default: 10)
  --hammerdb-home DIR  HammerDB installation directory
  --output DIR         Results directory
  --skip-build         Skip schema build (use existing data)

Scale Guide:
  Warehouses 10:   Small test (~500MB)
  Warehouses 100:  Medium benchmark (~5GB)
  Warehouses 500:  Large benchmark (~25GB)
  Warehouses 1000: Production-scale (~50GB)

Notes:
  - Warehouses should be >= virtual users for meaningful results
  - Each warehouse requires approximately 50MB of storage
  - Building schema: ~1 minute per warehouse (estimate)

EOF
exit 0
}

SKIP_BUILD=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --host) PG_HOST="$2"; shift 2 ;;
        --port) PG_PORT="$2"; shift 2 ;;
        --user) PG_USER="$2"; shift 2 ;;
        --dbname) PG_DBNAME="$2"; shift 2 ;;
        --warehouses) WAREHOUSES="$2"; shift 2 ;;
        --virtual-users) VIRTUAL_USERS="$2"; shift 2 ;;
        --rampup) RAMPUP_MINUTES="$2"; shift 2 ;;
        --duration) DURATION_MINUTES="$2"; shift 2 ;;
        --hammerdb-home) HAMMERDB_HOME="$2"; shift 2 ;;
        --output) RESULTS_DIR="$2"; shift 2 ;;
        --skip-build) SKIP_BUILD=true; shift ;;
        --help) usage ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

mkdir -p "${RESULTS_DIR}"
RESULT_FILE="${RESULTS_DIR}/tpcc-${RUN_ID}"
export PGPASSWORD

# =============================================================================
# Pre-flight
# =============================================================================

preflight() {
    log "Pre-flight checks..."
    
    [ -d "${HAMMERDB_HOME}" ] || error "HammerDB not found at ${HAMMERDB_HOME}"
    [ -f "${HAMMERDB_HOME}/hammerdb" ] || error "hammerdb executable not found"
    
    command -v tclsh &>/dev/null || error "tclsh not found. Install: apt-get install tcl"
    command -v psql &>/dev/null || error "psql not found"
    
    psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d postgres \
        -c "SELECT 1;" > /dev/null || error "Cannot connect to PostgreSQL"
    
    TOTAL_DURATION_MIN=$(( RAMPUP_MINUTES + DURATION_MINUTES ))
    log "Estimated total time: ~${TOTAL_DURATION_MIN} minutes"
    log "Data size estimate: ~$(( WAREHOUSES * 50 ))MB"
    
    success "Pre-flight passed"
}

# =============================================================================
# Create database
# =============================================================================

create_database() {
    log "Creating TPC-C database: ${PG_DBNAME}..."
    psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d postgres \
        -c "CREATE DATABASE ${PG_DBNAME};" 2>/dev/null || \
        warn "Database already exists (will use existing)"
    success "Database ready"
}

# =============================================================================
# Build TPC-C schema and load data
# =============================================================================

build_schema() {
    if [ "${SKIP_BUILD}" = "true" ]; then
        warn "Skipping schema build (--skip-build)"
        return
    fi
    
    log "Building TPC-C schema with ${WAREHOUSES} warehouses..."
    warn "This may take 1-5 minutes per warehouse. Estimated: $(( WAREHOUSES * 2 )) minutes"
    
    HAMMERDB_BUILD_SCRIPT="${RESULT_FILE}-build.tcl"
    cat > "${HAMMERDB_BUILD_SCRIPT}" << ENDTCL
dbset db pg
dbset bm TPC-C
diset connection pg_host ${PG_HOST}
diset connection pg_port ${PG_PORT}
diset connection pg_sslmode prefer
diset tpcc pg_count_ware ${WAREHOUSES}
diset tpcc pg_num_vu 8
diset tpcc pg_superuser ${PG_USER}
diset tpcc pg_superuserpass ${PGPASSWORD:-postgres}
diset tpcc pg_defaultdbase ${PG_DBNAME}
diset tpcc pg_vacuum true
diset tpcc pg_allwarehouse true
diset tpcc pg_timeprofile false
print dict
buildschema
waittocomplete
vudestroy
exit
ENDTCL
    
    cd "${HAMMERDB_HOME}"
    ./hammerdb < "${HAMMERDB_BUILD_SCRIPT}" 2>&1 | tee "${RESULT_FILE}-build.log"
    
    success "TPC-C schema built with ${WAREHOUSES} warehouses"
    
    # Post-build optimize
    log "Running VACUUM ANALYZE and CHECKPOINT..."
    psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DBNAME}" \
        -c "VACUUM ANALYZE; CHECKPOINT;" > /dev/null
}

# =============================================================================
# Run TPC-C benchmark
# =============================================================================

run_tpcc() {
    log "Starting TPC-C benchmark..."
    log "Virtual Users: ${VIRTUAL_USERS} | Warehouses: ${WAREHOUSES}"
    log "Ramp-up: ${RAMPUP_MINUTES}min | Duration: ${DURATION_MINUTES}min"
    
    HAMMERDB_RUN_SCRIPT="${RESULT_FILE}-run.tcl"
    cat > "${HAMMERDB_RUN_SCRIPT}" << ENDTCL
dbset db pg
dbset bm TPC-C
diset connection pg_host ${PG_HOST}
diset connection pg_port ${PG_PORT}
diset tpcc pg_count_ware ${WAREHOUSES}
diset tpcc pg_num_vu ${VIRTUAL_USERS}
diset tpcc pg_superuser ${PG_USER}
diset tpcc pg_superuserpass ${PGPASSWORD:-postgres}
diset tpcc pg_defaultdbase ${PG_DBNAME}
diset tpcc pg_rampup ${RAMPUP_MINUTES}
diset tpcc pg_duration ${DURATION_MINUTES}
diset tpcc pg_allwarehouse true
diset tpcc pg_timeprofile false
diset tpcc pg_vacuum false
loadscript
vuset logtotemp 1
vuset showoutput 1
tcstart
tcstatus
after $(( (RAMPUP_MINUTES + DURATION_MINUTES + 1) * 60000 ))
vudestroy
exit
ENDTCL
    
    cd "${HAMMERDB_HOME}"
    ./hammerdb < "${HAMMERDB_RUN_SCRIPT}" 2>&1 | tee "${RESULT_FILE}-results.txt"
    
    success "TPC-C benchmark complete"
}

# =============================================================================
# Parse and display results  
# =============================================================================

display_results() {
    echo ""
    echo -e "${BOLD}================================================================${NC}"
    echo -e "${BOLD}  MinervaDB TPC-C Benchmark Results${NC}"
    echo -e "${BOLD}================================================================${NC}"
    echo ""
    echo "  Run ID:      ${RUN_ID}"
    echo "  Warehouses:  ${WAREHOUSES}"
    echo "  Virtual Users: ${VIRTUAL_USERS}"
    echo "  Duration:    ${DURATION_MINUTES} minutes"
    echo ""
    
    # Extract NOPM from results
    if grep -q "NOPM" "${RESULT_FILE}-results.txt" 2>/dev/null; then
        NOPM=$(grep "NOPM" "${RESULT_FILE}-results.txt" | tail -1 | grep -oE '[0-9,]+' | head -1)
        TPMC=$(grep "TPM" "${RESULT_FILE}-results.txt" | tail -1 | grep -oE '[0-9,]+' | head -1 || echo "N/A")
        
        echo -e "  ${GREEN}NOPM (New Orders/Min):  ${NOPM}${NC}"
        echo -e "  ${GREEN}tpmC (Trans/Min C):     ${TPMC}${NC}"
    else
        echo "  Results: ${RESULT_FILE}-results.txt"
        echo "  (Check log file for NOPM metric)"
    fi
    
    echo ""
    echo "  Log: ${RESULT_FILE}-results.txt"
    echo -e "${BOLD}================================================================${NC}"
    echo ""
    
    # NOPM Interpretation Guide
    echo "  NOPM Reference Guide:"
    echo "  ─────────────────────────────────────────"
    echo "  < 10,000 NOPM    → Entry-level server or small config"
    echo "  10K - 50K NOPM   → Mid-tier production (8-16 cores)"
    echo "  50K - 200K NOPM  → High-performance (32-64 cores)"
    echo "  200K+ NOPM       → Enterprise-scale hardware"
    echo "  ─────────────────────────────────────────"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo -e "${BOLD}MinervaDB PostgreSQL Benchmarking Toolkit — TPC-C${NC}"
    echo "Run ID: ${RUN_ID}"
    echo ""
    
    preflight
    create_database
    build_schema
    run_tpcc
    display_results
    
    success "TPC-C benchmark complete! Results: ${RESULTS_DIR}/"
}

main "$@"
