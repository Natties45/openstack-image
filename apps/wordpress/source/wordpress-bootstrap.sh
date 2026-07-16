#!/bin/bash
set -e

ENV_FILE="/opt/wordpress/.env"
CRED_FILE="/root/wordpress-credentials.txt"
LOG_FILE="/var/log/wordpress-bootstrap.log"
COMPOSE_DIR="/opt/wordpress"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

gen_password() {
    local len="${1:-24}"
    openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c "$len"
}

get_all_ips() {
    ip -4 addr show scope global \
        | grep -vE 'docker[0-9]+|br-| veth' \
        | grep -oP '(?<=inet\s)\d+(\.\d+){3}' \
        | sort -u
}

# Already initialized — just start
if [ -f "$ENV_FILE" ]; then
    log "Bootstrap: .env exists — starting services"
    cd "$COMPOSE_DIR"
    docker compose --profile http up -d
    log "Bootstrap: done (reusing existing config)"
    exit 0
fi

log "Bootstrap: first boot — generating alphanumeric DB secrets"

MARIADB_ROOT_PASSWORD=$(gen_password 32)
MARIADB_DATABASE="wordpress"
MARIADB_USER="wordpress"
MARIADB_PASSWORD=$(gen_password 32)

cat > "$ENV_FILE" << EOF
MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}
MARIADB_DATABASE=${MARIADB_DATABASE}
MARIADB_USER=${MARIADB_USER}
MARIADB_PASSWORD=${MARIADB_PASSWORD}
EOF
chmod 600 "$ENV_FILE"

cat > "$CRED_FILE" << EOF
=== WordPress Customer Image Credentials ===
Generated: $(date)

Database:
  Host:     db (internal Docker network)
  Name:     ${MARIADB_DATABASE}
  User:     ${MARIADB_USER}
  Password: ${MARIADB_PASSWORD}

Root DB Password: ${MARIADB_ROOT_PASSWORD}

Detected VM IPs:
$(get_all_ips | sed 's/^/  - /')

WordPress Setup:
  Open http://<VM-IP> in browser.
  Follow the 5-minute install wizard.
  Create your own WordPress admin account and password.

Helpers:
  wordpress-status
  wordpress-logs
  wordpress-restart
  wordpress-upgrade
  wordpress-rollback
  wp-cli --info
EOF
chmod 600 "$CRED_FILE"

cd "$COMPOSE_DIR"

log "Bootstrap: starting services from locally built images (offline-safe; no pull at boot)"
docker compose --profile http up -d

log "Bootstrap: waiting for WordPress PHP-FPM"
for i in $(seq 1 30); do
    if docker compose exec -T wordpress php -r "echo 'ok';" 2>/dev/null | grep -q ok; then
        log "Bootstrap: WordPress is ready"
        break
    fi
    sleep 2
done

if ! docker compose exec -T wordpress php -r "echo 'ok';" 2>/dev/null | grep -q ok; then
    log "Bootstrap: WARNING — WordPress did not become ready within 60 seconds"
    log "Bootstrap: Check logs with wordpress-logs"
fi

log "Bootstrap: done — open http://<VM-IP> to complete WordPress setup"
