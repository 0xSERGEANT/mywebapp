# shellcheck shell=bash
# Configure PostgreSQL: bind to localhost only, create role + database.

set -euo pipefail
IFS=$'\n\t'

readonly PGPASS_FILE="/etc/mywebapp/.pgpass"
install -d -m 0750 -o root -g root "/etc/mywebapp"

if [[ -f "$PGPASS_FILE" ]]; then
    DB_PASS="$(<"$PGPASS_FILE")"
    echo "postgres: reusing password from ${PGPASS_FILE}"
else
    DB_PASS="$(openssl rand -base64 24 | tr -d '/+=')"
    (umask 077; printf '%s' "$DB_PASS" > "$PGPASS_FILE")
    echo "postgres: generated new password → ${PGPASS_FILE}"
fi
export DB_PASS

systemctl enable --now postgresql

PSQL=(sudo -u postgres psql --quiet --no-psqlrc --tuples-only --no-align)
readonly pg_conf=$("${PSQL[@]}" -c 'SHOW config_file;')
readonly hba_conf=$("${PSQL[@]}" -c 'SHOW hba_file;')

pg_restart_needed=0

if ! grep -qE "^[[:space:]]*listen_addresses[[:space:]]*=[[:space:]]*'127\.0\.0\.1'" "$pg_conf"; then
    sed -i -E "s|^[# \t]*listen_addresses[[:space:]]*=.*|listen_addresses = '127.0.0.1'|" "$pg_conf"
    pg_restart_needed=1
fi

readonly desired_hba="host    ${DB_NAME}    ${DB_USER}    127.0.0.1/32    scram-sha-256"

if ! grep -qF "$desired_hba" "$hba_conf"; then
    sed -i -E "/^[# \t]*host[[:space:]]+${DB_NAME}[[:space:]]+${DB_USER}[[:space:]]+127\.0\.0\.1\/32/d" "$hba_conf"
    printf '%s\n' "$desired_hba" >> "$hba_conf"
    pg_restart_needed=1
fi

if (( pg_restart_needed == 1 )); then
    systemctl restart postgresql
fi

if [[ $("${PSQL[@]}" -c "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'") == "1" ]]; then
    "${PSQL[@]}" -v ON_ERROR_STOP=1 -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASS}';" >/dev/null
    echo "postgres: role '${DB_USER}' password updated"
else
    "${PSQL[@]}" -v ON_ERROR_STOP=1 -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';" >/dev/null
    echo "postgres: role '${DB_USER}' created"
fi

if [[ $("${PSQL[@]}" -c "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'") == "1" ]]; then
    echo "postgres: database '${DB_NAME}' already exists"
else
    "${PSQL[@]}" -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" >/dev/null
    echo "postgres: database '${DB_NAME}' created"
fi