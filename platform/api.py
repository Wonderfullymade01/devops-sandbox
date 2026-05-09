#!/usr/bin/env python3
import os
import json
import subprocess
from datetime import datetime, timezone
from flask import Flask, jsonify, request

app = Flask(__name__)

ENVS_DIR = "envs"
LOGS_DIR = "logs"
PLATFORM_DIR = "platform"

def load_env(env_id):
    path = os.path.join(ENVS_DIR, f"{env_id}.json")
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return json.load(f)

def ttl_remaining(env):
    created = datetime.fromisoformat(env["created_at"].replace("Z", "+00:00"))
    now = datetime.now(timezone.utc)
    elapsed = (now - created).total_seconds()
    remaining = env["ttl"] - elapsed
    return max(0, int(remaining))

@app.route("/envs", methods=["POST"])
def create_env():
    data = request.get_json() or {}
    name = data.get("name", "sandbox")
    ttl = data.get("ttl", 1800)
    result = subprocess.run(
        ["bash", f"{PLATFORM_DIR}/create_env.sh", name, str(ttl)],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return jsonify({"error": result.stderr}), 500
    return jsonify({"message": result.stdout}), 201

@app.route("/envs", methods=["GET"])
def list_envs():
    envs = []
    if not os.path.exists(ENVS_DIR):
        return jsonify([])
    for f in os.listdir(ENVS_DIR):
        if f.endswith(".json"):
            env = load_env(f.replace(".json", ""))
            if env:
                env["ttl_remaining"] = ttl_remaining(env)
                envs.append(env)
    return jsonify(envs)

@app.route("/envs/<env_id>", methods=["DELETE"])
def destroy_env(env_id):
    env = load_env(env_id)
    if not env:
        return jsonify({"error": "Environment not found"}), 404
    result = subprocess.run(
        ["bash", f"{PLATFORM_DIR}/destroy_env.sh", env_id],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return jsonify({"error": result.stderr}), 500
    return jsonify({"message": f"Environment {env_id} destroyed"})

@app.route("/envs/<env_id>/logs", methods=["GET"])
def get_logs(env_id):
    log_file = os.path.join(LOGS_DIR, env_id, "app.log")
    if not os.path.exists(log_file):
        return jsonify({"error": "No logs found"}), 404
    with open(log_file) as f:
        lines = f.readlines()
    return jsonify({"logs": lines[-100:]})

@app.route("/envs/<env_id>/health", methods=["GET"])
def get_health(env_id):
    health_file = os.path.join(LOGS_DIR, env_id, "health.log")
    if not os.path.exists(health_file):
        return jsonify({"error": "No health data found"}), 404
    with open(health_file) as f:
        lines = f.readlines()
    return jsonify({"health": lines[-10:]})

@app.route("/envs/<env_id>/outage", methods=["POST"])
def trigger_outage(env_id):
    data = request.get_json() or {}
    mode = data.get("mode", "crash")
    env = load_env(env_id)
    if not env:
        return jsonify({"error": "Environment not found"}), 404
    result = subprocess.run(
        ["bash", f"{PLATFORM_DIR}/simulate_outage.sh",
         "--env", env_id, "--mode", mode],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return jsonify({"error": result.stderr}), 500
    return jsonify({"message": result.stdout})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)