# Restart Recovery — IAOP DEV

**Date:** 2026-11-14  
**Environment:** InstaBox machine `iaop-keycloak-dev`  
**Compose project:** `iaop-dev`  
**Restart policy:** `restart: unless-stopped` on all services

---

## Recovery Architecture

### What persists across restarts

| Data | Storage location | Survives |
|---|---|---|
| PostgreSQL data (all 4 databases) | `/data/iaop-dev/postgres` | Container stop/start, machine restart ✓ |
| Kafka logs (topics, offsets) | `/data/iaop-dev/kafka` | Container stop/start, machine restart ✓ |
| BFF sessions | `bff_db.sessions` table (PostgreSQL) | DB restart — sessions survive as long as DB volume persists ✓ |
| JWKS public keys cache | In-process memory | Reloaded from Keycloak on first request after restart ✗ (acceptable) |
| Outbox lease state | `outbox_events.locked_until` | Leases expire (30s TTL) → events reclaimed by publisher after restart ✓ |

### What does NOT persist

| Data | Reason | Recovery |
|---|---|---|
| In-flight Kafka produce (not yet ACK'd) | Network buffer lost on hard crash | Outbox pattern: event stays in DB; publisher retries |
| Active BFF request context | In-memory state | Client retries the request |
| OIDC PKCE state/nonce | In-flight login only; `__Host-iaop_login_binding` cookie expires in 5min | User re-initiates login |

---

## InstaBox Auto-Suspend Recovery

InstaBox free-tier machines auto-suspend after ~30 minutes of idle. On the Pro plan (`iaop-keycloak-dev`), this is extended but can still occur.

**Resume procedure:**
```bash
instabox resume iaop-keycloak-dev
# Wait ~30–60s for boot
instabox exec iaop-keycloak-dev -- docker ps
# All containers should be Up (restart: unless-stopped fires automatically)
```

**Expected container state after resume:**
```
iaop-keycloak          Up X minutes (healthy)
iaop-keycloak-edge     Up X minutes
iaop-keycloak-db       Up X minutes (healthy)
iaop-dev-db            Up X minutes (healthy)
iaop-dev-kafka         Up X minutes (healthy)
iaop-dev-agent-service Up X minutes
iaop-dev-agency-service Up X minutes
iaop-dev-eligibility-service Up X minutes
iaop-dev-agent-bff     Up X minutes
iaop-dev-api-docs      Up X minutes
```

---

## Controlled Recovery Test Procedure

**Run via `instabox exec iaop-keycloak-dev -- bash`:**

### Step 1: Verify baseline state

```bash
docker compose -p iaop-dev ps
docker exec iaop-dev-db pg_isready -U iaop_admin
docker exec iaop-dev-kafka /opt/kafka/bin/kafka-broker-api-versions.sh \
  --bootstrap-server localhost:9092 >/dev/null && echo "Kafka OK"
```

### Step 2: Stop all IAOP DEV services (not Keycloak)

```bash
cd /data/iaop-dev/compose
docker compose --env-file .env down
# Note: volumes are NOT removed (no --volumes flag)
```

**Expected:** All 7 `iaop-dev-*` containers stop. Keycloak containers unaffected.

### Step 3: Verify data persistence

```bash
ls -la /data/iaop-dev/postgres/
# Should show PostgreSQL cluster files (PG_VERSION, base/, global/, etc.)
ls -la /data/iaop-dev/kafka/
# Should show Kafka log segments
```

### Step 4: Restart

```bash
cd /data/iaop-dev/compose
docker compose --env-file .env up -d
```

**Expected startup sequence (after healthcheck-curl-fix is deployed):**

```
1. db starts, runs pg_isready healthcheck → healthy (~5s)
2. kafka starts, runs broker-api-versions check → healthy (~30s)
3. agent-service, eligibility-service start (wait for db + kafka healthy)
4. agency-service starts (waits for db + kafka + agent-service healthy)
5. agent-bff starts (waits for db + agent-service + agency-service healthy)
6. docs starts immediately (no DB dependency)
```

Total expected startup time: **60–120 seconds** from `up -d` to all services passing healthchecks.

### Step 5: Verify recovery

```bash
# Health endpoints
curl -fsS http://localhost:8082/health/live  # → {"status":"ok"}
curl -fsS http://localhost:8082/health/ready # → {"status":"ready"}
curl -fsS http://localhost:8083/health/live  # → {"status":"ok"}

# Confirm session store recovered (existing sessions remain valid)
curl -fsS http://localhost:8082/api/v1/me \
  --cookie "__Host-iaop_session=<saved-session-value>"
# → 200 (session survives restart as it's in PostgreSQL)

# Confirm outbox publisher resumed
docker logs iaop-dev-agent-service 2>&1 | grep "outbox publisher started"
# → "outbox publisher started with atomic leasing instance_id=agent-pub-..."

# Confirm outbox lease recovery (leases from crashed publisher expired)
docker exec iaop-dev-db psql -U iaop_admin -d agent_db -c \
  "SELECT event_id, event_type, locked_until, publish_attempts
   FROM outbox_events
   WHERE published_at IS NULL AND is_terminal = FALSE
   ORDER BY created_at;"
# → Any events previously locked with expired locked_until will be reclaimed
#    on next outbox poll cycle (~5s after publisher starts)
```

---

## Expected Recovery Behavior

| Component | Expected on restart | Notes |
|---|---|---|
| PostgreSQL | All databases, tables, data intact | Persistent volume mount |
| Kafka | All topics and messages intact | Persistent volume mount |
| Agent Service migrations | Already applied; `sqlx migrate run` is idempotent | No re-run needed |
| BFF sessions | Valid sessions still work immediately | Stored in PostgreSQL |
| JWKS cache | Empty on start; reloads from Keycloak on first JWT validation | First authenticated request pays ~100ms cache miss |
| Outbox publisher | Reclaims expired leases; re-delivers events that were in-flight during crash | At-least-once delivery; consumers deduplicate |
| In-flight Kafka produce at crash | Publisher reclaims and re-delivers | 30s lease expiry → reclaim on next poll |

---

## Runbook: Full Stack Restart After InstaBox Resume

```bash
# 1. Resume machine
instabox resume iaop-keycloak-dev

# 2. Check all containers came up
instabox exec iaop-keycloak-dev -- docker ps --format "{{.Names}}: {{.Status}}"

# 3. If any container failed to start, restart it
instabox exec iaop-keycloak-dev -- \
  sh -c 'cd /data/iaop-dev/compose && docker compose --env-file .env restart <service>'

# 4. Smoke test
curl https://8082-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/health/live
curl https://8083-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/health/live
```

---

## Known Limitation

The initdb script (`01-databases.sh`) runs only on a first-time PostgreSQL initialization (empty data dir). The existing `/data/iaop-dev/postgres` directory is already initialized and contains all databases and roles. Restarts do not trigger re-initialization. This is correct PostgreSQL behavior.
