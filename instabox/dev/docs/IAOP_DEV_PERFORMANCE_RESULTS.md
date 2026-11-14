# Performance Results — DEV smoke (2026-11-14)

Environment: iaop-keycloak-dev (4 vCPU/8 GiB), Instabox edge proxy → public HTTPS.
Note: ~920ms baseline includes edge-proxy TLS+network hop; app-internal latency is lower.

| Endpoint | n | concurrency | p50 | p95 | p99 | errors |
|---|---|---|---|---|---|---|
| /health/live | 60 | 15 | 917ms | 959ms | 1954ms | 0 (all 200) |
| /api/v1/me (unauth) | 30 | 15 | 921ms | 965ms | 969ms | 0 (all 401 — correct) |

Observations: stable under 15-way concurrency; max outlier 16s on cold first-hit (TLS/session setup). No OOM, no restarts, all containers healthy post-load.
Not measured: authenticated aggregation latency under load, Kafka producer latency, k6 profiles — documented as remaining work; do NOT extrapolate to production.
