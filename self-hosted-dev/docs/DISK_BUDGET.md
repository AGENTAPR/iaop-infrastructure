# IAOP Self-Hosted DEV — Disk Budget & Maintenance
## Target Host: 256 GB NVMe SSD Storage Plan

---

## 1. Storage Budget Architecture

With **256 GB total NVMe SSD**, persistent Docker volumes, build caches, and growing container logs must be bounded to avoid system disk full incidents (`ENOSPC`).

```
+-------------------------------------------------------------+
|               256 GB NVMe SSD Physical Layout               |
+-------------------------------------------------------------+
| Host OS (Windows/Linux) & Program Files:           ~70 GB   |
| Developer Tools, Rust toolchain, IDE, Git Repos:  ~40 GB   |
| Docker System Images (PostgreSQL, Kafka, etc.):    ~15 GB   |
| Docker BuildKit Cache (Bounded):                   ~10 GB   |
| Persistent Docker Data Volumes:                    ~50 GB   |
| Automated Local Backups (`./backups`):             ~10 GB   |
| Free Emergency Buffer (Target: >20% Free):        ~61 GB   |
+-------------------------------------------------------------+
```

---

## 2. Persistent Volume Sizing & Retention Policies

| Volume Name | Mount Path | Purpose | Hard Retention / Cap | Enforcement Mechanism |
|---|---|---|---|---|
| `iaop_pg_data` | `/var/lib/postgresql/data` | PostgreSQL DBs (6 databases) | **20 GB** | DEV workload data with autovacuum enabled. |
| `iaop_kafka_data` | `/var/lib/kafka/data` | Kafka topic partitions & logs | **5 GB** | `KAFKA_LOG_RETENTION_HOURS=48`, `KAFKA_LOG_RETENTION_BYTES=5368709120`. |
| `iaop_prom_data` | `/prometheus` | Prometheus time-series database | **15 GB** | `--storage.tsdb.retention.size=15GB`, `--storage.tsdb.retention.time=7d`. |
| `iaop_caddy_data` | `/data` | Caddy TLS certificates & state | **500 MB** | Lightweight TLS storage. |
| `iaop_caddy_config` | `/config` | Caddy autosave configuration | **100 MB** | Ephemeral config history. |

---

## 3. Log Rotation & Disk Protection

Every container in Compose inherits Docker daemon JSON-file logging limits:
- `max-size: 50m`
- `max-file: 3`

To configure host-wide log bounding in `/etc/docker/daemon.json` (Linux) or `%USERPROFILE%\.docker\daemon.json` (Windows):
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
```

---

## 4. Routine Safe Maintenance Runbook

Run `scripts/prune-safe.ps1` (PowerShell) or `scripts/prune-safe.sh` (Bash) weekly:

```powershell
# Windows
.\scripts\prune-safe.ps1
```

```bash
# Linux / macOS
./scripts/prune-safe.sh
```

**Safety Principle:**
- Prunes untagged container images older than 72 hours.
- Prunes BuildKit caches beyond 10 GB.
- **NEVER executes `docker volume prune`:** Data volumes (`iaop_pg_data`, `iaop_kafka_data`) remain intact.
