#!/usr/bin/env bash

set -euo pipefail
[[ "$(id -u)" -eq 0 ]] || { echo "must run as root" >&2; exit 1; }

RUNNER_HOME=/opt/actions-runner
RUNNER_USER=runner
RUNNER_VERSION="${RUNNER_VERSION:-2.319.1}"

detect_arch() {
    case "$(uname -m)" in
        x86_64)  echo x64 ;;
        aarch64|arm64) echo arm64 ;;
        *) echo "unsupported arch" >&2; exit 1 ;;
    esac
}
RUNNER_ARCH="${RUNNER_ARCH:-$(detect_arch)}"

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    ca-certificates curl gnupg lsb-release jq git openssh-client

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

if ! id -u "$RUNNER_USER" >/dev/null 2>&1; then
    useradd --system --create-home --home-dir "$RUNNER_HOME" --shell /bin/bash "$RUNNER_USER"
fi
usermod -aG docker "$RUNNER_USER" || true

ARCHIVE="actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
if [[ ! -f "${RUNNER_HOME}/config.sh" ]]; then
    curl -fsSL -o "/tmp/${ARCHIVE}" \
        "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${ARCHIVE}"
    sudo -u "$RUNNER_USER" tar -xzf "/tmp/${ARCHIVE}" -C "$RUNNER_HOME"
    rm -f "/tmp/${ARCHIVE}"
fi

cat <<'EOF'

==============================================================================
Runner downloaded but NOT registered (has to be done manually).

  1. Open: https://github.com/0xSERGEANT/mywebapp/settings/actions/runners/new
     pick: Linux x64. Copy the --token value GitHub shows.

  2. Run on runner VM:
        cd /opt/actions-runner
        sudo -u runner ./config.sh \
           --url https://github.com/0xSERGEANT/mywebapp \
           --token <PASTE_TOKEN_HERE> \
           --labels vm-runner \
           --unattended

  3. Install runner as a service:
        sudo ./svc.sh install runner
        sudo ./svc.sh start
==============================================================================

EOF
