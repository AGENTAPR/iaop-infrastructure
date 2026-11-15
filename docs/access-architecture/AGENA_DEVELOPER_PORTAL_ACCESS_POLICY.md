# Developer Portal Access Policy (DEV plane)

The Developer Portal (`iaop/api-docs`, container `iaop-dev-api-docs`) is an
engineering tool on a **separate access plane** — not application ingress.

## Planes

```
Application plane:  Browser -> Caddy/instabox edge -> BFF -> domain services
Developer plane:    Developer -> Developer Portal -> controlled /dev-api proxy
                        -> allowlisted domain services (DEV only)
```

## Controls (implemented in `iaop-api-contracts/portal`)

- Portal session: `agena_session_id` HttpOnly cookie, OIDC auth-code+PKCE via
  `iaop-developer-portal` client.
- `/dev-api/*` proxy requires: authenticated portal session **and**
  `portal-api-tester` realm role.
- Exact upstream allowlist (`UPSTREAM_AGENT_BFF`, `UPSTREAM_AGENT_SERVICE`,
  `UPSTREAM_AGENCY_SERVICE`, `UPSTREAM_ELIGIBILITY_SERVICE`) — no arbitrary
  upstream URL (no SSRF), fixed route prefixes only.
- `portal_*` cookies stripped before upstream; backend OAuth/PKCE used for
  domain calls — the portal session is never forwarded as a domain credential.
- Same-origin/CSRF validation on logout; Keycloak end-session on sign-out.

## Rules

- DEV-only: production must not carry this exception; default-disable mutation
  testing outside approved non-prod.
- The portal never bypasses domain authorization: every proxied call still
  requires a valid audience-scoped JWT and passes domain authz.
- Portal identity ≠ agent identity. `portal-api-tester` grants API *testing*
  permission only.
