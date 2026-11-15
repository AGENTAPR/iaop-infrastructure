# IAOP DEV Resource Requirements (measured)

## Deployed stack (all-in-one on iaop-keycloak-dev)
| Component | Memory limit | Notes |
|---|---|---|
| PostgreSQL 16 | 1 GiB | 4 service DBs, separate roles |
| Kafka (KRaft) | 1.5 GiB | single broker, dev retention |
| agent-service | 512 MiB | migrations + outbox publisher OK |
| agency-service | 512 MiB | migrations + outbox publisher OK |
| eligibility-service | 384 MiB | migrations OK |
| agent-bff | 512 MiB | PG session store, token encryption ON |
| api-docs (Swagger portal) | 128 MiB | serves real OpenAPI specs |
| Keycloak stack | ~1.5 GiB | pre-existing |

Total app limits ≈ 4.5 GiB + Keycloak ≈ fits 8 GiB with headroom. All containers Up simultaneously; no OOM; no restarts after DB credential fix.

## Not deployed (documented gaps)
workflow-service, notification-service, document-service, recruitment/onboarding/learning/certification/sales — no verified runtime need for current Agent journeys yet; BFF returns honest 503 UNAVAILABLE where unconfigured.
