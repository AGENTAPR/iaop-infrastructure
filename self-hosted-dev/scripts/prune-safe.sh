#!/usr/bin/env bash
# ==============================================================================
# IAOP Self-Hosted DEV — Safe Docker Prune Script (Bash)
# Prunes unused images and build caches to protect 256 GB SSD
# STRICT SAFETY GUARD: NEVER PRUNES DOCKER VOLUMES!
# ==============================================================================
set -euo pipefail

echo -e "\033[1;36m=== IAOP Safe Docker Disk Maintenance ===\033[0m"

# 1. Prune unused images older than 72 hours
echo -e "\033[1;33mPruning unused container images (>72h old)...\033[0m"
docker image prune -a -f --filter "until=72h"

# 2. Prune build cache (keeps last 10 GB)
echo -e "\n\033[1;33mPruning builder cache (maintaining 10GB working cache)...\033[0m"
docker builder prune -f --keep-storage 10GB

# 3. Report Disk Usage
echo -e "\n\033[1;32mCurrent Docker Disk Utilization:\033[0m"
docker system df

echo -e "\n\033[1;32mHost Disk Space:\033[0m"
df -h / | awk 'NR==1 || NR==2'

echo -e "\033[1;36mSafe prune completed. Docker persistent volumes were preserved.\033[0m"
