.PHONY: up down create destroy logs health simulate clean

up:
	@echo "Starting Nginx, daemon and API..."
	@mkdir -p nginx/conf.d logs envs
	@docker run -d --name sandbox-nginx \
		-p 80:80 \
		-v $(PWD)/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
		-v $(PWD)/nginx/conf.d:/etc/nginx/conf.d:ro \
		--network host \
		nginx:latest || true
	@nohup bash platform/cleanup_daemon.sh > logs/cleanup.log 2>&1 &
	@echo $$! > logs/daemon.pid
	@pip install flask -q
	@nohup python3 platform/api.py > logs/api.log 2>&1 &
	@echo $$! > logs/api.pid
	@echo "✅ Platform is up!"
	@echo "   API: http://localhost:5000"
	@echo "   Nginx: http://localhost:80"

down:
	@echo "Stopping platform..."
	@for f in envs/*.json; do \
		[ -f "$$f" ] || continue; \
		ID=$$(jq -r '.id' "$$f"); \
		bash platform/destroy_env.sh "$$ID" || true; \
	done
	@docker stop sandbox-nginx 2>/dev/null || true
	@docker rm sandbox-nginx 2>/dev/null || true
	@[ -f logs/daemon.pid ] && kill $$(cat logs/daemon.pid) 2>/dev/null || true
	@[ -f logs/api.pid ] && kill $$(cat logs/api.pid) 2>/dev/null || true
	@echo "✅ Platform is down"

create:
	@read -p "Environment name: " name; \
	read -p "TTL in seconds (default 1800): " ttl; \
	ttl=$${ttl:-1800}; \
	bash platform/create_env.sh "$$name" "$$ttl"

destroy:
	@bash platform/destroy_env.sh "$(ENV)"

logs:
	@tail -f logs/$(ENV)/app.log

health:
	@echo "=== Environment Health Status ==="
	@for f in envs/*.json; do \
		[ -f "$$f" ] || continue; \
		ID=$$(jq -r '.id' "$$f"); \
		STATUS=$$(jq -r '.status' "$$f"); \
		NAME=$$(jq -r '.name' "$$f"); \
		echo "  $$ID ($$NAME): $$STATUS"; \
	done

simulate:
	@bash platform/simulate_outage.sh --env "$(ENV)" --mode "$(MODE)"

clean:
	@echo "Wiping all state..."
	@rm -rf logs/* envs/*
	@mkdir -p logs envs
	@echo "✅ Clean complete"