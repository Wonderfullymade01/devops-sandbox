# DevOps Sandbox Platform

A self-service platform for spinning up isolated temporary environments, deploying apps, simulating outages, and monitoring health — automatically or on demand.

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │         DevOps Sandbox Platform      │
                    │                                      │
  User/CI ──────────│──► Nginx (port 80)                  │
                    │         │                            │
                    │         ▼                            │
                    │    sandbox-nginx                     │
                    │    conf.d/*.conf (dynamic)           │
                    │         │                            │
                    │         ▼                            │
                    │    sandbox-app containers            │
                    │    (one per environment)             │
                    │                                      │
  Operator ─────────│──► Flask API (port 5000)            │
                    │         │                            │
                    │         ▼                            │
                    │    platform/scripts                  │
                    │    create_env.sh                     │
                    │    destroy_env.sh                    │
                    │    simulate_outage.sh                │
                    │                                      │
                    │    monitor/health_poller.sh          │
                    │    platform/cleanup_daemon.sh        │
                    └─────────────────────────────────────┘
```

## Prerequisites

- Docker Desktop with WSL2 integration enabled
- Ubuntu WSL2
- Python 3 + Flask
- jq, curl

## Quick Start (5 commands)

```bash
git clone https://github.com/Wonderfullymade01/devops-sandbox.git
cd devops-sandbox
docker build -t sandbox-app:latest -f platform/Dockerfile.app platform/
docker run -d --name sandbox-nginx -p 80:80 -v $(pwd)/nginx/nginx.conf:/etc/nginx/nginx.conf:ro -v $(pwd)/nginx/conf.d:/etc/nginx/conf.d:ro nginx:latest
bash platform/create_env.sh myapp 1800
```

## Full Demo Walkthrough

### 1. Create an environment
```bash
bash platform/create_env.sh myapp 300
```

### 2. Check it's running
```bash
curl http://localhost:<PORT>/health
```

### 3. Start health monitoring
```bash
bash monitor/health_poller.sh &
```

### 4. Check health via API
```bash
curl http://localhost:5000/envs/<ENV_ID>/health
```

### 5. Simulate outage
```bash
curl -X POST http://localhost:5000/envs/<ENV_ID>/outage \
  -H "Content-Type: application/json" \
  -d '{"mode":"pause"}'
```

### 6. Observe health monitor detecting failure
```bash
curl http://localhost:5000/envs/<ENV_ID>/health
```

### 7. Recover
```bash
curl -X POST http://localhost:5000/envs/<ENV_ID>/outage \
  -H "Content-Type: application/json" \
  -d '{"mode":"recover"}'
```

### 8. Auto-destroy (TTL expiry)
```bash
nohup bash platform/cleanup_daemon.sh &
```
The daemon checks every 60 seconds and destroys expired environments automatically.

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /envs | Create environment |
| GET | /envs | List active environments + TTL |
| DELETE | /envs/:id | Destroy environment |
| GET | /envs/:id/logs | Last 100 lines of app.log |
| GET | /envs/:id/health | Last 10 health check results |
| POST | /envs/:id/outage | Trigger outage simulation |

## Outage Modes

| Mode | Description |
|------|-------------|
| crash | Kill the container |
| pause | Pause the container |
| network | Disconnect from network |
| recover | Restore everything |
| stress | Spike CPU (requires stress-ng) |

## Known Limitations

- Running on Windows WSL2 causes minor file permission warnings on mv operations (harmless)
- Web mode requires react-native-web dependencies
- Nginx uses host networking on WSL2
- stress mode requires stress-ng installed in the container