# Observability Report — IAOP DEV

**Date:** 2026-11-14  
**Environment:** InstaBox machine `iaop-keycloak-dev` (4 vCPU / 8 GiB)

---

## Approach

Full Prometheus + Grafana + Loki is not deployed. The machine has ~6 GiB in use with the existing Keycloak stack plus the IAOP services. The combined Prometheus/Grafana/Loki stack requires ~1–2 GiB additional and would push the machine to its memory limit.

The observability strategy for DEV is:

1. **Structured logging** — already in place via `tracing` crate with JSON/text output at `RUST_LOG=info`
2. **Lightweight health/metrics monitor script** — `monitor.sh` runs all relevant checks in one command
3. **On-demand log tailing** via `docker logs`
4. **On-demand DB queries** via `docker exec psql`

---

## Structured Logging

All Rust services use the `tracing` crate with the `tracing-subscriber` fmt layer. Log output goes to stdout and is captured by Docker.

**Key log fields emitted:**
- `request_id` — per-request UUID (also returned in response `meta.requestId`)
- `correlation_id` — propagated across service calls
- `event_id` — outbox event ID on delivery/retry
- `instance_id` — outbox publisher instance (format: `agent-pub-<uuid>`)

**How to tail logs:**

```bash
# Live tail — BFF
instabox exec iaop-keycloak-dev -- docker logs -f iaop-dev-agent-bff

# Last 100 lines — agent-service
instabox exec iaop-keycloak-dev -- docker logs --tail 100 iaop-dev-agent-service

# Filter for errors only (approximate — structured logs need jq for JSON)
instabox exec iaop-keycloak-dev -- docker logs --tail 500 iaop-dev-agent-bff 2>&1 | grep -i "error\|WARN\|panic"

# Outbox publisher activity
instabox exec iaop-keycloak-dev -- docker logs iaop-dev-agent-service 2>&1 | grep "outbox"
```

**Log format example:**
```
2026-11-14T17:45:12.034Z  INFO iaop_agent_bff::middleware: request id=01a1db2f... method=GET path=/api/v1/me status=200 latency_ms=2
2026-11-14T17:45:12.035Z  INFO iaop_agent_service_infrastructure::outbox: outbox publisher started with atomic leasing instance_id=agent-pub-01a1...
```

---

## Monitor Script

The `monitor.sh` script at `instabox/dev/monitor.sh` provides a one-command system snapshot.

**Run:**
```bash
instabox exec iaop-keycloak-dev -- bash /data/iaop-dev/monitor.sh
```

**What it shows:**
1. All container status (names, uptime, state)
2. CPU % and memory usage per container
3. PostgreSQL connection counts per database
4. Outbox backlog: pending / published / terminal counts for `agent_db` and `agency_db`
5. Kafka topic list
6. Kafka consumer groups
7. Docker healthcheck status per service
8. Last 20 log lines from each service container

**Copy the script to the box after deployment:**
```bash
instabox exec iaop-keycloak-dev -- \
  sh -c 'cp /data/iaop-dev/compose/../monitor.sh /data/iaop-dev/monitor.sh && chmod +x /data/iaop-dev/monitor.sh'
```

---

## Ad-hoc Queries

### PostgreSQL — active connections
```bash
instabox exec iaop-keycloak-dev -- docker exec iaop-dev-db \
  psql -U iaop_admin -d postgres -c \
  "SELECT datname, usename, state, count(*) FROM pg_stat_activity GROUP BY 1,2,3 ORDER BY 4 DESC;"
```

### Outbox backlog (agent)
```bash
instabox exec iaop-keycloak-dev -- docker exec iaop-dev-db \
  psql -U iaop_admin -d agent_db -c \
  "SELECT event_type, COUNT(*) FILTER (WHERE published_at IS NULL AND is_terminal=FALSE) as pending,
          COUNT(*) FILTER (WHERE published_at IS NOT NULL) as published
   FROM outbox_events GROUP BY event_type;"
```

### Kafka consumer lag
```bash
instabox exec iaop-keycloak-dev -- docker exec iaop-dev-kafka \
  /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --describe --all-groups
```

### Container memory detail
```bash
instabox exec iaop-keycloak-dev -- \
  docker stats --no-stream iaop-dev-agent-bff iaop-dev-agent-service iaop-dev-agency-service iaop-dev-eligibility-service iaop-dev-db iaop-dev-kafka
```

---

## Resource Budget

| Container | Memory limit | Expected usage |
|---|---|---|
| iaop-dev-db (PostgreSQL) | 512M | ~100–200MB DEV |
| iaop-dev-kafka | 1024M | ~600–800MB (JVM heap 768MB) |
| iaop-dev-agent-service | 512M | ~30–80MB (Rust, no GC) |
| iaop-dev-agency-service | 512M | ~30–80MB |
| iaop-dev-eligibility-service | 384M | ~20–40MB |
| iaop-dev-agent-bff | 512M | ~40–100MB |
| iaop-dev-api-docs | 256M | ~20–40MB |
| **Total** | **3.7 GiB limits** | **~1–1.5 GiB actual** |

Actual memory is well within the 6 GiB available after Keycloak stack (~2 GiB).

---

## Future Observability (when capacity allows)

When a larger machine is available:
- **Prometheus** with `/metrics` endpoint from each Rust service (add `axum-prometheus` or `metrics-exporter-prometheus` crate)
- **Loki** for log aggregation with `docker logs` driver
- **Grafana** dashboards for outbox lag, request latency per endpoint, Kafka consumer lag

For now, the monitor script + structured logging + on-demand queries provide adequate DEV observability.
