# mywebapp: Automated Web Service Deployment

[![OS: Debian 12 Bookworm](https://img.shields.io/badge/OS-Debian_12_Bookworm-red?style=flat-square&logo=debian)](https://www.debian.org/)
[![Stack: Rust/Axum](https://img.shields.io/badge/Stack-Rust_Axum-orange?style=flat-square&logo=rust)](https://github.com/tokio-rs/axum)
[![DB: PostgreSQL](https://img.shields.io/badge/DB-PostgreSQL-blue?style=flat-square&logo=postgresql)](https://www.postgresql.org/)

## 📖 Project Overview

The project is a fully automated deployment of a **Simple Inventory** web service built with **Rust** & **Axum** framework. It uses **Nginx** as a reverse proxy, **PostgreSQL** for data persistence, and **systemd** (w/ socket activation) for process management. The entire deployment is automated via **Vagrant** & **Bash**.

### 🧮 Individual Variant (N=11)

Based on student number **11**, the following variants were applied:

| Variable | Formula | Result | Meaning |
|----------|---------|--------|---------|
| **V2** | `(11 % 2) + 1 = 2` | **2** | PostgreSQL + YAML config file |
| **V3** | `(11 % 3) + 1 = 3` | **3** | Simple Inventory application |
| **V5** | `(11 % 5) + 1 = 2` | **2** | Port **5200** |

---

## ⚙️ System Architecture

```
client → nginx (0.0.0.0:80) → app (127.0.0.1:5200) → PostgreSQL (127.0.0.1:5432)
```

| Component | Address | Port |
|-----------|---------|------|
| Nginx (reverse proxy) | `0.0.0.0` | `80` |
| Web application (Axum) | `127.0.0.1` | `5200` |
| PostgreSQL | `127.0.0.1` | `5432` |

- **Nginx** listens on port 80, proxies only business-logic and root endpoints, and **blocks** health check endpoints from external access.
- **The application** runs as the restricted system user `app` from `/opt/mywebapp`, started via systemd socket activation.
- **PostgreSQL** is bound to localhost only — no external access.
- **Configuration** is stored at `/etc/mywebapp/config.yml` (YAML format).

---

## 🚀 Deployment Guide

### Requirements

- [VirtualBox](https://www.virtualbox.org/)
- [Vagrant](https://www.vagrantup.com/)

### Deploying

Clone the repository and bring up the virtual machine:

```bash
git clone https://github.com/0xSERGEANT/mywebapp
cd mywebapp
vagrant up
```

Vagrant will automatically:
1. Install all required system packages (Rust toolchain, PostgreSQL, Nginx, etc.)
2. Create system users (`student`, `teacher`, `operator`, `app`)
3. Build the Rust application and migrator from source
4. Set up the PostgreSQL database and user
5. Write the configuration file to `/etc/mywebapp/config.yml`
6. Install and enable the systemd socket + service units
7. Run database migrations before the first start
8. Configure Nginx as a reverse proxy
9. Create `/home/student/gradebook` containing the variant number
10. Lock the default `vagrant` user

Once complete, the service is accessible on the host at:

```
http://localhost:8080/
```

### VM Resource Requirements

| Resource | Value |
|----------|-------|
| Base image | `debian/bookworm64` (official Debian 12) |
| CPU | 2 vCPUs |
| RAM | 1024 MB |
| Disk | ~10 GB (default Vagrant box allocation) |

---

## 👤 System Users

| User | Purpose | Privileges |
|------|---------|------------|
| `student` | Project owner / development | Full sudo access; password reset required on first login |
| `teacher` | Grading / inspection | Full sudo access; password reset required on first login |
| `operator` | Service management only | Limited sudo — see below |
| `app` | Application runtime | System user — no login shell, minimal permissions |

**Default password** for `student`, `teacher`, and `operator`: `12345678`
A password change is enforced on first login (`chage -d 0`).

### Operator sudo permissions

The `operator` user may only run:
- `systemctl start mywebapp`
- `systemctl stop mywebapp`
- `systemctl restart mywebapp`
- `systemctl status mywebapp`
- `systemctl reload nginx`

---

## 🌐 Web Application

### Application Topic — Simple Inventory (V3 = 3)

A REST API for tracking inventory items. Each item contains:

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Auto-generated primary key |
| `name` | varchar(255) | Item name |
| `quantity` | integer | Item quantity |
| `created_at` | timestamptz | Creation timestamp |

### Configuration — YAML file (V2 = 2)

The application reads its configuration from `/etc/mywebapp/config.yml`:

```yaml
database:
  host: "127.0.0.1"
  user: "mywebapp_user"
  password: "mywebapp_password"
  database: "mywebapp_database"

server:
  host: "127.0.0.1"
  port: 5200
```

### Database Migration

The `migrator` binary runs as `ExecStartPre` in the systemd service unit. It connects to the database and creates all necessary tables and indexes:

```sql
CREATE TABLE IF NOT EXISTS items (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_items_name ON items(name);
```

The migrator is idempotent — safe to run against an empty or previously-migrated database.

### systemd Socket Activation

The service uses **systemd socket activation**. The socket unit (`mywebapp.socket`) binds `127.0.0.1:5200`. When a connection arrives, systemd passes the file descriptor to the application via `LISTEN_FDS`. This allows the service to start on demand and restart without losing connections.

---

## 🔌 API Reference

All business-logic endpoints support **content negotiation** via the `Accept` header:
- `Accept: application/json` → returns JSON (default)
- `Accept: text/html` → returns a plain HTML page (no JavaScript, no CSS; lists rendered as `<table>`)

### Root

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Lists all available business-logic endpoints. **Requires** `Accept: text/html`. |

### Business Logic Endpoints (proxied through Nginx on port 80)

| Method | Path | Body | Description |
|--------|------|------|-------------|
| `GET` | `/items` | — | List all inventory items (`id`, `name`) |
| `POST` | `/items` | `{"name": "...", "quantity": N}` | Create a new inventory item |
| `GET` | `/items/{id}` | — | Full details of a single item (`id`, `name`, `quantity`, `created_at`) |

### Health Check Endpoints (internal only — blocked by Nginx on port 80)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health/alive` | Always returns `200 OK` with body `OK` |
| `GET` | `/health/ready` | Returns `200 OK` if DB is reachable, `500` otherwise |

---

## 🧪 Testing Guide

All commands below assume the VM is running (`vagrant up`) and the host port is `8080`.

### Root endpoint

```bash
curl -H "Accept: text/html" http://localhost:8080/
```

### Create an inventory item

```bash
curl -X POST http://localhost:8080/items \
     -H "Content-Type: application/json" \
     -d '{"name": "Cisco Router", "quantity": 10}'
```

### List all items — JSON

```bash
curl -H "Accept: application/json" http://localhost:8080/items
```

### List all items — HTML table

```bash
curl -H "Accept: text/html" http://localhost:8080/items
```

### Get a single item

```bash
curl http://localhost:8080/items/1
```

### Health check — liveness (internal only)

```bash
# Blocked via Nginx (returns 404):
curl -i http://localhost:8080/health/alive

# Works directly on internal port inside the VM:
vagrant ssh -c "curl http://127.0.0.1:5200/health/alive"
```

### Health check — readiness (internal only)

```bash
vagrant ssh -c "curl http://127.0.0.1:5200/health/ready"
```

---

## 👨‍🏫 Teacher Grading Instructions

SSH into the VM using the `teacher` account:

```bash
ssh -p 2222 teacher@127.0.0.1
```

**Default password:** `12345678` — you will be forced to set a new password on first login.

### Verify database schema and indexes

```bash
sudo -u postgres psql -d mywebapp_database -c "\d items"
sudo -u postgres psql -d mywebapp_database -c "\di"
```

### Verify operator sudo permissions

```bash
sudo -l -U operator
```

### Verify configuration file (YAML format)

```bash
sudo cat /etc/mywebapp/config.yml
```

### Verify systemd unit (socket activation, ExecStartPre migration, app user)

```bash
systemctl cat mywebapp.socket
systemctl cat mywebapp.service
```

### Verify gradebook

```bash
cat /home/student/gradebook
# Expected output: 11
```

### Check service status

```bash
systemctl status mywebapp.service
systemctl status mywebapp.socket
systemctl status nginx
```