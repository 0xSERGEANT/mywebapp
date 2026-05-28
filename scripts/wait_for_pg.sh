#!/usr/bin/env bash
# Bounded wait for PostgreSQL to accept TCP connections on 127.0.0.1.
# Used as ExecStartPre= so a slow cold-boot PG does not burn StartLimitBurst.
# Hard cap = 60s.

set -euo pipefail
IFS=$'\n\t'

readonly PG_HOST="${PG_HOST:-127.0.0.1}"
readonly PG_PORT="${PG_PORT:-5432}"
readonly PG_PROBE_USER="${PG_PROBE_USER:-postgres}"
readonly TIMEOUT=60

SECONDS=0

while (( SECONDS < TIMEOUT )); do
    if pg_isready -h "$PG_HOST" -p "$PG_PORT" -U "$PG_PROBE_USER" -t 2 >/dev/null 2>&1; then
        exit 0
    fi
    sleep 1
done

echo "wait_for_pg.sh: timed out after ${TIMEOUT}s waiting for PostgreSQL at ${PG_HOST}:${PG_PORT}" >&2
exit 1