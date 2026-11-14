#!/usr/bin/env bash
# ==============================================================================
# IAOP Self-Hosted DEV — Bootstrap Script (Bash)
# Initializes environment, networks, and foundation services
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PROFILE="${1:-foundation}"

cd "$ROOT_DIR"

echo -e "\033[1;36m=== IAOP Self-Hosted DEV Bootstrap ===\033[0m"

# 1. Check prerequisites
command -v docker >/dev/null 2>&1 || { echo >&2 "Docker is required but not installed."; exit 1; }
command -v docker compose >/dev/null 2>&1 || { echo >&2 "Docker Compose is required but not installed."; exit 1; }

# 2. Setup .env
if [ ! -f "$ROOT_DIR/.env" ]; then
    echo -e "\033[1;33mCreating .env from .env.example...\033[0m"
    cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
fi

# 3. Create network if needed
if ! docker network ls --filter name=iaop-internal -q | grep -q .; then
    echo -e "\033[1;32mCreating docker bridge network: iaop-internal...\033[0m"
    docker network create iaop-internal >/dev/null
fi

# 4. Start Compose profile
echo -e "\033[1;32mStarting Docker Compose profile: $PROFILE...\033[0m"
docker compose --profile "$PROFILE" up -d

echo -e "\n\033[1;33mWaiting for PostgreSQL to pass health check...\033[0m"
TIMEOUT=60
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' iaop-postgres 2>/dev/null || echo "starting")
    if [ "$STATUS" = "healthy" ]; then
        echo -e "\033[1;32mPostgreSQL is healthy!\033[0m"
        break
    fi
    sleep 3
    ELAPSED=$((ELAPSED + 3))
    echo "Waiting for PostgreSQL ($ELAPSED s)..."
done

echo -e "\n\033[1;36m=== IAOP Environment Ready ===\033[0m"
echo "Centralized Swagger Portal: http://localhost/docs/"
echo "Keycloak Identity Console:  http://localhost/auth/ (admin/admin_dev_secret_change_me)"
echo "Reverse Proxy Ingress:      http://localhost/"
echo "PostgreSQL Database:        localhost:5432"
echo "Kafka Broker:               localhost:9092"
