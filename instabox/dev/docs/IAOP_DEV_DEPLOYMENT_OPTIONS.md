# Deployment Options Evaluated

## Option A — All-in-one InstaBox: SELECTED
Keycloak + Postgres + Kafka + 4 Rust services + Swagger on `iaop-keycloak-dev`.
- Fits measured 8 GiB; zero incremental cost; single compose lifecycle; data persists on `/data`.
- Risk: auto-pause cold starts; single point of failure — acceptable for DEV.

## Option B — InstaBox + external managed Postgres/Kafka
Rejected for now: adds cost/latency; no measured capacity need. Kafka required for outbox verification — self-hosted KRaft suffices at DEV scale.

## Option C — Hybrid split
Rejected: no second machine needed; adds ops complexity without benefit at this scale.

## Verdict
INSTABOX SUFFICIENT WITH EXISTING KEYCLOAK for current Agent-ecosystem DEV scope.
