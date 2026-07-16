#!/bin/bash
set -e

ENV_FILE="/opt/nextcloud/.env"
CRED_FILE="/root/nextcloud-credentials.txt"
LOG_FILE="/var/log/nextcloud-bootstrap.log"
COMPOSE_DIR="/opt/nextcloud"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# Generate random alphanumeric-only password (no + / = that break URI/connection strings)
gen_password() {
    local len="${1:-24}"
    openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c "$len"
}

# Get all non-loopback, non-Docker-bridge IPv4 addresses on this VM
get_all_ips() {
    ip -4 addr show scope global | grep -vE 'docker[0-9]+|br-' | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | sort -u
}

nextcloud_occ() {
    docker compose exec -T -u www-data nextcloud php occ "$@"
}

wait_for_install() {
    log "Bootstrap: waiting for Nextcloud install"
    local delays=(2 5 10 15 30 30 30 30 30 30 30 30 30 30 30)
    for delay in "${delays[@]}"; do
        if nextcloud_occ status 2>/dev/null | grep -q "installed: true"; then
            log "Bootstrap: Nextcloud installed"
            return 0
        fi
        sleep "$delay"
    done
    log "Bootstrap: Nextcloud install did not complete"
    return 1
}

# Append IPs to trusted_domains — never remove existing entries (protects user-added domains)
append_trusted_domains() {
    log "Bootstrap: syncing trusted_domains"
    for ip in $(get_all_ips); do
        if ! nextcloud_occ config:system:get trusted_domains 2>/dev/null | grep -qF "$ip"; then
            log "Bootstrap: adding trusted_domain: $ip"
            nextcloud_occ config:system:set trusted_domains "$(nextcloud_occ config:system:get trusted_domains 2>/dev/null | grep -c '^')" --value="$ip"
        fi
    done
    for host in localhost 127.0.0.1; do
        if ! nextcloud_occ config:system:get trusted_domains 2>/dev/null | grep -qFx "$host"; then
            nextcloud_occ config:system:set trusted_domains "$(nextcloud_occ config:system:get trusted_domains 2>/dev/null | grep -c '^')" --value="$host"
        fi
    done
}

configure_redis() {
    local redis_pass="$1"
    log "Bootstrap: configuring Redis memcache"
    nextcloud_occ config:system:set memcache.locking --value="\OC\Memcache\Redis"
    nextcloud_occ config:system:set memcache.distributed --value="\OC\Memcache\Redis"
    nextcloud_occ config:system:set redis host --value="redis"
    nextcloud_occ config:system:set redis port --value=6379 --type=integer
    nextcloud_occ config:system:set redis password --value="$redis_pass"
}

configure_opcache() {
    log "Bootstrap: tuning PHP opcache"
    nextcloud_occ config:system:set opcache.interned_strings_buffer --value=16 --type=integer
    nextcloud_occ config:system:set opcache.max_accelerated_files --value=10000 --type=integer
    nextcloud_occ config:system:set opcache.memory_consumption --value=128 --type=integer
}

setup_cron() {
    log "Bootstrap: setting up system cron"
    cat > /etc/cron.d/nextcloud << 'CRONEOF'
*/5 * * * * www-data cd /opt/nextcloud && docker compose exec -T -u www-data nextcloud php -f /var/www/html/cron.php > /dev/null 2>&1
CRONEOF
    chmod 644 /etc/cron.d/nextcloud
}

install_helpers() {
    log "Bootstrap: installing helper scripts"

    cat > /usr/local/bin/nc-occ << 'HELPEOF'
#!/bin/bash
cd /opt/nextcloud && docker compose exec -T -u www-data nextcloud php occ "$@"
HELPEOF

    cat > /usr/local/bin/nc-status << 'HELPEOF'
#!/bin/bash
cd /opt/nextcloud && docker compose --profile http ps
HELPEOF

    cat > /usr/local/bin/nc-logs << 'HELPEOF'
#!/bin/bash
cd /opt/nextcloud && docker compose logs --tail=50 "$@"
HELPEOF

    cat > /usr/local/bin/nc-restart << 'HELPEOF'
#!/bin/bash
cd /opt/nextcloud && docker compose --profile http restart
HELPEOF

    cat > /usr/local/bin/nc-upgrade << 'HELPEOF'
#!/bin/bash
set -e
COMPOSE_DIR="/opt/nextcloud"
cd "$COMPOSE_DIR"
PREV_IMAGE=$(docker inspect nextcloud-nextcloud-1 --format '{{.Config.Image}}' 2>/dev/null || echo "unknown")
echo "$PREV_IMAGE" > "$COMPOSE_DIR/.previous-image"
chmod 600 "$COMPOSE_DIR/.previous-image"
echo "Saving previous image: $PREV_IMAGE"
docker compose exec -T -u www-data nextcloud php occ maintenance:mode --on
docker compose pull nextcloud
docker compose up -d nextcloud
docker compose --profile http restart nginx
sleep 10
docker compose exec -T -u www-data nextcloud php occ maintenance:mode --off
echo "Upgrade completed. New image: $(docker inspect nextcloud-nextcloud-1 --format '{{.Config.Image}}')"
HELPEOF

    cat > /usr/local/bin/nc-rollback << 'HELPEOF'
#!/bin/bash
set -e
COMPOSE_DIR="/opt/nextcloud"
cd "$COMPOSE_DIR"
PREV_IMAGE_FILE="$COMPOSE_DIR/.previous-image"
if [ ! -f "$PREV_IMAGE_FILE" ]; then
    echo "ERROR: No previous image record found. Run nc-upgrade first."
    exit 1
fi
PREV_IMAGE=$(cat "$PREV_IMAGE_FILE")
echo "Rolling back to: $PREV_IMAGE"
docker compose exec -T -u www-data nextcloud php occ maintenance:mode --on
sed -i "s|^    image: nextcloud:.*|    image: $PREV_IMAGE|" "$COMPOSE_DIR/docker-compose.yml"
docker compose pull nextcloud 2>/dev/null || true
docker compose up -d nextcloud
docker compose --profile http restart nginx
sleep 10
docker compose exec -T -u www-data nextcloud php occ maintenance:mode --off
echo "Rollback completed"
HELPEOF

    chmod +x /usr/local/bin/nc-occ /usr/local/bin/nc-status /usr/local/bin/nc-logs /usr/local/bin/nc-restart /usr/local/bin/nc-upgrade /usr/local/bin/nc-rollback
    log "Bootstrap: helper scripts installed"
}

# ─── Reboot path: .env exists ───
if [ -f "$ENV_FILE" ]; then
    log "Bootstrap: .env exists — reusing config"

    cd "$COMPOSE_DIR"
    if [ -f "$COMPOSE_DIR/certs/fullchain.pem" ] && [ -f "$COMPOSE_DIR/certs/privkey.pem" ]; then
        docker compose --profile https up -d
    else
        docker compose --profile http up -d
    fi

    wait_for_install
    append_trusted_domains
    install_helpers
    log "Bootstrap: done"
    exit 0
fi

# ─── First boot: generate secrets ───
log "Bootstrap: first boot — generating secrets"

ALL_IPS=$(get_all_ips | tr '\n' ' ')
log "Bootstrap: detected IPs = $ALL_IPS"

POSTGRES_DB="nextcloud"
POSTGRES_USER="nextcloud"
POSTGRES_PASSWORD=$(gen_password 24)
POSTGRES_HOST="db"
REDIS_PASSWORD=$(gen_password 24)
NEXTCLOUD_ADMIN_USER="admin"
NEXTCLOUD_ADMIN_PASSWORD=$(gen_password 18)

TRUSTED_DOMAINS="$ALL_IPS localhost 127.0.0.1"

cat > "$ENV_FILE" << EOF
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_HOST=${POSTGRES_HOST}
REDIS_PASSWORD=${REDIS_PASSWORD}
NEXTCLOUD_ADMIN_USER=${NEXTCLOUD_ADMIN_USER}
NEXTCLOUD_ADMIN_PASSWORD=${NEXTCLOUD_ADMIN_PASSWORD}
NEXTCLOUD_TRUSTED_DOMAINS=${TRUSTED_DOMAINS}
EOF
chmod 600 "$ENV_FILE"

PRIMARY_IP=$(get_all_ips | head -1)

cat > "$CRED_FILE" << EOF
=== Nextcloud Docker Credentials ===
Generated: $(date)
VM IPs: ${ALL_IPS}

Nextcloud Admin:
  URL:      http://${PRIMARY_IP}
  User:     ${NEXTCLOUD_ADMIN_USER}
  Password: ${NEXTCLOUD_ADMIN_PASSWORD}

PostgreSQL Database:
  Host:     ${POSTGRES_HOST}
  Name:     ${POSTGRES_DB}
  User:     ${POSTGRES_USER}
  Password: ${POSTGRES_PASSWORD}

Redis:
  Host:     redis
  Password: ${REDIS_PASSWORD}

Config Files:
  /opt/nextcloud/nginx/default.conf       — HTTP Nginx config
  /opt/nextcloud/nginx/default-https.conf — HTTPS Nginx config

Manage:
  cd /opt/nextcloud
  docker compose ps                — check status
  docker compose logs -f           — view logs
  docker compose restart            — restart all

Helper Commands:
  nc-occ <command>                 — run occ (e.g. nc-occ user:list)
  nc-status                        — check container status
  nc-logs <service>                — view logs (e.g. nc-logs nextcloud)
  nc-restart                       — restart all services
  nc-upgrade                       — upgrade Nextcloud (saves previous version)
  nc-rollback                      — rollback to previous version

Enable HTTPS:
  1. Point DNS → VM IP
  2. Place certs: /opt/nextcloud/certs/fullchain.pem + privkey.pem
  3. chmod 644 /opt/nextcloud/certs/fullchain.pem
  4. chmod 600 /opt/nextcloud/certs/privkey.pem
  5. cd /opt/nextcloud && docker compose --profile https up -d
EOF
chmod 600 "$CRED_FILE"

log "Bootstrap: starting services"
cd "$COMPOSE_DIR"
if [ -f "$COMPOSE_DIR/certs/fullchain.pem" ] && [ -f "$COMPOSE_DIR/certs/privkey.pem" ]; then
    log "Bootstrap: HTTPS certs found — using https profile"
    docker compose --profile https up -d
else
    log "Bootstrap: using http profile"
    docker compose --profile http up -d
fi

log "Bootstrap: waiting for Nextcloud to be ready..."
wait_for_install
append_trusted_domains
configure_redis "$REDIS_PASSWORD"
configure_opcache
setup_cron
install_helpers

log "Bootstrap: done"
