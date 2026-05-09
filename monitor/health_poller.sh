#!/bin/bash
set -euo pipefail

ENVS_DIR="envs"
LOGS_DIR="logs"
INTERVAL=30
FAILURE_THRESHOLD=3

declare -A FAILURE_COUNTS

echo "[$(date)] Health poller started"

while true; do
    for STATE_FILE in "$ENVS_DIR"/*.json; do
        [ -f "$STATE_FILE" ] || continue

        ENV_ID=$(jq -r '.id' "$STATE_FILE")
        PORT=$(jq -r '.port' "$STATE_FILE")
        STATUS=$(jq -r '.status' "$STATE_FILE")

        [ "$STATUS" == "running" ] || continue

        mkdir -p "$LOGS_DIR/$ENV_ID"
        HEALTH_LOG="$LOGS_DIR/$ENV_ID/health.log"

        START=$(date +%s%N)
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time 5 "http://localhost:${PORT}/health" 2>/dev/null || echo "000")
        END=$(date +%s%N)
        LATENCY=$(( (END - START) / 1000000 ))

        TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        echo "$TIMESTAMP | status=$HTTP_STATUS | latency=${LATENCY}ms | env=$ENV_ID" \
            >> "$HEALTH_LOG"

        if [ "$HTTP_STATUS" != "200" ]; then
            FAILURE_COUNTS[$ENV_ID]=$(( ${FAILURE_COUNTS[$ENV_ID]:-0} + 1 ))
            if [ "${FAILURE_COUNTS[$ENV_ID]}" -ge "$FAILURE_THRESHOLD" ]; then
                echo "⚠️  [$(date)] $ENV_ID is DEGRADED after ${FAILURE_COUNTS[$ENV_ID]} failures"
                jq '.status = "degraded"' "$STATE_FILE" > "/tmp/${ENV_ID}.json"
                mv "/tmp/${ENV_ID}.json" "$STATE_FILE"
            fi
        else
            FAILURE_COUNTS[$ENV_ID]=0
        fi
    done

    sleep "$INTERVAL"
done