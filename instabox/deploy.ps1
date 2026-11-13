# Idempotent deploy of the IAOP Keycloak bundle to iaop-keycloak-dev.
param([switch]$DryRun)
$ErrorActionPreference = 'Stop'
$IB = "$env:LOCALAPPDATA\Programs\instabox\instabox.exe"
$BASE = "/data/iaop-keycloak"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
function Push($local, $remote) {
  if ($DryRun) { Write-Host "DRY: push $local -> $remote"; return }
  Get-Content $local -Raw | & $IB exec iaop-keycloak-dev --stdin -- bash -c "cat > $remote && sed -i 's/\r$//' $remote"
}
& $IB exec iaop-keycloak-dev -- bash -c "mkdir -p $BASE/compose/nginx $BASE/config $BASE/backups $BASE/reports"
Push "$root\docker-compose.yml" "$BASE/compose/docker-compose.yml"
Push "$root\nginx\default.conf"        "$BASE/compose/nginx/default.conf"
Push "$root\keycloak\realm-iaop-dev.json" "$BASE/config/realm-iaop-dev.json"
Push "$root\setup.sh"                 "$BASE/setup.sh"
& $IB exec iaop-keycloak-dev -- bash -c "chmod +x $BASE/setup.sh"
if (-not $DryRun) {
  $pub = (& $IB port publish iaop-keycloak-dev 8080 --json | ConvertFrom-Json).url
  Write-Host "public URL: $pub"
  & $IB exec iaop-keycloak-dev --env "KC_PUBLIC_URL=$pub" --timeout 600 -- bash "$BASE/setup.sh"
}
