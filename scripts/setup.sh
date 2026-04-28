#!/usr/bin/env bash
set -euo pipefail

info()    { echo -e "\e[32m[INFO]\e[0m  $*"; }
warning() { echo -e "\e[33m[WARN]\e[0m  $*"; }
error()   { echo -e "\e[31m[ERROR]\e[0m $*" >&2; exit 1; }
step()    { echo -e "\e[34m[STEP]\e[0m  ── $* ──"; }

STUDENT_N=11
 
APP_USER="app"
APP_NAME="mywebapp"
APP_DIR="/opt/mywebapp"
CONFIG_DIR="/etc/mywebapp"
 
DB_NAME="mywebapp_database"
DB_USER="mywebapp_user"
DB_PASS="mywebapp_password"
 
APP_HOST="127.0.0.1"
APP_PORT=5200
 
REPO_DIR="/vagrant"

pg() { sudo -u postgres psql -v ON_ERROR_STOP=1 -c "$1"; }
pg_db() { sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$DB_NAME" -c "$1"; }

create_user() {
    local username="$1" is_system="${2:-false}"
 
    if id "$username" &>/dev/null; then
        warning "User '$username' already exists — skipping"
        return
    fi
 
    local extra_flags=()
    getent group "$username" &>/dev/null && extra_flags+=(--gid "$username")
 
    if [[ "$is_system" == "true" ]]; then
        useradd --system --no-create-home --shell /usr/sbin/nologin "${extra_flags[@]}" "$username"
    else
        useradd --create-home --shell /bin/bash "${extra_flags[@]}" "$username"
    fi
 
    info "Created user: $username"
}

step "Installing system packages"
 
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
    postgresql \
    nginx \
    curl \
    build-essential \
    pkg-config \
    libssl-dev \
    sudo
 
info "Packages installed"

if ! command -v cargo &>/dev/null; then
    info "Installing Rust toolchain..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable --profile minimal
fi
 
CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export PATH="$CARGO_HOME/bin:$PATH"
source "$CARGO_HOME/env" 2>/dev/null || true
 
cargo --version || error "cargo not available after installation"

step "Creating users"
 
create_user student
echo "student:12345678"  | chpasswd
usermod -aG sudo student
chage -d 0 student
 
create_user teacher
echo "teacher:12345678"  | chpasswd
usermod -aG sudo teacher
chage -d 0 teacher
 
create_user operator
echo "operator:12345678" | chpasswd
chage -d 0 operator
 
create_user "$APP_USER" true

sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
 
step "Setting up PostgreSQL"
 
systemctl enable postgresql
systemctl start postgresql
 
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
    pg "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
    info "Database user '$DB_USER' created"
else
    warning "Database user '$DB_USER' already exists"
fi
 
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
    pg "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
    info "Database '$DB_NAME' created"
else
    warning "Database '$DB_NAME' already exists"
fi
 
step "Building Rust application"
 
cd "$REPO_DIR"
cargo build --release 2>&1 | tail -5
 
mkdir -p "$APP_DIR"
cp target/release/app      "$APP_DIR/$APP_NAME"
cp target/release/migrator "$APP_DIR/migrator"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"
chmod 750 "$APP_DIR/$APP_NAME" "$APP_DIR/migrator"
 
info "Binaries installed to $APP_DIR"
 
step "Generating configuration file"
 
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_DIR/config.yml" <<EOF
database:
  host: "127.0.0.1"
  user: "$DB_USER"
  password: "$DB_PASS"
  database: "$DB_NAME"
 
server:
  host: "$APP_HOST"
  port: $APP_PORT
EOF
 
chown -R "$APP_USER:$APP_USER" "$CONFIG_DIR"
chmod 640 "$CONFIG_DIR/config.yml"
 
info "Config written to $CONFIG_DIR/config.yml"
 
step "Installing systemd units"
 
cat > /etc/systemd/system/mywebapp.socket <<EOF
[Unit]
Description=mywebapp TCP socket
 
[Socket]
ListenStream=${APP_HOST}:${APP_PORT}
Accept=no
 
[Install]
WantedBy=sockets.target
EOF
 
cat > /etc/systemd/system/mywebapp.service <<EOF
[Unit]
Description=mywebapp — Simple Inventory Web Service
Documentation=https://github.com/0xSERGEANT/mywebapp
After=network.target postgresql.service
Requires=mywebapp.socket
 
[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
 
ExecStartPre=${APP_DIR}/migrator
ExecStart=${APP_DIR}/${APP_NAME}
 
Restart=on-failure
RestartSec=5s
TimeoutStopSec=10s
 
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadOnlyPaths=/etc/mywebapp
PrivateTmp=yes
 
[Install]
WantedBy=multi-user.target
EOF
 
systemctl daemon-reload
systemctl enable mywebapp.socket mywebapp.service
systemctl start  mywebapp.socket
 
info "Socket activated — systemctl status mywebapp.socket"
 
step "Configuring sudo for operator"

cat > /etc/sudoers.d/operator <<'EOF'
Cmnd_Alias MYWEBAPP_CMDS = \
    /bin/systemctl start mywebapp,    \
    /bin/systemctl stop mywebapp,     \
    /bin/systemctl restart mywebapp,  \
    /bin/systemctl status mywebapp,   \
    /usr/bin/systemctl start mywebapp,    \
    /usr/bin/systemctl stop mywebapp,     \
    /usr/bin/systemctl restart mywebapp,  \
    /usr/bin/systemctl status mywebapp,   \
    /bin/systemctl reload nginx,      \
    /usr/bin/systemctl reload nginx
 
operator ALL=(ALL) NOPASSWD: MYWEBAPP_CMDS
EOF
 
chmod 440 /etc/sudoers.d/operator
visudo -c -f /etc/sudoers.d/operator || error "sudoers syntax error!"
 
info "sudo rules installed for operator"
 
step "Configuring Nginx"
 
cat > /etc/nginx/sites-available/mywebapp <<'NGINXEOF'
server {
    listen 80 default_server;
    server_name _;
 
    access_log /var/log/nginx/mywebapp.access.log combined;
    error_log  /var/log/nginx/mywebapp.error.log warn;
 
    proxy_set_header Host            $host;
    proxy_set_header X-Real-IP       $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
 
    location = / {
        proxy_pass http://127.0.0.1:5200;
    }
 
    location ~ ^/items/?$ {
        proxy_pass http://127.0.0.1:5200;
    }
 
    location ~ ^/items/[0-9]+$ {
        proxy_pass http://127.0.0.1:5200;
    }
 
    location / {
        return 404;
    }
}
NGINXEOF
 
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/mywebapp
 
nginx -t || error "Nginx configuration test failed"
systemctl enable nginx
systemctl restart nginx
 
info "Nginx listening on http://0.0.0.0:80"
 
step "Starting mywebapp"
 
for i in {1..10}; do
    sudo -u postgres psql -c '\q' 2>/dev/null && break
    info "Waiting for PostgreSQL... ($i/10)"
    sleep 2
done
 
systemctl start mywebapp.service
sleep 2
 
if systemctl is-active --quiet mywebapp.service; then
    info "mywebapp started successfully ✓"
else
    warning "mywebapp failed to start — check: journalctl -u mywebapp -n 50"
fi
 
step "Creating /home/student/gradebook"
 
echo "$STUDENT_N" > /home/student/gradebook
chown student:student /home/student/gradebook
chmod 644 /home/student/gradebook
 
info "gradebook: $(cat /home/student/gradebook)"
 
step "Locking default user"
 
if id vagrant &>/dev/null; then
    usermod --lock vagrant
    info "User 'vagrant' locked"
else
    warning "User 'vagrant' not found — skipping"
fi
 
cat <<EOF

═══════════════════════════════════════════════════════
  ✓  Deployment completed successfully!
═══════════════════════════════════════════════════════
  Application : http://0.0.0.0:80
  Service     : systemctl status mywebapp
  Nginx logs  : /var/log/nginx/mywebapp.access.log
  Gradebook   : /home/student/gradebook → $STUDENT_N
 
  Testing (from host machine after vagrant up):
    curl http://localhost:8080/
    curl http://localhost:8080/items
═══════════════════════════════════════════════════════
EOF
