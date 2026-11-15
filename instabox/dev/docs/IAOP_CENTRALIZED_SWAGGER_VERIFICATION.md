# Centralized Swagger Verification — VERIFIED

- URL: `https://8083-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/swagger-ui/` → 200
- Catalog API `/api/v1/catalog` returns 20 real service entries sourced from `specs/development/*/openapi.json` in iaop-api-contracts (sourceCommit recorded per spec).
- Spot check: `GET /specs/development/agent-service/openapi.json` → 200, valid OpenAPI 3.1.0 ("IAOP Agent Registry & Identity Service").
- Only implemented/verified specs enabled; proposed specs marked accordingly — no fabricated endpoints.
- "Try it out" requires a Keycloak bearer token; domain services themselves remain private.
