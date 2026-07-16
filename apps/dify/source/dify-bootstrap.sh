#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/opt/dify
ENV_FILE="$APP_DIR/.env"
CREDENTIALS=/root/dify-credentials.txt
LOG=/var/log/dify-bootstrap.log
MARKER=/var/lib/dify-firstboot.done

exec > >(tee -a "$LOG") 2>&1

wait_http() {
  local url="$1"
  local name="$2"
  local tries=120
  local i=1
  while [ "$i" -le "$tries" ]; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "$name is ready"
      return 0
    fi
    sleep 5
    i=$((i + 1))
  done
  echo "WARNING: $name did not become ready in time"
  return 1
}

get_primary_ip() {
  hostname -I 2>/dev/null | awk '{print $1}'
}

echo "[$(date -Is)] Dify CE bootstrap started"

VM_IP="$(get_primary_ip)"

if [ -e "$MARKER" ]; then
  echo "Bootstrap already completed"

  CURRENT_CREDENTIAL_IP=""
  if [ -f "$CREDENTIALS" ]; then
    CURRENT_CREDENTIAL_IP=$(grep -oP '^\s*\d+\.\d+\.\d+\.\d+' "$CREDENTIALS" | head -1)
  fi

  if [ -z "$CURRENT_CREDENTIAL_IP" ] || [ "$CURRENT_CREDENTIAL_IP" != "$VM_IP" ]; then
    echo "IP changed (credential: ${CURRENT_CREDENTIAL_IP:-missing}, current: $VM_IP) — regenerating credentials"
  else
    echo "IP unchanged — ensuring services are running"
    systemctl enable --now docker
    docker compose -f "$APP_DIR/docker-compose.yml" --env-file "$ENV_FILE" up -d
    exit 0
  fi
fi

mkdir -p "$APP_DIR" /var/lib
chmod 755 "$APP_DIR"

VM_IP="$(get_primary_ip)"

# ── Generate secrets ───────────────────────────────────────
SECRET_KEY=$(openssl rand -base64 42)
DB_PASSWORD=$(openssl rand -base64 24)
REDIS_PASSWORD=$(openssl rand -base64 24)
INIT_PASSWORD=$(openssl rand -base64 12 | tr -d '=+/')
SANDBOX_API_KEY="dify-sandbox-$(openssl rand -hex 16)"

# ── Create storage directory ────────────────────────────────
mkdir -p /opt/dify/storage
chmod -R 777 /opt/dify/storage

# ── Write .env ──────────────────────────────────────────────
cat > "$ENV_FILE" << EOF
# ── Security ────────────────────────────────────────────────
SECRET_KEY=${SECRET_KEY}
INIT_PASSWORD=${INIT_PASSWORD}

# ── Database ────────────────────────────────────────────────
DB_TYPE=postgresql
DB_HOST=db_postgres
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=${DB_PASSWORD}
DB_DATABASE=dify
SQLALCHEMY_POOL_SIZE=30
POSTGRES_MAX_CONNECTIONS=100
POSTGRES_SHARED_BUFFERS=256MB

# ── Redis ───────────────────────────────────────────────────
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_DB=0

# ── Vector Store ────────────────────────────────────────────
VECTOR_STORE=weaviate
WEAVIATE_ENDPOINT=http://weaviate:8080

# ── Code Sandbox ────────────────────────────────────────────
CODE_EXECUTION_ENDPOINT=http://sandbox:8194
CODE_EXECUTION_API_KEY=${SANDBOX_API_KEY}
SANDBOX_API_KEY=${SANDBOX_API_KEY}
SSRF_PROXY_HOST=ssrf_proxy
SSRF_PROXY_PORT=3128

# ── URLs ────────────────────────────────────────────────────
CONSOLE_WEB_URL=http://${VM_IP}
APP_WEB_URL=http://${VM_IP}
CONSOLE_API_URL=
APP_API_URL=

# ── Migration ────────────────────────────────────────────────
MIGRATION_ENABLED=true

# ── Performance ─────────────────────────────────────────────
CELERY_WORKER_AMOUNT=2
SERVER_WORKER_AMOUNT=1

# ── Telemetry ───────────────────────────────────────────────
CHECK_UPDATE_URL=

# ── Timezone ────────────────────────────────────────────────
TZ=Asia/Bangkok
EOF
chmod 600 "$ENV_FILE"

# ── Start services ──────────────────────────────────────────
systemctl enable --now docker
docker compose -f "$APP_DIR/docker-compose.yml" --env-file "$ENV_FILE" up -d

# ── Wait for API ────────────────────────────────────────────
wait_http "http://127.0.0.1:80/health" "Dify API"

# ── Write credentials ───────────────────────────────────────
cat > "$CREDENTIALS" << EOF
Dify CE
=======

VM IP:
  ${VM_IP:-<VM-IP>}

Setup:
  URL: http://${VM_IP:-<VM-IP>}/install
  Initial password: ${INIT_PASSWORD}

  IMPORTANT: Use this password to complete the initial setup.
  You will create an admin account after visiting /install.

After setup, add LLM providers via:
  Settings → Model Providers → Add provider (API key required)

Stack services (12 containers):
  - api          Flask REST API (Gunicorn + gevent)
  - worker       Celery worker (dataset indexing, email, workflow)
  - worker_beat  Celery beat scheduler
  - web          Next.js frontend
  - api_websocket  Real-time collaboration WebSocket
  - db_postgres  PostgreSQL 15
  - redis        Redis 6 (cache + broker)
  - nginx        Reverse proxy on port 80
  - sandbox      Code execution sandbox
  - ssrf_proxy   Squid SSRF protection
  - weaviate     Vector database

Vector DB: Weaviate (default)
LLM: Uses external API only (OpenAI, Anthropic, etc.)
     No GPU required — platform itself runs on CPU

Admin commands:
  View status:    docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env ps
  View logs:      docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env logs -f
  Restart:        docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env restart
  Stop:           docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env down

Important:
  - Keep INIT_PASSWORD safe — anyone with it can complete setup.
  - INIT_PASSWORD is only used for initial setup, not for daily login.
  - OpenStack security group should expose port 80.
  - Read more: /root/README-dify-image.txt

License:
  Dify Open Source License (based on Apache 2.0 with conditions)
  - Multi-tenant service prohibited without written permission
  - Do not remove or modify Dify LOGO/copyright
EOF
chmod 600 "$CREDENTIALS"

touch "$MARKER"

echo "Credentials written to $CREDENTIALS"
echo "[$(date -Is)] Dify CE bootstrap completed"
