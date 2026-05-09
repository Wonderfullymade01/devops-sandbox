#!/bin/bash
set -euo pipefail

ENV_ID=""
MODE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --env) ENV_ID="$2"; shift 2;;
        --mode) MODE="$2"; shift 2;;
        *) echo "Unknown option: $1"; exit 1;;
    esac
done

if [ -z "$ENV_ID" ] || [ -z "$MODE" ]; then
    echo "❌ Usage: simulate_outage.sh --env <env-id> --mode <crash|pause|network|recover|stress>"
    exit 1
fi

# Guard — never run against Nginx or daemon
if [[ "$ENV_ID" == *"nginx"* ]] || [[ "$ENV_ID" == *"daemon"* ]]; then
    echo "❌ Cannot simulate outage against Nginx or daemon container"
    exit 1
fi

STATE_FILE="envs/${ENV_ID}.json"
if [ ! -f "$STATE_FILE" ]; then
    echo "❌ Environment $ENV_ID not found"
    exit 1
fi

NETWORK=$(jq -r '.network' "$STATE_FILE")

case $MODE in
    crash)
        echo "[$(date)] Simulating CRASH for $ENV_ID"
        docker kill "$ENV_ID"
        echo "✅ Container killed — health monitor should detect within 90s"
        ;;
    pause)
        echo "[$(date)] Simulating PAUSE for $ENV_ID"
        docker pause "$ENV_ID"
        echo "✅ Container paused — use --mode recover to unpause"
        ;;
    network)
        echo "[$(date)] Simulating NETWORK disconnect for $ENV_ID"
        docker network disconnect "$NETWORK" "$ENV_ID"
        echo "✅ Network disconnected — use --mode recover to reconnect"
        ;;
    recover)
        echo "[$(date)] Recovering $ENV_ID"
        docker unpause "$ENV_ID" 2>/dev/null || true
        docker network connect "$NETWORK" "$ENV_ID" 2>/dev/null || true
        docker start "$ENV_ID" 2>/dev/null || true
        jq '.status = "running"' "$STATE_FILE" > "/tmp/${ENV_ID}.json"
        mv "/tmp/${ENV_ID}.json" "$STATE_FILE"
        echo "✅ Environment recovered"
        ;;
    stress)
        echo "[$(date)] Simulating STRESS for $ENV_ID"
        docker exec "$ENV_ID" stress-ng --cpu 2 --timeout 30s || \
        echo "⚠️  stress-ng not available in container"
        ;;
    *)
        echo "❌ Unknown mode: $MODE"
        echo "Valid modes: crash, pause, network, recover, stress"
        exit 1
        ;;
esac