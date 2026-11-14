# Container Health Report — IAOP DEV

**Date:** 2026-11-14  
**Branch:** `feature/instabox-dev-deployment` (iaop-infrastructure)  
**Environment:** InstaBox machine `iaop-keycloak-dev`

---

## Problem (Pre-fix)

All 5 service containers had `healthcheck: disable: true` in `docker-compose.yml`. The comment noted that `wget` was absent in `debian:bookworm-slim`. However, all 4 Rust service Dockerfiles already specified:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
    CMD ["sh", "-c", "wget -qO- http://127.0.0.1:${PORT:-8080}/health/live >/dev/null 2>&1 || exit 1"]
```

`wget` is not installed in the base `debian:bookworm-slim` image, so the healthcheck would fail even if re-enabled. This caused two problems:

1. `depends_on: condition: service_healthy` could never be satisfied — Compose fell back to `service_started`.
2. Docker had no visibility into service health; `docker ps` would show `Up` for containers that were failing to start.

The docs portal Dockerfile (in `iaop-api-contracts`) correctly installs `curl` and uses it in its own `HEALTHCHECK`, but its healthcheck was also disabled in Compose.

---

## Fix Applied

### Dockerfile changes (feature/healthcheck-curl-fix on each service repo)

Replaced `wget` with `curl` and added `ca-certificates curl` to the runtime stage of all 4 Rust service Dockerfiles:

**Pattern applied to:** `iaop-agent-bff`, `iaop-agent-service`, `iaop-agency-service`, `iaop-eligibility-service`

```dockerfile
FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
RUN useradd --system --uid 10001 --create-home appuser
# ... binary copy, USER, EXPOSE ...
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8080/health/live > /dev/null || exit 1
```

### docker-compose.yml changes

Removed all `healthcheck: disable: true` entries and replaced with explicit Compose-level healthcheck blocks. Upgraded dependency conditions from `service_started` to `service_healthy` where appropriate:

| Service | Healthcheck endpoint | start_period | depends_on change |
|---|---|---|---|
| agent-service | `/health/live` | 20s | — (db + kafka were already `service_healthy`) |
| agency-service | `/health/live` | 20s | `agent-service`: `service_started` → `service_healthy` |
| eligibility-service | `/health/live` | 20s | — |
| agent-bff | `/health/ready` | 25s | `agent-service` + `agency-service`: now `service_healthy` |
| docs | `/health/live` | 10s | — |

The BFF uses `/health/ready` (not `/health/live`) because readiness checks whether its PostgreSQL connection is working — a critical runtime dependency.

---

## Verification

### Live health probes (from outside the InstaBox, via public edge)

```
GET https://8082-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/health/live
→ 200 {"status":"ok"}

GET https://8082-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/health/ready
→ 200 {"status":"ready"}

GET https://8083-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/health/live
→ 200 {"status":"ok"}
```

Both verified live on 2026-11-14T17:xx:xxZ.

### Internal healthcheck (requires InstaBox shell)

After rebuilding and redeploying with the new Dockerfiles:

```bash
instabox exec iaop-keycloak-dev -- docker inspect iaop-dev-agent-bff \
  --format='{{.State.Health.Status}}'
# Expected: healthy
```

**Current status on live machine:** Healthchecks are disabled in the currently deployed images because the fix requires a Docker image rebuild. The runbook command to apply after pushing:

```bash
instabox exec iaop-keycloak-dev -- \
  sh -c 'cd /data/iaop-dev/compose && docker compose --env-file .env build --no-cache && docker compose --env-file .env up -d'
```

---

## Dependency Chain (After Fix)

```
postgres (healthy) ──┬──> agent-service (healthy) ──┬──> agency-service (healthy) ──┐
                     │                               └──> agent-bff (healthy)         │
kafka (healthy) ─────┘                                                                │
                                                       agent-bff also depends on ─────┘
eligibility-service: postgres only
docs: standalone
```

---

## Files Changed

| Repository | Branch | File |
|---|---|---|
| `iaop-agent-bff` | `feature/healthcheck-curl-fix` | `Dockerfile` |
| `iaop-agent-service` | `feature/healthcheck-curl-fix` | `Dockerfile` |
| `iaop-agency-service` | `feature/healthcheck-curl-fix` | `Dockerfile` |
| `iaop-eligibility-service` | `feature/healthcheck-curl-fix` | `Dockerfile` |
| `iaop-infrastructure` | `feature/instabox-dev-deployment` | `instabox/dev/compose/docker-compose.yml` |
