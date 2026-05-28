# shellcheck shell=bash
# Final hardening: gradebook, sshd assertions, default-user lockout.

set -euo pipefail
IFS=$'\n\t'

readonly PROTECTED_USERS="^(student|teacher|operator)$"
readonly GRADEBOOK="/home/student/gradebook"

install -m 0644 -o student -g student /dev/null "$GRADEBOOK"
echo "$STUDENT_N" > "$GRADEBOOK"
echo "lockout: gradebook written → ${STUDENT_N}"

readonly sshd_cfg="$(sshd -T 2>/dev/null || true)"

if [[ ! "$sshd_cfg" =~ (^|$'\n')passwordauthentication[[:space:]]+yes($|$'\n') ]]; then
    echo "lockout: sshd passwordauthentication is not 'yes'; aborting" >&2
    exit 1
fi

getent passwd operator >/dev/null || { echo "lockout: operator user missing; aborting" >&2; exit 1; }

if [[ "$sshd_cfg" =~ (^|$'\n')denyusers[[:space:]]+.*\boperator\b ]]; then
    echo "lockout: operator is in sshd DenyUsers; aborting" >&2
    exit 1
fi

if [[ -z "$DEFAULT_USER" ]]; then
    echo "lockout: DEFAULT_USER not set — skipping default user lockout"
elif [[ "$DEFAULT_USER" =~ $PROTECTED_USERS ]]; then
    echo "lockout: default user '${DEFAULT_USER}' is protected — skipping"
elif id "$DEFAULT_USER" >/dev/null 2>&1; then
    usermod --lock "$DEFAULT_USER"
    echo "lockout: locked default user '${DEFAULT_USER}'"
else
    echo "lockout: default user '${DEFAULT_USER}' absent — skipping"
fi