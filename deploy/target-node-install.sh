#!/usr/bin/env bash

set -euo pipefail
[[ "$(id -u)" -eq 0 ]] || { echo "must run as root" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_HOME=/opt/mywebapp

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    ca-certificates curl gnupg lsb-release ufw python3

if ! command -v docker >/dev/null 2>&1; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker

install -d -m 0750 -o root -g root "${APP_HOME}"
install -d -m 0755 -o root -g root "${APP_HOME}/nginx"

install -m 0644 "${REPO_ROOT}/docker-compose.prod.yml" "${APP_HOME}/compose.prod.yml"
install -m 0644 "${REPO_ROOT}/deploy/nginx/mywebapp.compose.conf" "${APP_HOME}/nginx/mywebapp.compose.conf"

ENV_FILE="${APP_HOME}/.env"
if [[ ! -f "$ENV_FILE" ]]; then
    PG_PW="$(openssl rand -hex 24)"
    cat > "$ENV_FILE" <<EOF
IMAGE=ghcr.io/0xsergeant/mywebapp:stable
MYWEBAPP_DATABASE_HOST=db
MYWEBAPP_DATABASE_PORT=5432
MYWEBAPP_DATABASE_USER=mywebapp_user
MYWEBAPP_DATABASE_PASSWORD=${PG_PW}
MYWEBAPP_DATABASE_NAME=mywebapp_database
NGINX_PORT_MAP=80
EOF
    chmod 0640 "$ENV_FILE"
    echo "Generated .env with new DB password"
else
    echo ".env already exists — secrets preserved"
fi

install -m 0644 "${REPO_ROOT}/deploy/systemd/mywebapp-container.service" \
    /etc/systemd/system/mywebapp-container.service
systemctl daemon-reload
systemctl enable mywebapp-container.service

ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw --force enable

cat <<'EOF'

=========================================================================
Target node setup complete. Next steps:
    
    1. Add deploy SSH public key to ~/.ssh/authorized_keys
    2. First deployment will trigger the CI/CD pipeline (annotated tag)
=========================================================================

EOF
