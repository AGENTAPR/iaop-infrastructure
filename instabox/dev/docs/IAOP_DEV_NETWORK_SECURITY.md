# Network & Security Topology

- Public: 8080 (Keycloak edge), 8082 (BFF), 8083 (docs). Postgres/Kafka bound to compose network only — NOT published.
- BFF enforces: session cookie (Secure/HttpOnly/SameSite), CSRF on mutations (verified: POST /auth/logout without CSRF → 403), verified-JWT permission extraction, audience-scoped access tokens.
- Demo users: read-only `agent:read`, `agent:history:read`; candidate workspace only.
- Observed negatives: unauthenticated /api/v1/me → 401; unauthenticated /api/v1/agency/hierarchy → 401; unknown routes → 404.
- Remaining risks: docs portal is public (specs only, no data); no edge rate limiting; single sandbox = no HA. Acceptable for DEV; must be revisited for production.
