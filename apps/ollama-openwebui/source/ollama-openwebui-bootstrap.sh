#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/opt/ollama-openwebui
ENV_FILE="$APP_DIR/.env"
CREDENTIALS=/root/ollama-openwebui-credentials.txt
LOG=/var/log/ollama-openwebui-bootstrap.log
MARKER=/var/lib/ollama-openwebui-firstboot.done

exec > >(tee -a "$LOG") 2>&1

wait_http() {
  local url="$1"
  local name="$2"
  local tries=60
  local i=1
  while [ "$i" -le "$tries" ]; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "$name is ready"
      return 0
    fi
    sleep 3
    i=$((i + 1))
  done
  echo "WARNING: $name did not become ready in time"
  return 1
}

get_primary_ip() {
  hostname -I 2>/dev/null | awk '{print $1}'
}

echo "[$(date -Is)] Ollama + Open WebUI bootstrap started"

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

cat > "$ENV_FILE" << EOF
TZ=Asia/Bangkok
EOF
chmod 600 "$ENV_FILE"

systemctl enable --now docker
docker compose -f "$APP_DIR/docker-compose.yml" --env-file "$ENV_FILE" up -d

wait_http "http://127.0.0.1:3000" "Open WebUI"
wait_http "http://127.0.0.1:11434" "Ollama"

cat > "$CREDENTIALS" << EOF
Ollama + Open WebUI
===================

VM IP:
  ${VM_IP:-<VM-IP>}

Open WebUI:
  URL: http://${VM_IP:-<VM-IP>}:3000
  First-time setup: open the URL and create your first account.
  The first account becomes the admin.

Pre-pulled models (ready to use):
  - gemma3:4b   (~3 GB RAM)
  - llama3.2:1b (~1.2 GB RAM)

Admin commands:
  List models:     docker exec ollama ollama list
  Pull new model:  docker exec -it ollama ollama pull <model-name>
  View logs:       docker compose -f /opt/ollama-openwebui/docker-compose.yml logs -f

Important:
  - ENABLE_SIGNUP=true (default). Disable after creating admin if single-user.
  - OpenStack security group should expose port 3000 (and restrict if needed).
  - Read more: /root/README-ollama-openwebui-image.txt
EOF
chmod 600 "$CREDENTIALS"

touch "$MARKER"

echo "Credentials written to $CREDENTIALS"
echo "[$(date -Is)] Ollama + Open WebUI bootstrap completed"
