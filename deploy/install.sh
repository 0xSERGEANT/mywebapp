#!/usr/bin/env bash
# mywebapp — single-entry installer for Debian 12 (Bookworm).
# Idempotent: every step guards on current state and converges.

set -euo pipefail
IFS=$'\n\t'

(( EUID == 0 )) || { echo "install.sh: must run as root" >&2; exit 1; }

readonly DEFAULT_USER="${DEFAULT_USER:-}"
readonly HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export REPO_DIR="${HERE%/*}"
export APP_HOST="127.0.0.1"
export APP_PORT=5200
export APP_NAME="mywebapp"
export APP_DIR="/opt/mywebapp"
export APP_USER="app"
export CONFIG_DIR="/etc/mywebapp"
export CONFIG_FILE="${CONFIG_DIR}/config.yml"
export DB_NAME="mywebapp_database"
export DB_USER="mywebapp_user"
export DB_PORT=5432
export STUDENT_N=11

readonly LOG_FILE="/var/log/mywebapp-install.log"
mkdir -p "${LOG_FILE%/*}"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==== install.sh started $(date -Is) ===="

shopt -s nullglob
readonly steps=("$HERE"/lib/[0-9][0-9]_*.sh)

for step in "${steps[@]}"; do
    echo "---- running ${step##*/} ----"
    source "$step"
done

echo "==== install.sh finished $(date -Is) ===="

cat <<EOF

═══════════════════════════════════════════════════════
  ✓  Deployment completed successfully!
═══════════════════════════════════════════════════════
  Application : http://0.0.0.0:80  (host: http://localhost:8080)
  Service     : systemctl status mywebapp
  Nginx logs  : /var/log/nginx/mywebapp.access.log
  DB password : /etc/mywebapp/.pgpass (root-readable only)
  Gradebook   : /home/student/gradebook → ${STUDENT_N}

  Quick test:
    curl -H 'Accept: text/html' http://localhost:8080/
    curl http://localhost:8080/items
═══════════════════════════════════════════════════════
EOF