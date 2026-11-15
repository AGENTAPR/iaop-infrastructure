# Averuna Keycloak login theme

Custom Keycloak login theme (`averuna`) that mirrors the authentication page
design of `AGENTAPR/averuna-partner-web` (`main`): centered card over the
`bg-light` backdrop, aubergine primary buttons, Urbanist/Mulish typography,
Averuna logo.

## Structure

- `login/theme.properties` — `parent=keycloak`.
- `login/template.ftl` — copy of the stock layout with two changes: the
  realm-title header is emptied and the Averuna logo `<img>` is injected as
  the first child of the card. All other pages (OTP, reset, error, logout)
  inherit it, so they get the same branded shell.
- `login/login.ftl` — partner-web sign-in markup (subtitle, labeled fields,
  eye toggle, Reset Password link, Continue button) while preserving every
  Keycloak mechanism: form action, `username`/`password`/`credentialId`
  fields, `data-password-toggle` JS hooks, passkeys, social providers.
- `login/messages/messages_en.properties` — copy overrides
  (`Sign in`, `Continue`, `Reset Password`, subtitle).
- `login/resources/css/login.css` — pixel-matched partner styling
  (512px card, 32px radius, grey-200 outlined inputs, aubergine button).
- `login/resources/css/login.css` — reskins the PatternFly DOM
  (`#kc-*`, `.login-pf-*`, `.card-pf`, `.form-control`, `.btn-primary`)
  to the Averuna look.
- `login/resources/img/logo.svg` — Averuna logo extracted from
  `averuna-partner-web/src/components/logo/logo.tsx`.
- `login/resources/img/bg.jpg` — `averuna-partner-web/public/images/misc/bg-light.jpg`.

## Deployment (InstaBox DEV, `iaop-keycloak-dev`)

1. Copy the theme to the box:

   ```bash
   # on the box
   mkdir -p /data/iaop-keycloak/themes
   # copy instabox/dev/keycloak/themes/averuna -> /data/iaop-keycloak/themes/averuna
   ```

2. Mount it in `/data/iaop-keycloak/compose/docker-compose.yml` under the
   `keycloak` service:

   ```yaml
   volumes:
     - /data/iaop-keycloak/themes:/opt/keycloak/themes:ro
   ```

3. Recreate Keycloak and wait for healthy:

   ```bash
   cd /data/iaop-keycloak/compose && docker compose up -d --force-recreate keycloak
   ```

4. Select the theme on the realm (admin API or admin console):

   ```
   PUT /admin/realms/iaop-dev  { "loginTheme": "averuna" }
   ```

Theme resources are served publicly at
`/resources/<version>/login/averuna/...`; the login page HTML references
`averuna/css/login.css`.

## Notes

- Authentication behavior is unchanged: same OIDC flows, PKCE, session
  cookies, CSRF, and authorization. Only presentation is themed.
- If the box root filesystem (`/`) is full, Keycloak's first boot after a
  config change fails while rebuilding its optimized image — free space or
  `instabox resize` before recreating.
