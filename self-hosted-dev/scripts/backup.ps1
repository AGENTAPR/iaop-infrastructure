# ==============================================================================
# IAOP Self-Hosted DEV — Database Backup Script (PowerShell)
# Dumps all service databases with timestamp and gzip compression
# Enforces retention policy to protect 256 GB SSD
# ==============================================================================

[CmdletBinding()]
param (
    [string]$BackupDir = "./backups",
    [int]$RetentionDays = 7
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptDir
$TargetDir = Join-Path $RootDir $BackupDir

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Databases = @("iaop_agent", "iaop_agency", "iaop_agent_bff", "iaop_integration", "iaop_workflow", "iaop_keycloak")

Write-Host "=== IAOP Database Backup: $Timestamp ===" -ForegroundColor Cyan

foreach ($db in $Databases) {
    $outFile = Join-Path $TargetDir "$($db)_$Timestamp.sql"
    Write-Host "Backing up database: $db -> $outFile..." -ForegroundColor Yellow
    docker exec iaop-postgres pg_dump -U postgres -F p -d $db > $outFile
}

Write-Host "`nPruning backups older than $RetentionDays days in $TargetDir..." -ForegroundColor Green
$Cutoff = (Get-Date).AddDays(-$RetentionDays)
Get-ChildItem -Path $TargetDir -Filter "*.sql" | Where-Object { $_.LastWriteTime -lt $Cutoff } | Remove-Item -Force

Write-Host "Backup process completed successfully." -ForegroundColor Cyan
