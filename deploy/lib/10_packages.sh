# shellcheck shell=bash
# Install OS packages required to build & run mywebapp.

set -euo pipefail
IFS=$'\n\t'

export DEBIAN_FRONTEND=noninteractive
export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export PATH="$CARGO_HOME/bin:$PATH"

readonly PACKAGES=(
    build-essential
    pkg-config
    libssl-dev
    postgresql
    postgresql-client
    nginx
    curl
    ca-certificates
    sudo
    openssh-server
)

readonly SERVICES=(
    postgresql.service
    nginx.service
    ssh.service
)

readonly RUSTUP_URL="https://sh.rustup.rs"
readonly RUSTUP_ARGS=(
    -y
    --default-toolchain stable
    --profile minimal
)

apt-get update -qq
apt-get install -y -qq --no-install-recommends "${PACKAGES[@]}"

systemctl enable --now "${SERVICES[@]}"

echo "packages: installed"

if command -v cargo >/dev/null 2>&1; then
    echo "rust: $(cargo --version) already present — skipping install"
else
    echo "rust: installing stable toolchain via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf "$RUSTUP_URL" | sh -s -- "${RUSTUP_ARGS[@]}"
    source "$CARGO_HOME/env"
fi

command -v cargo >/dev/null 2>&1 || { echo "rust: cargo not available after install" >&2; exit 1; }