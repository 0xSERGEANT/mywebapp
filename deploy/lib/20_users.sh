# shellcheck shell=bash
# Create system + admin users with the required privileges and password policy.

set -euo pipefail
IFS=$'\n\t'

readonly DEFAULT_PASSWORD="12345678"
readonly ADMIN_USERS=(student teacher)
readonly INTERACTIVE_USERS=("${ADMIN_USERS[@]}" operator)

for user in "${ADMIN_USERS[@]}"; do
    id -u "$user" >/dev/null 2>&1 || useradd --create-home --shell /bin/bash "$user"
    usermod -aG sudo "$user"
done

if ! id -u operator >/dev/null 2>&1; then
    groupadd --force operator
    useradd --create-home --shell /bin/bash --gid operator operator
fi

if [[ " $(id -nG operator) " =~ [[:space:]]sudo[[:space:]] ]]; then
    gpasswd -d operator sudo
fi

if ! id -u app >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin app
fi

for user in "${INTERACTIVE_USERS[@]}"; do
    echo "${user}:${DEFAULT_PASSWORD}" | chpasswd
    chage -d 0 "$user"
done

sed -i -E 's/^[# \t]*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd 2>/dev/null || systemctl restart ssh

echo "users: created ${INTERACTIVE_USERS[*]} app"