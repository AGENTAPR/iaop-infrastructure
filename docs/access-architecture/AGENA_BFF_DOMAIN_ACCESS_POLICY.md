# BFF → Domain Access Policy

## Agent BFF (`iaop-agent-bff`)

- Session: OIDC Authorization Code + PKCE (S256), state/nonce/browser-binding,
  single-use login transactions, HttpOnly `__Host-iaop_session`, CSRF header.
- Tokens: access/refresh server-side only; never in browser storage.
- Downstream calls carry the **end-user access token** to domain services.
- Audiences: `iaop-agent-api` (agent-service), `iaop-agency-api`
  (agency-service), `iaop-eligibility-api` (eligibility-service) via the
  `aud-*` optional client scopes on `iaop-agent-bff`.
- Domain services re-validate JWT signature/issuer/audience/expiry and enforce
  resource-level authorization. BFF network position grants nothing.

## Operations BFF (`iaop-operations-bff`)

- Scaffold only — NOT deployed, NOT exposed. No public route exists.
- Intended: staff authorization (not agent sessions), separate session cookie,
  own OIDC client. Do not reuse Agent BFF sessions for office users.

## Customer BFF

- Does not exist. No route configured. No placeholder.

## Caller allowlist (domain plane)

| Domain service | Authorized callers |
|---|---|
| agent-service | agent-bff, agency-service (identity validation), workers |
| agency-service | agent-bff, operations-bff (future), workers |
| eligibility-service | agent-bff, domain services per policy |

Workload auth where implemented: Keycloak client-credentials service accounts
(e.g., `iaop-agency-service` → agent-service with `agent:read` only).
