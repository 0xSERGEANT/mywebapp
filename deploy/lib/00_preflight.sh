# shellcheck shell=bash
# Preflight: sanity checks before we mutate anything.

set -euo pipefail
IFS=$'\n\t'

if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    distro="${NAME:-unknown}"
    release="${VERSION_ID:-unknown}"
else
    if ! command -v lsb_release >/dev/null; then
        apt-get update -qq && apt-get install -y -qq lsb-release
    fi
    distro="$(lsb_release -is 2>/dev/null || echo unknown)"
    release="$(lsb_release -rs 2>/dev/null || echo unknown)"
fi

echo "preflight: detected ${distro} ${release}"

if [[ ! "$distro" =~ ^(Debian|Ubuntu) ]]; then
    echo "preflight: this installer targets Debian/Ubuntu (got ${distro}); aborting" >&2
    exit 1
fi

export CURRENT_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
echo "preflight: installer invoked by ${CURRENT_USER}"

network_up=0
for mirror in deb.debian.org archive.ubuntu.com; do
    if ping -c 1 -W 3 "$mirror" >/dev/null 2>&1; then
        network_up=1
        break
    fi
done

if (( network_up == 0 )); then
    echo "preflight: cannot reach Debian/Ubuntu mirrors — check network" >&2
    exit 1
fi