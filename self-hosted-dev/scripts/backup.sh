#!/usr/bin/env bash
# ==============================================================================
# IAOP Self-Hosted DEV — Database Backup Script (Bash)
# Dumps all service databases with timestamp and gzip compression
# Enforces retention policy to protect 256 GB SSD
# ==============================================================================
set -euo pipefail

BACKUP_DIR="${1:-./backups}"
RETENTION_DAYS="${2:-7}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DATABASES=("iaop_agent" "iaop_agency" "iaop_agent_bff" "iaop_integration" "iaop_workflow" "iaop_keycloak")

mkdir -p "$BACKUP_DIR"

echo -e "\033[1;36m=== IAOP Database Backup: $TIMESTAMP ===\033[0m"

for db in "${DATABASES[@]}"; do
    OUT_FILE="$BACKUP_DIR/${db}_${TIMESTAMP}.sql.gz"
    echo -e "\033[1;33mBacking up database: $db -> $OUT_FILE...\033[0m"
    docker exec iaop-postgres pg_dump -U postgres -F p -d "$db" | gzip > "$OUT_FILE"
done

echo -e "\n\033[1;32mPruning backups older than $RETENTION_DAYS days in $BACKUP_DIR...\033[0m"
find "$BACKUP_DIR" -name "*.sql.gz" -type f -mtime "+$RETENTION_DAYS" -delete

echo -e "\033[1;36mBackup process completed successfully.\033[0m"
