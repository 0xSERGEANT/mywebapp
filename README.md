# mywebapp: Automated Web Service Deployment

[![OS: Debian 12 Bookworm](https://img.shields.io/badge/OS-Debian_12_Bookworm-red?style=flat-square&logo=debian)](https://www.debian.org/)
[![Stack: Rust/Axum](https://img.shields.io/badge/Stack-Rust_Axum-orange?style=flat-square&logo=rust)](https://github.com/tokio-rs/axum)
[![DB: PostgreSQL](https://img.shields.io/badge/DB-PostgreSQL-blue?style=flat-square&logo=postgresql)](https://www.postgresql.org/)

## Project Overview

The project is a fully automated deployment of a **Simple Inventory** REST API built w/ **Rust** & **Axum** framework. The service stores inventory items in **PostgreSQL**, is reverse-proxied by **Nginx**, and is managed by **systemd** w/ socket activation. The entire stack is provisioned from scratch via **Vagrant** & **Bash**.

### Individual Variant (N=11)

| Variable | Formula | Result | Meaning |
|----------|---------|--------|---------|
| **V2** | `(11 % 2) + 1 = 2` | **2** | PostgreSQL + YAML config file |
| **V3** | `(11 % 3) + 1 = 3` | **3** | Simple Inventory application |
| **V5** | `(11 % 5) + 1 = 2` | **2** | Port **5200** |

---

## System Architecture

```
client → nginx (0.0.0.0:80) → app (127.0.0.1:5200) → PostgreSQL (127.0.0.1:5432)
```

| Component | Bind address | Port |
|-----------|-------------|------|
| Nginx (reverse proxy) | `0.0.0.0` | `80` |
| Axum web application | `127.0.0.1` | `5200` |
| PostgreSQL | `127.0.0.1` | `5432` |

- **Nginx** listens on port 80, proxies only the root (`/`), `/items`, and `/items/{id}` endpoints, and returns `404` for health check paths and anything else.
- **The application** runs as the restricted system user `app` from `/opt/mywebapp`, started via systemd socket activation (`mywebapp.socket` → `mywebapp.service`).
- **PostgreSQL** binds to localhost only with `scram-sha-256` authentication — no external access.
- **Configuration** lives at `/etc/mywebapp/config.yml` (YAML, readable by `root` and `app` only).

---

## Deployment Guide

### Requirements

- [VirtualBox](https://www.virtualbox.org/)
- [Vagrant](https://www.vagrantup.com/)

### Deploying

```bash
git clone https://github.com/0xSERGEANT/mywebapp
cd mywebapp
vagrant up
```

`install.sh` sources each `deploy/lib/NN_*.sh` step in numeric order:

1. **Preflight** — OS and network checks
2. **Packages** — `build-essential`, `postgresql`, `nginx`, `openssh-server`, Rust toolchain via `rustup`
3. **Users** — creates `student`, `teacher` (full sudo), `operator` (restricted sudo), `app` (system user, no shell)
4. **PostgreSQL** — localhost-only binding, creates role `mywebapp_user` and database `mywebapp_database`
5. **Build** — `cargo build --release`; binary installed to `/opt/mywebapp/mywebapp`
6. **Config** — writes `/etc/mywebapp/config.yml` from template with generated DB password
7. **Migrate** — runs `migrate.sh` as the `app` user (idempotent, version-tracked)
8. **systemd** — installs socket + service units, enables and starts them, verifies `/health/alive`
9. **Nginx** — deploys allow-list site config, reloads nginx
10. **Sudoers** — installs `operator-mywebapp` fragment via `visudo -c`
11. **Lockout** — writes `/home/student/gradebook`, locks the default `vagrant` user
12. **Verify** — smoke-tests all endpoints from inside the VM

Once complete, the service is accessible on the host at:

```
http://localhost:8080/
```

### Post-install smoke test log

The installer runs `99_verify.sh` automatically. To re-run it manually:

```bash
sudo bash /vagrant/deploy/lib/99_verify.sh
```

Expected output:

```
PASS  health alive (loopback)    (200)
PASS  health ready (loopback)    (200)
PASS  root via nginx             (200)
PASS  items via nginx (json)     (200)
PASS  health blocked externally  (404)
PASS  unknown path 404           (404)
PASS  dotfile 404                (404)
99_verify.sh: all post-install checks passed
```

### VM Resource Requirements

| Resource | Value |
|----------|-------|
| Base image | `debian/bookworm64` |
| CPU | 2 vCPUs |
| RAM | 1024 MB |
| Disk | ~10 GB (default Vagrant box allocation) |

---

## Docker Compose Deployment

The stack can be deployed via Docker Compose using containerized services connected through a custom bridge network (`mywebapp_net`):
- `db`: PostgreSQL 17 database running on Alpine Linux.
- `app`: Containerized Rust/Axum backend server.
- `nginx`: Alpine-based reverse proxy configuration.

### Prerequisites

- Docker
- Docker Compose

### Deployment Strategy

Generate your configuration from the provided blueprint:

```bash
cp .env.example .env
```

Launch the stack in the background:

```bash
docker compose up -d --build
```

### Management Protocols

Check container status:
```bash
docker compose ps
```

Trace logging indicators directly to the console buffer:
```bash
docker compose logs -f
```

Tear down active structural layers:
```bash
docker compose down
```
*(Append `-v` to discard internal volume state mappings permanently).*

---

## Configuration

The application reads `/etc/mywebapp/config.yml` (path overridable via `MYWEBAPP_CONFIG` env var):

```yaml
database:
  host: "127.0.0.1"
  port: 5432
  user: "mywebapp_user"
  password: "<generated at provision time>"
  database: "mywebapp_database"

server:
  host: "127.0.0.1"
  port: 5200
```

The file is owned `root:app`, mode `0640`. The raw password is also stored in `/etc/mywebapp/.pgpass` (mode `0600`, root-readable only) so the install scripts can re-run idempotently.

---

## System Users

| User | Purpose | Privileges |
|------|---------|------------|
| `student` | Project owner / development | Full sudo; forced password reset on first login |
| `teacher` | Grading / inspection | Full sudo; forced password reset on first login |
| `operator` | Service management only | Restricted sudo — see below |
| `app` | Application runtime | System user — no login shell, no home directory |

**Default password** for `student`, `teacher`, and `operator`: `12345678`  
A password change is enforced on first login (`chage -d 0`).

### Operator sudo permissions

`operator` may only run (all require `--no-pager`):

```
systemctl --no-pager start   mywebapp
systemctl --no-pager stop    mywebapp
systemctl --no-pager restart mywebapp
systemctl --no-pager status  mywebapp
systemctl --no-pager reload  nginx
systemctl --no-pager status  nginx
```

---

## Web Application

### Data Model — Simple Inventory

```sql
CREATE TABLE IF NOT EXISTS "items" (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS "idx_items_name" ON "items" (name);
```

The `GET /items` list endpoint returns only `id` and `name` (`ItemListEntry`). The `GET /items/{id}` detail endpoint returns all four fields (`Item`).

### systemd Socket Activation

`mywebapp.socket` binds `127.0.0.1:5200`. When a connection arrives, systemd passes the file descriptor to the application via `LISTEN_FDS` (fd 3). The application falls back to binding the address from config if `LISTEN_FDS` is not set (useful for local development).

`mywebapp.service` runs two `ExecStartPre` steps before the main process:

1. `wait_for_pg.sh` — polls `pg_isready` up to 60 s
2. `migrate.sh` — applies any pending `.sql` migrations from `/opt/mywebapp/migrations/`

### Content Negotiation

All business-logic endpoints inspect the `Accept` header:

| `Accept` value | Response format |
|----------------|-----------------|
| `text/html` | Plain HTML page (`<table>` for lists, no JS/CSS) |
| `application/json` (or anything else) | JSON (default) |

The root endpoint (`GET /`) requires `Accept: text/html` and returns `406 Not Acceptable` otherwise.

---

## API Reference

### Root

| Method | Path | Notes |
|--------|------|-------|
| `GET` | `/` | Lists available endpoints. **Requires** `Accept: text/html`. |

### Business Logic (proxied through Nginx on port 80)

| Method | Path | Body | Response |
|--------|------|------|----------|
| `GET` | `/items` | — | Array of `{id, name}` |
| `POST` | `/items` | `{"name": "...", "quantity": N}` | `201` with full item `{id, name, quantity, created_at}` |
| `GET` | `/items/{id}` | — | Full item or `404` |

### Health (internal only — blocked by Nginx)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health/alive` | Always `200 OK` with body `OK` |
| `GET` | `/health/ready` | `200 OK` if DB responds to `SELECT 1`, otherwise `500` |

---

## Testing Guide

All commands assume `vagrant up` has completed and the host port is `8080`.

```bash
# Root (HTML required)
curl -H "Accept: text/html" http://localhost:8080/

# Create an item
curl -X POST http://localhost:8080/items      -H "Content-Type: application/json"      -d '{"name": "Cisco Router", "quantity": 10}'

# List items — JSON (default)
curl http://localhost:8080/items

# List items — HTML table
curl -H "Accept: text/html" http://localhost:8080/items

# Get a single item
curl http://localhost:8080/items/1

# Health endpoints are blocked externally (returns 404):
curl -i http://localhost:8080/health/alive

# Health endpoints work on the internal port inside the VM:
vagrant ssh -c "curl http://127.0.0.1:5200/health/alive"
vagrant ssh -c "curl http://127.0.0.1:5200/health/ready"
```

---

## Teacher Grading Instructions

SSH into the VM as `teacher` (default password `12345678`; you will be forced to change it):

```bash
ssh -p 2222 teacher@127.0.0.1
```

### Verify database schema and indexes

```bash
sudo -u postgres psql -d mywebapp_database -c "\d items"
sudo -u postgres psql -d mywebapp_database -c "\di"
```

### Verify operator sudo permissions

```bash
sudo -l -U operator
```

### Verify configuration file

```bash
sudo cat /etc/mywebapp/config.yml
```

### Verify systemd units

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