# Kafka Outbox E2E — IAOP DEV

**Date:** 2026-11-14  
**Environment:** `iaop-keycloak-dev` (InstaBox)  
**Current state:** Kafka broker healthy, outbox publisher running, zero events emitted (no domain write command executed yet)

---

## Infrastructure Status

| Component | Status | Evidence |
|---|---|---|
| Kafka broker (`iaop-dev-kafka`) | Running (port 9092 internal) | Confirmed in IAOP_DEV_REAL_E2E_RESULTS.md |
| PostgreSQL outbox table (agent_db) | Created, empty | Migrations applied on deploy |
| PostgreSQL outbox table (agency_db) | Created, empty | Migrations applied on deploy |
| Outbox publisher (agent-service) | Running | Log: "outbox publisher started with atomic leasing" |
| Outbox publisher (agency-service) | Running | Log: "outbox publisher started with atomic leasing" |
| Kafka events emitted | **0** | No domain write command has been executed |

---

## Why No Events Have Been Emitted

The transactional outbox pattern requires a domain command that writes to both the domain table and `outbox_events` in the same database transaction. The only write operations executed so far have been:

- Keycloak authentication (Keycloak's own DB)
- BFF session creation (bff_db)
- BFF session reads (`GET /api/v1/me`, `/api/v1/me/today`)

None of these touch the agent or agency domain tables. The first event will be emitted when a command such as `POST /api/v1/agents` or `POST /api/v1/agents/{id}/submit-for-activation` is executed.

---

## Outbox Architecture

```
Domain command (e.g., CreateAgent)
  │
  └─► Transaction {
        INSERT INTO agents (...)                    ← domain record
        INSERT INTO outbox_events (payload, ...)    ← event record (same tx)
      }
  
Outbox Publisher (background task, 5s poll):
  ├─ claim_batch(): UPDATE outbox_events SET locked_until=..., locked_by=<instance-id>
  │                 WHERE published_at IS NULL AND locked_until < now()
  │                 FOR UPDATE SKIP LOCKED
  │
  ├─ transport.deliver(&event) → Kafka produce to iaop.agent.events (or iaop.agency.events)
  │
  └─ mark_published(): UPDATE outbox_events SET published_at=now()
                        WHERE event_id=$1 AND locked_by=$2  ← fenced
```

Delivery is at-least-once. Consumers must deduplicate on `event_id`.

---

## Verification Commands (run on InstaBox machine)

### 1. Check Kafka topics

```bash
instabox exec iaop-keycloak-dev -- \
  docker exec iaop-dev-kafka \
    /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
# Expected after first agent write: iaop.agent.events, iaop.agency.events
# Current: likely empty (auto-create on first produce)
```

### 2. Check outbox table current state

```bash
instabox exec iaop-keycloak-dev -- \
  docker exec iaop-dev-db \
    psql -U iaop_admin -d agent_db -c \
    "SELECT event_id, event_type, published_at, is_terminal, publish_attempts
     FROM outbox_events
     ORDER BY created_at DESC
     LIMIT 10;"
# Expected now: (0 rows)
```

```bash
instabox exec iaop-keycloak-dev -- \
  docker exec iaop-dev-db \
    psql -U iaop_admin -d agency_db -c \
    "SELECT event_id, event_type, published_at, is_terminal
     FROM outbox_events
     ORDER BY created_at DESC
     LIMIT 10;"
# Expected now: (0 rows)
```

### 3. Execute a write command to generate the first event

```bash
# Get a token for e2e-agent-admin (direct grant, DEV only)
TOKEN=$(instabox exec iaop-keycloak-dev -- \
  docker exec iaop-dev-agent-bff \
    curl -s -X POST \
    "http://iaop-keycloak:8080/realms/iaop-dev/protocol/openid-connect/token" \
    -d "grant_type=password&client_id=iaop-agent-bff&username=e2e-agent-admin&password=<PASSWORD>&scope=openid" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# Create an agent (triggers AgentCreated event)
instabox exec iaop-keycloak-dev -- \
  docker exec iaop-dev-agent-bff \
    curl -s -X POST http://agent-service:8080/api/v1/agents \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "fullName": "E2E Test Agent",
      "idNumber": "9988776655443322",
      "phoneNumber": "+6281234567890"
    }'
```

### 4. Verify event appears in outbox_events

```bash
instabox exec iaop-keycloak-dev -- \
  docker exec iaop-dev-db \
    psql -U iaop_admin -d agent_db -c \
    "SELECT event_id, event_type, aggregate_id, published_at, publish_attempts
     FROM outbox_events
     ORDER BY created_at DESC
     LIMIT 5;"
# Expected: 1 row, event_type='AgentCreated', published_at=NULL initially
# After outbox publisher runs (~5s poll): published_at=<timestamp>
```

### 5. Verify event delivered to Kafka

```bash
instabox exec iaop-keycloak-dev -- \
  docker exec iaop-dev-kafka \
    /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 \
    --topic iaop.agent.events \
    --from-beginning \
    --max-messages 5
```

### 6. Submit for activation (triggers AgentSubmittedForActivation event)

```bash
# Replace <agent-uuid> with the ID from the create response
instabox exec iaop-keycloak-dev -- \
  docker exec iaop-dev-agent-bff \
    curl -s -X POST \
    http://agent-service:8080/api/v1/agents/<agent-uuid>/submit-for-activation \
    -H "Authorization: Bearer $TOKEN"
```

---

## Expected Event Schema

When `POST /api/v1/agents` succeeds, the agent service writes to `outbox_events`:

```json
{
  "event_id":          "<uuid-v7>",
  "aggregate_id":      "<agent-uuid>",
  "aggregate_type":    "Agent",
  "aggregate_version": 1,
  "event_type":        "AgentCreated",
  "event_version":     1,
  "source":            "iaop-agent-service",
  "payload": {
    "agent_id":        "<agent-uuid>",
    "agent_code":      "AGT-XXXXX",
    "full_name":       "E2E Test Agent",
    "created_at":      "<iso8601>"
  },
  "occurred_at":       "<iso8601>",
  "correlation_id":    "<uuid>",
  "causation_id":      "<uuid>"
}
```

Kafka message: topic=`iaop.agent.events`, key=`<agent-uuid>`, value=JSON envelope above.

---

## Outbox Publisher Behavior

The publisher (`iaop-agent-service/crates/infrastructure/src/outbox.rs`) implements:

- **Atomic lease claiming** — `UPDATE ... WHERE FOR UPDATE SKIP LOCKED` prevents duplicate delivery across multiple publisher instances
- **Lease fencing** — `mark_published` only commits if `locked_by` still matches the claiming instance
- **Exponential backoff with jitter** — retries at 2^attempt seconds (capped 300s) + ≤1s jitter
- **Terminal poison events** — after `max_attempts`, sets `is_terminal = TRUE` and stops retrying (requires operator replay)
- **Restart safety** — publisher resumes from last committed `published_at`; in-flight events whose lease has expired are reclaimed

---

## Verdict

| Check | Status |
|---|---|
| Kafka broker healthy | PASS (confirmed running) |
| Outbox tables created by migrations | PASS |
| Outbox publisher started | PASS (log confirmed) |
| First domain event emitted | BLOCKED — requires InstaBox exec + e2e-agent-admin credentials |
| Kafka consumer validation | BLOCKED — requires InstaBox exec |

The infrastructure is ready to emit events the moment a domain write command executes. All runbook commands are documented above.
