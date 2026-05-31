# shellcheck shell=bash
# Build the Rust application from source and install the binary.

set -euo pipefail
IFS=$'\n\t'

# shellcheck disable=SC1091
[[ -f "$CARGO_HOME/env" ]] && source "$CARGO_HOME/env"

echo "app_build: building release binary..."

cd "$REPO_DIR"
cargo build --release

install -D -m 0750 -o "$APP_USER" -g "$APP_USER" \
    "target/release/mywebapp" "${APP_DIR}/${APP_NAME}"

echo "app_build: binary installed to ${APP_DIR}/${APP_NAME}"