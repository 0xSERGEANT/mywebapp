#!/usr/bin/env bash
# Docker entrypoint script for mywebapp

set -euo pipefail

export PG_HOST="${MYWEBAPP_DATABASE_HOST}"
export PG_PORT="${MYWEBAPP_DATABASE_PORT:-5432}"
export PG_PROBE_USER="${MYWEBAPP_DATABASE_USER}"

./scripts/wait_for_pg.sh
./scripts/migrate.sh

exec ./mywebapp