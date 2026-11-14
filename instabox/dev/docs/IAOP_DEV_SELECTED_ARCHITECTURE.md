# Selected Architecture — IAOP DEV

```
Browser ──HTTPS──> Instabox edge proxy
  :8080 Keycloak (existing, preserved)
  :8082 agent-bff ──> agent-service / agency-service / eligibility-service (private net)
  :8083 api-docs (Swagger portal, real specs)
Internal: postgres:16 (4 DBs, per-service roles), kafka KRaft (outbox topics)
```

- All domain services private (no published ports); only BFF + docs + Keycloak public.
- Secrets in `/data/iaop-dev/compose/.env` on sandbox — NOT in git.
- Session tokens encrypted at rest (`SESSIONS_ENCRYPTION_KEY` mandatory with `DATABASE_URL`).
- Auth: real OIDC auth-code+PKCE; no `AUTH_MODE=dev` bypass.
