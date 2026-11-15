# ==============================================================================
# IAOP Self-Hosted DEV — Database Restore Script (PowerShell)
# Restores a specific database from SQL dump with confirmation guard
# ==============================================================================

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$Database,

    [Parameter(Mandatory = $true)]
    [string]$BackupFile
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $BackupFile)) {
    Write-Error "Backup file not found: $BackupFile"
}

Write-Host "WARNING: Restoring $Database will overwrite existing data!" -ForegroundColor Red
$Confirmation = Read-Host "Type 'RESTORE' to proceed"
if ($Confirmation -ne "RESTORE") {
    Write-Host "Restore cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host "Terminating active connections on $Database..." -ForegroundColor Yellow
docker exec iaop-postgres psql -U postgres -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$Database' AND pid <> pg_backend_pid();"

Write-Host "Restoring $Database from $BackupFile..." -ForegroundColor Green
Get-Content $BackupFile | docker exec -i iaop-postgres psql -U postgres -d $Database

Write-Host "Database $Database restored successfully." -ForegroundColor Cyan
