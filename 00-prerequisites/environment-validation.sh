#!/usr/bin/env bash
# =============================================================================
# MinervaDB PostgreSQL Benchmarking Toolkit
# environment-validation.sh - Pre-benchmark Environment Validation
# =============================================================================
# Validates that all requirements are met before running benchmarks.
# Run this script first to ensure your environment is properly configured.
# =============================================================================

set -euo pipefail

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
PG_DBNAME="${PG_DBNAME:-benchdb}"

# Colors
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

PASS_COUNT=0; WARN_COUNT=0; FAIL_COUNT=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; ((PASS_COUNT++)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; ((WARN_COUNT++)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ((FAIL_COUNT++)); }
section() { echo -e "\n${BOLD}--- $1 ---${NC}"; }

while [[ $# -gt 0 ]]; do
    case $1 in
        --host) PG_HOST="$2"; shift 2 ;;
        --port) PG_PORT="$2"; shift 2 ;;
        --user) PG_USER="$2"; shift 2 ;;
        --dbname) PG_DBNAME="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo -e "${BOLD}"
echo "=================================================================="
echo "  MinervaDB PostgreSQL Benchmarking Toolkit"
echo "  Environment Validation"
echo "=================================================================="
echo -e "${NC}"

# =============================================================================
# Tool Checks
# =============================================================================

section "Benchmark Tools"

for tool in pgbench psql git python3 jq bc; do
    if command -v "${tool}" &>/dev/null; then
        ver=$("${tool}" --version 2>&1 | head -1 | awk '{print $NF}' || echo "ok")
        pass "${tool}: ${ver}"
    else
        fail "${tool}: NOT FOUND — Install: sudo bash 00-prerequisites/install-dependencies.sh"
    fi
done

if command -v sysbench &>/dev/null; then
    pass "sysbench: $(sysbench --version 2>&1)"
else
    warn "sysbench: NOT FOUND (optional, needed for sysbench benchmarks)"
fi

if [ -f "/opt/HammerDB/hammerdb" ] || command -v hammerdb &>/dev/null; then
    pass "HammerDB: installed"
else
    warn "HammerDB: NOT FOUND (optional, needed for TPC-C/TPC-H benchmarks)"
fi

# =============================================================================
# PostgreSQL Connectivity
# =============================================================================

section "PostgreSQL Connection"

if psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DBNAME}" \
        -c "SELECT 1;" &>/dev/null; then
    pass "Connection to ${PG_HOST}:${PG_PORT}/${PG_DBNAME}: OK"
    
    # PostgreSQL version
    PG_VERSION=$(psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DBNAME}" \
                    -At -c "SHOW server_version;")
    PG_MAJOR=$(echo "${PG_VERSION}" | cut -d. -f1)
    
    if [ "${PG_MAJOR}" -ge 15 ] && [ "${PG_MAJOR}" -le 18 ]; then
        pass "PostgreSQL version: ${PG_VERSION} (supported)"
    else
        warn "PostgreSQL version: ${PG_VERSION} (not in supported range 15-18)"
    fi
    
    # Check extensions
    section "PostgreSQL Extensions"
    
    for ext in pg_stat_statements pg_buffercache; do
        if psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DBNAME}" \
                -At -c "SELECT 1 FROM pg_extension WHERE extname='${ext}';" 2>/dev/null | grep -q 1; then
            pass "${ext}: installed"
        else
            warn "${ext}: NOT INSTALLED (recommended for analysis)"
            echo "    Install with: CREATE EXTENSION ${ext};"
        fi
    done
    
    # Check key settings
    section "PostgreSQL Configuration"
    
    SHARED_BUFFERS=$(psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DBNAME}" \
                        -At -c "SELECT setting FROM pg_settings WHERE name='shared_buffers';")
    SHARED_BUFFERS_MB=$((SHARED_BUFFERS * 8 / 1024))
    
    if [ "${SHARED_BUFFERS_MB}" -ge 1024 ]; then
        pass "shared_buffers: ${SHARED_BUFFERS_MB}MB (>= 1GB)"
    elif [ "${SHARED_BUFFERS_MB}" -ge 256 ]; then
        warn "shared_buffers: ${SHARED_BUFFERS_MB}MB (recommend >= 1GB for meaningful benchmarks)"
    else
        fail "shared_buffers: ${SHARED_BUFFERS_MB}MB (too small — benchmark results will be misleading)"
    fi
    
    MAX_CONN=$(psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DBNAME}" \
                  -At -c "SELECT setting FROM pg_settings WHERE name='max_connections';")
    
    if [ "${MAX_CONN}" -ge 100 ]; then
        pass "max_connections: ${MAX_CONN} (adequate)"
    else
        warn "max_connections: ${MAX_CONN} (low — high-concurrency benchmarks may fail)"
    fi
    
    SYNC_COMMIT=$(psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DBNAME}" \
                     -At -c "SELECT setting FROM pg_settings WHERE name='synchronous_commit';")
    pass "synchronous_commit: ${SYNC_COMMIT}"
    
else
    fail "Cannot connect to PostgreSQL at ${PG_HOST}:${PG_PORT}/${PG_DBNAME}"
    echo "  Check: PGPASSWORD, pg_hba.conf, PostgreSQL is running"
fi

# =============================================================================
# System Configuration
# =============================================================================

section "System Configuration"

# RAM
TOTAL_RAM_GB=$(free -g | grep Mem | awk '{print $2}')
if [ "${TOTAL_RAM_GB}" -ge 16 ]; then
    pass "Total RAM: ${TOTAL_RAM_GB}GB (>=16GB recommended)"
elif [ "${TOTAL_RAM_GB}" -ge 8 ]; then
    warn "Total RAM: ${TOTAL_RAM_GB}GB (16GB+ recommended for scale 100+)"
else
    fail "Total RAM: ${TOTAL_RAM_GB}GB (insufficient for meaningful benchmarks)"
fi

# CPU
CPU_CORES=$(nproc)
if [ "${CPU_CORES}" -ge 4 ]; then
    pass "CPU cores: ${CPU_CORES}"
else
    warn "CPU cores: ${CPU_CORES} (4+ recommended)"
fi

# THP check
if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
    THP=$(cat /sys/kernel/mm/transparent_hugepage/enabled)
    if echo "${THP}" | grep -q "\[never\]"; then
        pass "Transparent Huge Pages: disabled (optimal)"
    else
        warn "Transparent Huge Pages: ENABLED — disable for accurate benchmarks"
        echo "    Fix: echo never > /sys/kernel/mm/transparent_hugepage/enabled"
    fi
fi

# CPU governor
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
    if [ "${GOV}" = "performance" ]; then
        pass "CPU governor: performance (optimal)"
    else
        warn "CPU governor: ${GOV} (set to 'performance' for consistent benchmarks)"
    fi
fi

# Disk space
AVAIL_DISK=$(df -BG . | tail -1 | awk '{gsub(/G/,""); print $4}')
if [ "${AVAIL_DISK}" -ge 50 ]; then
    pass "Available disk space: ${AVAIL_DISK}GB (>=50GB)"
elif [ "${AVAIL_DISK}" -ge 10 ]; then
    warn "Available disk space: ${AVAIL_DISK}GB (50GB+ recommended)"
else
    fail "Available disk space: ${AVAIL_DISK}GB (insufficient)"
fi

# =============================================================================
# Summary
# =============================================================================

TOTAL=$((PASS_COUNT + WARN_COUNT + FAIL_COUNT))

echo ""
echo -e "${BOLD}=================================================================="
echo "  Validation Summary"
echo "=================================================================="
echo -e "${NC}"
echo -e "  ${GREEN}Passed:${NC}   ${PASS_COUNT}/${TOTAL}"
echo -e "  ${YELLOW}Warnings:${NC} ${WARN_COUNT}/${TOTAL}"
echo -e "  ${RED}Failed:${NC}   ${FAIL_COUNT}/${TOTAL}"
echo ""

if [ "${FAIL_COUNT}" -gt 0 ]; then
    echo -e "  ${RED}✗ Environment has critical issues. Fix failed checks before benchmarking.${NC}"
    exit 1
elif [ "${WARN_COUNT}" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠ Environment ready with warnings. Benchmarks may not reflect optimal performance.${NC}"
    exit 0
else
    echo -e "  ${GREEN}✓ Environment is fully validated and ready for benchmarking!${NC}"
    echo ""
    echo "  Next step:"
    echo "    bash examples/example-quick-oltp.sh --host ${PG_HOST}"
    exit 0
fi
