# shellcheck shell=bash
# Install nginx site config (allow-list proxy; health endpoints blocked).

set -euo pipefail
IFS=$'\n\t'

readonly NGINX_CONF_NAME="mywebapp.conf"
readonly SITES_AVAILABLE="/etc/nginx/sites-available"
readonly SITES_ENABLED="/etc/nginx/sites-enabled"

rm -f "${SITES_ENABLED}/default"

install -D -m 0644 -o root -g root \
    "${REPO_DIR}/deploy/nginx/${NGINX_CONF_NAME}" \
    "${SITES_AVAILABLE}/${NGINX_CONF_NAME}"

ln -sf "${SITES_AVAILABLE}/${NGINX_CONF_NAME}" "${SITES_ENABLED}/${NGINX_CONF_NAME}"

nginx -t -q || { echo "nginx: config test failed" >&2; exit 1; }
systemctl reload nginx

echo "nginx: site enabled & reloaded"