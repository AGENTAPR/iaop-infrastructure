# ==============================================================================
# IAOP Self-Hosted DEV — Bootstrap Script (PowerShell)
# Initializes environment, networks, and foundation services
# ==============================================================================

[CmdletBinding()]
param (
    [string]$Profile = "foundation"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptDir

Push-Location $RootDir
try {
    Write-Host "=== IAOP Self-Hosted DEV Bootstrap ===" -ForegroundColor Cyan

    # 1. Check prerequisites
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "Docker is required but not installed or not in PATH."
    }

    # 2. Setup .env
    if (-not (Test-Path "$RootDir\.env")) {
        Write-Host "Creating .env from .env.example..." -ForegroundColor Yellow
        Copy-Item "$RootDir\.env.example" "$RootDir\.env"
    }

    # 3. Create network if needed
    $networkExists = docker network ls --filter name=iaop-internal -q
    if (-not $networkExists) {
        Write-Host "Creating docker bridge network: iaop-internal..." -ForegroundColor Green
        docker network create iaop-internal | Out-Null
    }

    # 4. Start Compose profile
    Write-Host "Starting Docker Compose profile: $Profile..." -ForegroundColor Green
    docker compose --profile $Profile up -d

    Write-Host "`nWaiting for foundation services to pass health checks..." -ForegroundColor Yellow
    $timeout = 60
    $elapsed = 0
    while ($elapsed -lt $timeout) {
        $pgHealthy = (docker inspect --format='{{.State.Health.Status}}' iaop-postgres 2>$null) -eq "healthy"
        if ($pgHealthy) {
            Write-Host "PostgreSQL is healthy!" -ForegroundColor Green
            break
        }
        Start-Sleep -Seconds 3
        $elapsed += 3
        Write-Host "Waiting for PostgreSQL ($elapsed s)..."
    }

    Write-Host "`n=== IAOP Environment Ready ===" -ForegroundColor Cyan
    Write-Host "Centralized Swagger Portal: http://localhost/docs/"
    Write-Host "Keycloak Identity Console:  http://localhost/auth/ (admin/admin_dev_secret_change_me)"
    Write-Host "Reverse Proxy Ingress:      http://localhost/"
    Write-Host "PostgreSQL Database:        localhost:5432"
    Write-Host "Kafka Broker:               localhost:9092"
}
finally {
    Pop-Location
}
