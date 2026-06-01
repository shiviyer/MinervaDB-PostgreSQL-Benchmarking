#!/usr/bin/env bash
# =============================================================================
# MinervaDB PostgreSQL Benchmarking Toolkit
# collect-pg-stats.sh - Comprehensive pg_stat_* Data Collector
# =============================================================================
# Collects all key PostgreSQL statistics during or after a benchmark run.
# Captures point-in-time snapshots of:
#   - pg_stat_activity (current connections and queries)
#   - pg_stat_bgwriter (checkpoint and buffer statistics)
#   - pg_stat_database (per-database I/O and transaction stats)
#   - pg_stat_user_tables (table-level access patterns)
#   - pg_stat_user_indexes (index usage statistics)
#   - pg_stat_statements (query-level performance)
#   - pg_locks (lock information)
#   - pg_stat_io (PG16+ detailed I/O stats)
#   - pg_stat_wal (WAL statistics)
# =============================================================================

set -euo pipefail

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
PG_DBNAME="${PG_DBNAME:-benchdb}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/pg-stats}"
INTERVAL="${INTERVAL:-0}"    # 0 = single snapshot, N = collect every N seconds
DURATION="${DURATION:-300}"  # Total duration for interval collection

GREEN='\033[0;32m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
log() { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"; }
success() { echo -e "${GREEN}[$(date +%H:%M:%S)] ✓${NC} $1"; }

while [[ $# -gt 0 ]]; do
    case $1 in
        --host) PG_HOST="$2"; shift 2 ;;
        --port) PG_PORT="$2"; shift 2 ;;
        --user) PG_USER="$2"; shift 2 ;;
        --dbname) PG_DBNAME="$2"; shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        --duration) DURATION="$2"; shift 2 ;;
        *) shift ;;
    esac
done

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SNAPSHOT_DIR="${OUTPUT_DIR}/${TIMESTAMP}"
mkdir -p "${SNAPSHOT_DIR}"

PSQL="psql -h ${PG_HOST} -p ${PG_PORT} -U ${PG_USER} -d ${PG_DBNAME}"

# =============================================================================
# Collection Functions
# =============================================================================

collect_snapshot() {
    local SNAP_TIMESTAMP="$(date -Iseconds)"
    local SNAP_FILE="${SNAPSHOT_DIR}/snapshot-$(date +%H%M%S).sql"
    
    ${PSQL} << SQLEOF > "${SNAP_FILE}" 2>&1

\echo '======================================================================'
\echo 'MinervaDB PostgreSQL Benchmarking Toolkit - Statistics Snapshot'
\echo 'Timestamp: ${SNAP_TIMESTAMP}'
\echo 'Host: ${PG_HOST}:${PG_PORT}/${PG_DBNAME}'
\echo '======================================================================'

\echo '\n--- PostgreSQL Version ---'
SELECT version();

\echo '\n--- Active Connections Summary ---'
SELECT
    state,
    wait_event_type,
    wait_event,
    count(*) AS count,
    max(now() - query_start) AS max_query_duration
FROM pg_stat_activity
WHERE pid != pg_backend_pid()
GROUP BY state, wait_event_type, wait_event
ORDER BY count DESC;

\echo '\n--- Long Running Queries (>1s) ---'
SELECT
    pid,
    state,
    wait_event_type || '.' || COALESCE(wait_event,'') AS wait,
    round(extract(epoch from (now() - query_start))::numeric, 1) AS query_age_s,
    left(query, 100) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
  AND query_start < now() - interval '1 second'
  AND pid != pg_backend_pid()
ORDER BY query_start;

\echo '\n--- Lock Waits ---'
SELECT
    blocked.pid AS blocked_pid,
    blocked.usename AS blocked_user,
    blocked.query AS blocked_query,
    blocking.pid AS blocking_pid,
    blocking.usename AS blocking_user,
    blocking.query AS blocking_query
FROM pg_stat_activity AS blocked
JOIN pg_stat_activity AS blocking ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE NOT blocked.granted LIMIT 10;

\echo '\n--- pg_stat_bgwriter ---'
SELECT
    checkpoints_timed,
    checkpoints_req,
    checkpoint_write_time,
    checkpoint_sync_time,
    buffers_checkpoint,
    buffers_clean,
    maxwritten_clean,
    buffers_backend,
    buffers_backend_fsync,
    buffers_alloc,
    stats_reset
FROM pg_stat_bgwriter;

\echo '\n--- Database Statistics ---'
SELECT
    datname,
    numbackends,
    xact_commit,
    xact_rollback,
    blks_read,
    blks_hit,
    round(blks_hit::numeric / NULLIF(blks_hit+blks_read, 0) * 100, 3) AS cache_hit_pct,
    tup_returned,
    tup_fetched,
    tup_inserted,
    tup_updated,
    tup_deleted,
    conflicts,
    temp_files,
    temp_bytes,
    deadlocks,
    checksum_failures
FROM pg_stat_database
WHERE datname NOT IN ('template0', 'template1')
ORDER BY xact_commit DESC;

\echo '\n--- Top Tables by Access (User Tables) ---'
SELECT
    schemaname,
    relname AS table_name,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    n_tup_ins,
    n_tup_upd,
    n_tup_del,
    n_live_tup,
    n_dead_tup,
    round(n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0) * 100, 2) AS dead_tup_pct,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY seq_scan + idx_scan DESC
LIMIT 20;

\echo '\n--- Unused Indexes ---'
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan AS times_used
FROM pg_stat_user_indexes
JOIN pg_index USING (indexrelid)
WHERE idx_scan = 0
  AND NOT indisunique
  AND NOT indisprimary
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 10;

\echo '\n--- Top Indexes by Usage ---'
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC
LIMIT 20;

\echo '\n--- pg_stat_statements (Top 20 by Total Time) ---'
SELECT
    calls,
    round(total_exec_time::numeric, 2) AS total_ms,
    round(mean_exec_time::numeric, 2) AS avg_ms,
    round(stddev_exec_time::numeric, 2) AS stddev_ms,
    round(min_exec_time::numeric, 2) AS min_ms,
    round(max_exec_time::numeric, 2) AS max_ms,
    rows,
    shared_blks_hit,
    shared_blks_read,
    round(shared_blks_hit::numeric / NULLIF(shared_blks_hit+shared_blks_read, 0) * 100, 2) AS cache_hit_pct,
    local_blks_hit,
    temp_blks_read,
    temp_blks_written,
    left(query, 80) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

\echo '\n--- WAL Statistics ---'
SELECT
    wal_records,
    wal_fpi,
    wal_bytes,
    wal_buffers_full,
    wal_write,
    wal_sync,
    wal_write_time,
    wal_sync_time,
    stats_reset
FROM pg_stat_wal;

SQLEOF

    success "Snapshot saved: ${SNAP_FILE}"
}

collect_io_stats() {
    # pg_stat_io available in PostgreSQL 16+
    local PG_MAJOR
    PG_MAJOR=$(${PSQL} -At -c "SHOW server_version_num;" | cut -c1-2)
    
    if [ "${PG_MAJOR}" -ge 16 ]; then
        local IO_FILE="${SNAPSHOT_DIR}/pg-stat-io-$(date +%H%M%S).txt"
        ${PSQL} << IOEOF > "${IO_FILE}" 2>&1

\echo '--- pg_stat_io (PostgreSQL 16+) ---'
SELECT
    backend_type,
    object,
    context,
    reads,
    read_time,
    writes,
    write_time,
    writebacks,
    writeback_time,
    extends,
    extend_time,
    op_bytes,
    hits,
    evictions,
    reuses,
    fsyncs,
    fsync_time,
    stats_reset
FROM pg_stat_io
WHERE reads > 0 OR writes > 0 OR hits > 0
ORDER BY backend_type, object, context;
IOEOF
        success "pg_stat_io saved: ${IO_FILE}"
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo -e "${BOLD}MinervaDB PostgreSQL Statistics Collector${NC}"
    echo "Host: ${PG_HOST}:${PG_PORT}/${PG_DBNAME}"
    echo "Output: ${SNAPSHOT_DIR}/"
    echo ""
    
    # Validate connection
    ${PSQL} -c "SELECT 1;" > /dev/null || {
        echo "ERROR: Cannot connect to PostgreSQL"
        exit 1
    }
    
    if [ "${INTERVAL}" -eq 0 ]; then
        log "Collecting single statistics snapshot..."
        collect_snapshot
        collect_io_stats
    else
        log "Collecting statistics every ${INTERVAL}s for ${DURATION}s..."
        local END_TIME=$(( $(date +%s) + DURATION ))
        local ITERATION=0
        
        while [ "$(date +%s)" -lt "${END_TIME}" ]; do
            ITERATION=$(( ITERATION + 1 ))
            log "Snapshot ${ITERATION} ($(( END_TIME - $(date +%s) ))s remaining)..."
            collect_snapshot
            sleep "${INTERVAL}"
        done
    fi
    
    success "Statistics collection complete!"
    echo ""
    echo "  Output directory: ${SNAPSHOT_DIR}/"
    echo "  Files collected: $(ls ${SNAPSHOT_DIR}/*.txt 2>/dev/null | wc -l || echo 0)"
}

main "$@"
