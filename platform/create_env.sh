#!/bin/bash
set -euo pipefail

NAME=${1:-"sandbox"}
TTL=${2:-1800}

ENV_ID="env-$(date +%s)-$(openssl rand -hex 3)"
NETWORK_NAME="net-${ENV_ID}"
PORT=$(shuf -i 3000-9000 -n 1)
CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STATE_FILE="envs/${ENV_ID}.json"

echo "[$(date)] Creating environment: $ENV_ID (name=$NAME, ttl=${TTL}s)"

# Create Docker network
docker network create "$NETWORK_NAME"

# Start app container
docker run -d \
  --name "$ENV_ID" \
  --network "$NETWORK_NAME" \
  --label "sandbox.env=$ENV_ID" \
  --label "sandbox.name=$NAME" \
  -p "${PORT}:3000" \
  -e "ENV_ID=$ENV_ID" \
  -e "ENV_NAME=$NAME" \
  sandbox-app:latest

# Write state file atomically
cat > "/tmp/${ENV_ID}.json" <<EOF
{
  "id": "$ENV_ID",
  "name": "$NAME",
  "created_at": "$CREATED_AT",
  "ttl": $TTL,
  "port": $PORT,
  "network": "$NETWORK_NAME",
  "status": "running"
}
EOF
mv "/tmp/${ENV_ID}.json" "$STATE_FILE"

# Create Nginx config
cat > "nginx/conf.d/${ENV_ID}.conf" <<EOF
server {
    listen 80;
    server_name ${ENV_ID}.localhost;

    location / {
        proxy_pass http://localhost:${PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        add_header X-Env-ID "$ENV_ID";
    }
}
EOF

# Reload Nginx
docker exec sandbox-nginx nginx -s reload

# Start log shipping
mkdir -p "logs/${ENV_ID}"
docker logs -f "$ENV_ID" >> "logs/${ENV_ID}/app.log" 2>&1 &
echo $! > "logs/${ENV_ID}/logger.pid"

echo ""
echo "✅ Environment created!"
echo "   ID:   $ENV_ID"
echo "   Name: $NAME"
echo "   URL:  http://${ENV_ID}.localhost"
echo "   Port: $PORT"
echo "   TTL:  ${TTL}s (expires at $(date -u -d "+${TTL} seconds" +%Y-%m-%dT%H:%M:%SZ))"