#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/opt/docker-platform
ENV_FILE="$APP_DIR/.env"
CREDENTIALS=/root/docker-platform-credentials.txt
LOG=/var/log/docker-platform-bootstrap.log
MARKER=/var/lib/docker-platform-firstboot.done

exec > >(tee -a "$LOG") 2>&1

random_secret() {
  openssl rand -base64 24 | tr -d '=+/' | cut -c1-24
}

wait_http() {
  local url="$1"
  local name="$2"
  local tries=60
  local i=1
  while [ "$i" -le "$tries" ]; do
    if curl -kfsS "$url" >/dev/null 2>&1; then
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

echo "[$(date -Is)] Docker Platform bootstrap started"

if [ -e "$MARKER" ]; then
  echo "Bootstrap already completed; ensuring platform services are running"
  systemctl enable --now docker
  docker compose -f "$APP_DIR/docker-compose.yml" --env-file "$ENV_FILE" up -d
  exit 0
fi

mkdir -p "$APP_DIR" /var/lib
chmod 755 "$APP_DIR"

PORTAINER_ADMIN_PASSWORD="$(random_secret)"
NPM_ADMIN_PASSWORD="$(random_secret)"
NPM_UPSTREAM_EMAIL="admin@example.com"
NPM_UPSTREAM_PASSWORD="changeme"
NPM_EFFECTIVE_PASSWORD="$NPM_UPSTREAM_PASSWORD"
NPM_PASSWORD_NOTE="Default upstream password is still active. Change it immediately after first login."
VM_IP="$(get_primary_ip)"

cat > "$ENV_FILE" << EOF
TZ=Asia/Bangkok
EOF
chmod 600 "$ENV_FILE"

systemctl enable --now docker
docker compose -f "$APP_DIR/docker-compose.yml" --env-file "$ENV_FILE" up -d

if wait_http "https://127.0.0.1:9443/api/status" "Portainer"; then
  PORTAINER_INIT_CODE="$(curl -k -s -o /tmp/portainer-init.out -w '%{http_code}' \
    -H 'Content-Type: application/json' \
    -X POST https://127.0.0.1:9443/api/users/admin/init \
    -d '{"Username":"admin","Password":"'"$PORTAINER_ADMIN_PASSWORD"'"}')"
  if [ "$PORTAINER_INIT_CODE" = "200" ] || [ "$PORTAINER_INIT_CODE" = "204" ] || [ "$PORTAINER_INIT_CODE" = "409" ]; then
    echo "Portainer admin initialized or already initialized"
  else
    echo "WARNING: Portainer admin init returned HTTP $PORTAINER_INIT_CODE"
    cat /tmp/portainer-init.out || true
  fi
  rm -f /tmp/portainer-init.out
fi

if wait_http "http://127.0.0.1:81" "Nginx Proxy Manager"; then
  NPM_TOKEN="$(curl -s -X POST http://127.0.0.1:81/api/tokens \
    -H 'Content-Type: application/json' \
    -d '{"identity":"'"$NPM_UPSTREAM_EMAIL"'","secret":"'"$NPM_UPSTREAM_PASSWORD"'"}' | jq -r '.token // empty')"
  if [ -n "$NPM_TOKEN" ]; then
    NPM_AUTH_CODE="$(curl -s -o /tmp/npm-auth.out -w '%{http_code}' \
      -X PUT http://127.0.0.1:81/api/users/me/auth \
      -H "Authorization: Bearer $NPM_TOKEN" \
      -H 'Content-Type: application/json' \
      -d '{"type":"password","current":"'"$NPM_UPSTREAM_PASSWORD"'","secret":"'"$NPM_ADMIN_PASSWORD"'"}')"
    if [ "$NPM_AUTH_CODE" = "200" ] || [ "$NPM_AUTH_CODE" = "204" ]; then
      NPM_EFFECTIVE_PASSWORD="$NPM_ADMIN_PASSWORD"
      NPM_PASSWORD_NOTE="Password changed automatically during first boot."
      echo "Nginx Proxy Manager password changed"
    else
      echo "WARNING: NPM password change returned HTTP $NPM_AUTH_CODE"
      cat /tmp/npm-auth.out || true
    fi
    rm -f /tmp/npm-auth.out
  else
    echo "WARNING: Could not obtain NPM API token; default upstream password remains"
  fi
fi

cat > "$CREDENTIALS" << EOF
Docker Platform Credentials
===========================

VM IP:
  ${VM_IP:-<VM-IP>}

Portainer CE:
  URL: https://${VM_IP:-<VM-IP>}:9443
  Username: admin
  Password: $PORTAINER_ADMIN_PASSWORD

Nginx Proxy Manager:
  URL: http://${VM_IP:-<VM-IP>}:81
  Email: $NPM_UPSTREAM_EMAIL
  Password: $NPM_EFFECTIVE_PASSWORD
  Note: $NPM_PASSWORD_NOTE

Important:
  - Change the Nginx Proxy Manager password immediately after first login.
  - Browser will warn about Portainer self-signed TLS certificate on first access.
  - OpenStack security group should expose 80/443 publicly, and restrict 22/81/9443 to admin IPs.
EOF
chmod 600 "$CREDENTIALS"

touch "$MARKER"

echo "Credentials written to $CREDENTIALS"
echo "[$(date -Is)] Docker Platform bootstrap completed"
