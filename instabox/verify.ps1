# Post-deploy verification: health, discovery, exposure controls, token smoke.
$ErrorActionPreference = 'Continue'
$IB = "$env:LOCALAPPDATA\Programs\instabox\instabox.exe"
$B = 'https://8080-agq5lpbszgbva3ygddcbarv6ea.instabox.tech'
$realm = "$B/realms/iaop-dev"
"== container health =="
& $IB exec iaop-keycloak-dev -- docker ps --format '{{.Names}} {{.Status}}'
"== OIDC discovery =="
try { (Invoke-RestMethod "$realm/.well-known/openid-configuration").issuer } catch { "FAIL: $_" }
"== admin console (expect 404) =="; try { (Invoke-WebRequest "$B/admin/" -SkipHttpErrorCheck).StatusCode } catch { $_.Exception.Response.StatusCode.value__ }
"== master realm (expect 404) =="; try { (Invoke-WebRequest "$B/realms/master/.well-known/openid-configuration" -SkipHttpErrorCheck).StatusCode } catch { $_.Exception.Response.StatusCode.value__ }
"== postgres port (expect refused) =="; Test-NetConnection 127.0.0.1 -Port 5432 -InformationLevel Quiet
