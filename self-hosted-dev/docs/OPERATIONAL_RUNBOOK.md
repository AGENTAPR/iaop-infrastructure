# IAOP Self-Hosted DEV — Operational Runbook
## Daily Operations, Profiling, Backup/Recovery, and Troubleshooting

---

## 1. Quick Start

### 1.1 First-Time Initialization
Run the bootstrap script from `self-hosted-dev/`:

```powershell
# Windows PowerShell
.\scripts\bootstrap.ps1
```

```bash
# Linux / macOS Bash
chmod +x ./scripts/*.sh
./scripts/bootstrap.sh
```

This will:
1. Verify Docker and Docker Compose prerequisites.
2. Initialize `.env` from `.env.example`.
3. Create the `iaop-internal` Docker bridge network.
4. Launch the `foundation` profile (`iaop-postgres`, `iaop-keycloak`, `iaop-kafka`, `iaop-caddy`, `iaop-developer-portal`).
5. Wait for PostgreSQL health checks to turn healthy.

### 1.2 Accessing Local Endpoints
- **Centralized Swagger UI:** [http://localhost/docs/](http://localhost/docs/)
- **Swagger UI Configuration:** [http://localhost/api/docs/swagger-config.json](http://localhost/api/docs/swagger-config.json)
- **Keycloak Admin Console:** [http://localhost/auth/](http://localhost/auth/) (`admin` / `admin_dev_secret_change_me`)
- **Prometheus Metrics:** [http://localhost:9090](http://localhost:9090)
- **PostgreSQL Database:** `localhost:5432` (`postgres` / `postgres_dev_secret_change_me`)
- **Kafka Broker:** `localhost:9092`

---

## 2. Profile Management

Run specific sets of services based on your task to conserve RAM on the 16 GB host:

```bash
# Foundation only (DB, Kafka, Auth, Swagger Portal, Caddy) (~4.2 GB RAM)
docker compose --profile foundation up -d

# Foundation + Agent & Agency domain services (~6.0 GB RAM)
docker compose --profile foundation --profile agent --profile agency up -d

# Foundation + Integration Service (~4.8 GB RAM)
docker compose --profile foundation --profile integration up -d

# Full ecosystem (All microservices + Flowable + Observability) (~8.9 GB RAM)
docker compose --profile all up -d

# Stop all services gracefully
docker compose --profile all down
```

---

## 3. Database Backup and Recovery

### 3.1 Taking a Backup
```powershell
# PowerShell
.\scripts\backup.ps1
```
```bash
# Bash
./scripts/backup.sh
```
Dumps are created in `./backups/` with timestamping and retention pruning (keeps last 7 days).

### 3.2 Restoring from Backup
```powershell
# PowerShell
.\scripts\restore.ps1 -Database iaop_agent -BackupFile ./backups/iaop_agent_20261114_120000.sql
```
```bash
# Bash
./scripts/restore.sh iaop_agent ./backups/iaop_agent_20261114_120000.sql.gz
```
The script guards against accidental overwrites by prompting for explicit confirmation (`RESTORE`) and automatically disconnects active client pools before loading data.

---

## 4. Troubleshooting & Diagnostics

### 4.1 Checking Service Health
```bash
docker compose ps
```

### 4.2 Viewing Live Logs
```bash
# Follow Caddy reverse proxy logs
docker logs -f iaop-caddy

# Follow Integration Service logs
docker logs -f iaop-integration-service

# Follow Keycloak logs
docker logs -f iaop-keycloak
```

### 4.3 Container Memory Inspection
Check real-time memory usage against limits:
```bash
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}"
```

### 4.4 PostgreSQL Database Inspection
```bash
docker exec -it iaop-postgres psql -U postgres -d postgres -c "\l"
```
