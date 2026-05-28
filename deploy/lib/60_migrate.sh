#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail
IFS=$'\n\t'

install -d -m 0755 -o root -g root "${APP_DIR}/scripts" "${APP_DIR}/migrations"

install -m 0750 -o root -g "$APP_USER" \
    "${REPO_DIR}/scripts/migrate.sh" \
    "${REPO_DIR}/scripts/wait_for_pg.sh" \
    -t "${APP_DIR}/scripts/"

shopt -s nullglob
migrations=("${REPO_DIR}"/migrations/*.sql)

if (( ${#migrations[@]} > 0 )); then
    install -m 0644 -o root -g root "${migrations[@]}" -t "${APP_DIR}/migrations/"
fi

sudo -u "$APP_USER" env \
    MYWEBAPP_CONFIG="$CONFIG_FILE" \
    BIN_PATH="${APP_DIR}/mywebapp" \
    MIGRATIONS_DIR="${APP_DIR}/migrations" \
    "${APP_DIR}/scripts/migrate.sh"

echo "migrate: done"