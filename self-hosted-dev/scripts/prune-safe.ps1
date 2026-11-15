# ==============================================================================
# IAOP Self-Hosted DEV — Safe Docker Prune Script (PowerShell)
# Prunes unused images and build caches to protect 256 GB SSD
# STRICT SAFETY GUARD: NEVER PRUNES DOCKER VOLUMES!
# ==============================================================================

Write-Host "=== IAOP Safe Docker Disk Maintenance ===" -ForegroundColor Cyan

# 1. Prune unused images older than 72 hours
Write-Host "Pruning unused container images (>72h old)..." -ForegroundColor Yellow
docker image prune -a -f --filter "until=72h"

# 2. Prune build cache (keeps last 10 GB)
Write-Host "`nPruning builder cache (maintaining 10GB working cache)..." -ForegroundColor Yellow
docker builder prune -f --keep-storage 10GB

# 3. Report Disk Usage
Write-Host "`nCurrent Docker Disk Utilization:" -ForegroundColor Green
docker system df

Write-Host "`nHost Disk Space:" -ForegroundColor Green
Get-PSDrive -PSProvider FileSystem | Select-Object Name, @{Name="FreeGB";Expression={[math]::Round($_.Free/1GB,2)}}, @{Name="TotalGB";Expression={[math]::Round(($_.Used+$_.Free)/1GB,2)}} | Format-Table -AutoSize

Write-Host "Safe prune completed. Docker persistent volumes were preserved." -ForegroundColor Cyan
