#!/usr/bin/env bash
# ==============================================================================
# IAOP Self-Hosted DEV — Database Restore Script (Bash)
# Restores a specific database from SQL/gzip dump with confirmation guard
# ==============================================================================
set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <database_name> <backup_file>"
    exit 1
fi

DATABASE="$1"
BACKUP_FILE="$2"

if [ ! -f "$BACKUP_FILE" ]; then
    echo >&2 "Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo -e "\033[1;31mWARNING: Restoring database '$DATABASE' will overwrite existing data!\033[0m"
read -p "Type 'RESTORE' to proceed: " CONFIRMATION
if [ "$CONFIRMATION" != "RESTORE" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo -e "\033[1;33mTerminating active connections on $DATABASE...\033[0m"
docker exec iaop-postgres psql -U postgres -d postgres -c \
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DATABASE' AND pid <> pg_backend_pid();"

echo -e "\033[1;32mRestoring $DATABASE from $BACKUP_FILE...\033[0m"
if [[ "$BACKUP_FILE" == *.gz ]]; then
    gunzip -c "$BACKUP_FILE" | docker exec -i iaop-postgres psql -U postgres -d "$DATABASE"
else
    cat "$BACKUP_FILE" | docker exec -i iaop-postgres psql -U postgres -d "$DATABASE"
fi

echo -e "\033[1;36mDatabase $DATABASE restored successfully.\033[0m"
