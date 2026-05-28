# shellcheck shell=bash
# Write /etc/mywebapp/config.yml from template w/ locked-down permissions.

set -euo pipefail
IFS=$'\n\t'

readonly TEMPLATE_FILE="${REPO_DIR}/deploy/config/config.yml.example"

[[ -f "$TEMPLATE_FILE" ]] || {
    echo "config: template not found at ${TEMPLATE_FILE}" >&2
    exit 1
}

install -d -m 0750 -o root -g "${APP_USER}" "${CONFIG_DIR}"

readonly sed_args=(
    -e "s|\${DB_PORT}|${DB_PORT}|g"
    -e "s|\${DB_USER}|${DB_USER}|g"
    -e "s|\${DB_PASS}|${DB_PASS}|g"
    -e "s|\${DB_NAME}|${DB_NAME}|g"
    -e "s|\${APP_HOST}|${APP_HOST}|g"
    -e "s|\${APP_PORT}|${APP_PORT}|g"
)

sed "${sed_args[@]}" "${TEMPLATE_FILE}" > "${CONFIG_FILE}"

chown root:"${APP_USER}" "${CONFIG_FILE}"
chmod 0640 "${CONFIG_FILE}"

echo "config: written to ${CONFIG_FILE} from template"