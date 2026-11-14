#!/usr/bin/env bash
# IAOP DEV — Lightweight health monitor
# Run: instabox exec iaop-keycloak-dev -- bash /data/iaop-dev/monitor.sh
set -euo pipefail

echo "=== Container Status ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}" \
  --filter "name=iaop-dev" --filter "name=iaop-keycloak"

echo ""
echo "=== Resource Usage ==="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" \
  iaop-dev-db iaop-dev-kafka iaop-dev-agent-service iaop-dev-agency-service \
  iaop-dev-eligibility-service iaop-dev-agent-bff iaop-dev-api-docs 2>/dev/null || \
  echo "(some containers not running)"

echo ""
echo "=== PostgreSQL Connections ==="
docker exec iaop-dev-db psql -U iaop_admin -d postgres -c \
  "SELECT datname, count(*) as connections FROM pg_stat_activity WHERE datname IS NOT NULL GROUP BY datname ORDER BY count DESC;" \
  2>/dev/null || echo "DB not reachable"

echo ""
echo "=== Outbox Backlog (agent) ==="
docker exec iaop-dev-db psql -U iaop_admin -d agent_db -c \
  "SELECT
     COUNT(*) FILTER (WHERE published_at IS NULL AND is_terminal = FALSE) as pending,
     COUNT(*) FILTER (WHERE published_at IS NOT NULL)                    as published,
     COUNT(*) FILTER (WHERE is_terminal = TRUE)                          as terminal,
     COUNT(*)                                                             as total
   FROM outbox_events;" \
  2>/dev/null || echo "agent_db not reachable"

echo ""
echo "=== Outbox Backlog (agency) ==="
docker exec iaop-dev-db psql -U iaop_admin -d agency_db -c \
  "SELECT
     COUNT(*) FILTER (WHERE published_at IS NULL AND is_terminal = FALSE) as pending,
     COUNT(*) FILTER (WHERE published_at IS NOT NULL)                    as published,
     COUNT(*) FILTER (WHERE is_terminal = TRUE)                          as terminal,
     COUNT(*)                                                             as total
   FROM outbox_events;" \
  2>/dev/null || echo "agency_db not reachable"

echo ""
echo "=== Kafka Topics ==="
docker exec iaop-dev-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 --list 2>/dev/null || echo "Kafka not reachable"

echo ""
echo "=== Kafka Consumer Groups ==="
docker exec iaop-dev-kafka /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --list 2>/dev/null || echo "(no groups or Kafka not reachable)"

echo ""
echo "=== Service Health Checks ==="
for svc in iaop-dev-agent-service iaop-dev-agency-service iaop-dev-eligibility-service iaop-dev-agent-bff iaop-dev-api-docs; do
  STATUS=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$svc" 2>/dev/null || echo "not-found")
  echo "  $svc: $STATUS"
done

echo ""
echo "=== Recent Service Logs (last 20 lines each) ==="
for svc in iaop-dev-agent-service iaop-dev-agency-service iaop-dev-eligibility-service iaop-dev-agent-bff; do
  echo "--- $svc ---"
  docker logs --tail 20 "$svc" 2>&1 | tail -20
  echo ""
done

echo "=== Monitor complete: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
