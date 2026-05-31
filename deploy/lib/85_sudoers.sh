# shellcheck shell=bash
# Install /etc/sudoers.d/operator-mywebapp atomically with visudo validation.

set -euo pipefail
IFS=$'\n\t'

readonly SRC_FILE="${REPO_DIR}/deploy/sudoers/operator-mywebapp"
readonly DST_FILE="/etc/sudoers.d/operator-mywebapp"

tmp="$(mktemp)"
readonly tmp
trap 'rm -f "$tmp"' EXIT

cp "$SRC_FILE" "$tmp"
sed -i 's/\r$//' "$tmp"
visudo -cf "$tmp" || { echo "sudoers: visudo rejected the fragment — aborting" >&2; exit 1; }
install -m 0440 -o root -g root "$tmp" "$DST_FILE"

echo "sudoers: operator-mywebapp installed"