#!/usr/bin/env bash
# Idempotent, version-aware migration runner.

set -euo pipefail
IFS=$'\n\t'

readonly MIGRATIONS_DIR="${MIGRATIONS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/migrations}"
readonly BIN_PATH="${BIN_PATH:-$(dirname "${BASH_SOURCE[0]}")/../mywebapp}"
readonly DB_URL="$("$BIN_PATH" --print-db-url)"

PSQL_ARGS=(
    psql 
    --quiet 
    --no-psqlrc 
    --set=ON_ERROR_STOP=1
    --dbname="$DB_URL"
)

"${PSQL_ARGS[@]}" --file="$MIGRATIONS_DIR/schema_version.sql"

readonly current_version=$("${PSQL_ARGS[@]}" --tuples-only --no-align \
    --command='SELECT COALESCE(MAX(version), 0) FROM schema_version;')

shopt -s nullglob
migrations=("$MIGRATIONS_DIR"/[0-9][0-9][0-9]_*.sql)
applied=0

for sql in "${migrations[@]}"; do
    fname="${sql##*/}"
    version=$((10#${fname%%_*}))
    
    (( version <= current_version )) && continue

    echo "migrate.sh: applying ${fname} (version ${version})"
    
    "${PSQL_ARGS[@]}" --single-transaction --file=<(
        cat "$sql"
        echo "INSERT INTO schema_version (version) VALUES (${version});"
    )
    
    applied=$((applied + 1))
done

if (( applied == 0 )); then
    echo "migrate.sh: schema already at version ${current_version}, nothing to do"
else
    echo "migrate.sh: applied ${applied} migration(s)"
fi