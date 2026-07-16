#!/bin/bash
set -e

ENV_FILE="/opt/anythingllm/.env"
CRED_FILE="/root/anythingllm-credentials.txt"
LOG_FILE="/var/log/anythingllm-bootstrap.log"
COMPOSE_DIR="/opt/anythingllm"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# Already initialized — just start
if [ -f "$ENV_FILE" ]; then
    log "Bootstrap: .env exists — starting services"
    cd "$COMPOSE_DIR"
    docker compose up -d
    log "Bootstrap: done (reusing existing config)"
    exit 0
fi

log "Bootstrap: first boot — generating secrets"

JWT_SECRET=$(openssl rand -base64 32)

cat > "$ENV_FILE" << APP_ENV
JWT_SECRET=${JWT_SECRET}
APP_ENV
chmod 600 "$ENV_FILE"

cat > "$CRED_FILE" << CRED_EOF
=== AnythingLLM Docker Credentials ===
Generated: $(date)

Security:
  JWT_SECRET: ${JWT_SECRET}

Getting Started:
  1. Open http://<VM-IP> in your browser.
  2. Follow the setup wizard to create your admin account.
  3. Configure your LLM preference (e.g. OpenAI API, Gemini API, or local Ollama).

Configuration & Data:
  Docker Compose Directory: /opt/anythingllm
  Nginx Config: /opt/anythingllm/nginx.conf
  Persistent Data: Managed via 'anythingllm_data' Docker volume.

Manage:
  cd /opt/anythingllm
  docker compose ps        # check status
  docker compose logs -f   # view logs
  docker compose restart   # restart services
  
Troubleshooting:
  If you forget your admin password, you can run:
  anythingllm-reset-password
CRED_EOF
chmod 600 "$CRED_FILE"

log "Bootstrap: pulling images"
cd "$COMPOSE_DIR"
docker compose pull --quiet 2>/dev/null || log "Bootstrap: WARNING — could not pull latest images, using pre-pulled cache"

log "Bootstrap: starting services"
# Pre‑set volume permissions for container user uid=1000
docker run --rm -v anythingllm_anythingllm_data:/data alpine chown -R 1000:1000 /data 2>/dev/null || log "Bootstrap: WARNING — could not set volume permissions, container may fail to write"
docker compose up -d

log "Bootstrap: waiting for AnythingLLM Nginx proxy to be ready..."
for i in $(seq 1 30); do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -E "200|302|401|403" >/dev/null 2>&1; then
        log "Bootstrap: AnythingLLM proxy is ready"
        break
    fi
    sleep 2
done

log "Bootstrap: done — open http://<VM-IP> to complete AnythingLLM setup"
