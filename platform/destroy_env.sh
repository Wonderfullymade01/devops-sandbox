#!/bin/bash
set -euo pipefail

ENV_ID=${1:-""}

if [ -z "$ENV_ID" ]; then
    echo "❌ Usage: destroy_env.sh <env-id>"
    exit 1
fi

STATE_FILE="envs/${ENV_ID}.json"

if [ ! -f "$STATE_FILE" ]; then
    echo "❌ Environment $ENV_ID not found"
    exit 1
fi

echo "[$(date)] Destroying environment: $ENV_ID"

# Kill log shipping process
if [ -f "logs/${ENV_ID}/logger.pid" ]; then
    PID=$(cat "logs/${ENV_ID}/logger.pid")
    kill "$PID" 2>/dev/null || true
    rm "logs/${ENV_ID}/logger.pid"
    echo "[$(date)] Stopped log shipping (PID $PID)"
fi

# Stop and remove container
docker stop "$ENV_ID" 2>/dev/null || true
docker rm "$ENV_ID" 2>/dev/null || true
echo "[$(date)] Removed container: $ENV_ID"

# Remove Docker network
NETWORK=$(jq -r '.network' "$STATE_FILE")
docker network rm "$NETWORK" 2>/dev/null || true
echo "[$(date)] Removed network: $NETWORK"

# Delete Nginx config and reload
if [ -f "nginx/conf.d/${ENV_ID}.conf" ]; then
    rm "nginx/conf.d/${ENV_ID}.conf"
    docker exec sandbox-nginx nginx -s reload
    echo "[$(date)] Removed Nginx config and reloaded"
fi

# Archive logs
mkdir -p "logs/archived/${ENV_ID}"
if [ -d "logs/${ENV_ID}" ]; then
    mv "logs/${ENV_ID}"/* "logs/archived/${ENV_ID}/" 2>/dev/null || true
    rmdir "logs/${ENV_ID}" 2>/dev/null || true
    echo "[$(date)] Archived logs to logs/archived/${ENV_ID}/"
fi

# Delete state file
rm "$STATE_FILE"

echo ""
echo "✅ Environment $ENV_ID destroyed successfully"