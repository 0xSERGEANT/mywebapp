# shellcheck shell=bash
# Install systemd socket + service units and enable socket activation.

set -euo pipefail
IFS=$'\n\t'

readonly UNITS=(mywebapp.socket mywebapp.service)

install -m 0644 -o root -g root \
    "${REPO_DIR}/deploy/systemd/mywebapp.socket" \
    "${REPO_DIR}/deploy/systemd/mywebapp.service" \
    -t "/etc/systemd/system"

systemctl daemon-reload
systemctl enable "${UNITS[@]}"
systemctl start "${UNITS[@]}"

healthy=0
for ((i=1; i<=15; i++)); do
    if curl -fsS --max-time 1 "http://127.0.0.1:${APP_PORT}/health/alive" >/dev/null 2>&1; then
        echo "systemd: mywebapp is up after ${i}s"
        healthy=1
        break
    fi
    echo "systemd: waiting for app... (${i}/15)"
    sleep 1
done

if (( healthy == 0 )) || ! systemctl is-active --quiet mywebapp.service; then
    echo "systemd: mywebapp.service failed to start or pass health check" >&2
    journalctl -u mywebapp -n 30 --no-pager >&2 || true
    exit 1
fi

echo "systemd: socket and service units installed and running"