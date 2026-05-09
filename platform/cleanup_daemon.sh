#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="logs/cleanup.log"

echo "[$(date)] Cleanup daemon started" >> "$LOG_FILE"

while true; do
    for STATE_FILE in envs/*.json; do
        # Skip if no state files exist
        [ -f "$STATE_FILE" ] || continue

        ENV_ID=$(jq -r '.id' "$STATE_FILE")
        CREATED_AT=$(jq -r '.created_at' "$STATE_FILE")
        TTL=$(jq -r '.ttl' "$STATE_FILE")

        # Calculate expiry time
        CREATED_TS=$(date -d "$CREATED_AT" +%s)
        EXPIRY_TS=$((CREATED_TS + TTL))
        NOW_TS=$(date +%s)

        if [ "$NOW_TS" -gt "$EXPIRY_TS" ]; then
            echo "[$(date)] TTL expired for $ENV_ID — destroying" >> "$LOG_FILE"
            bash "$SCRIPT_DIR/destroy_env.sh" "$ENV_ID" >> "$LOG_FILE" 2>&1
            echo "[$(date)] Destroyed $ENV_ID" >> "$LOG_FILE"
        else
            REMAINING=$((EXPIRY_TS - NOW_TS))
            echo "[$(date)] $ENV_ID is alive — ${REMAINING}s remaining" >> "$LOG_FILE"
        fi
    done

    sleep 60
done