#!/bin/bash
set -e

ENV_FILE="/opt/woocommerce/.env"
CRED_FILE="/root/woocommerce-credentials.txt"
LOG_FILE="/var/log/woocommerce-bootstrap.log"
COMPOSE_DIR="/opt/woocommerce"
SITE_TITLE="WooCommerce Store"
ADMIN_USER="storeadmin"
ADMIN_EMAIL="admin@localhost.invalid"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

primary_url() {
    local ip
    ip=$(hostname -I | awk '{print $1}')
    if [ -z "$ip" ]; then
        echo "http://localhost"
    else
        echo "http://${ip}"
    fi
}

run_wp() {
    cd "$COMPOSE_DIR"
    docker compose --profile tools run --rm cli "$@"
}

if [ -f "$ENV_FILE" ]; then
    log "Bootstrap: .env exists - starting services"
    cd "$COMPOSE_DIR"
    docker compose up -d
    systemctl enable --now woocommerce-cron.timer >/dev/null 2>&1 || true
    log "Bootstrap: done (reusing existing config)"
    exit 0
fi

log "Bootstrap: first boot - generating secrets"

MYSQL_ROOT_PASSWORD=$(openssl rand -base64 24)
MYSQL_DATABASE="wordpress"
MYSQL_USER="wordpress"
MYSQL_PASSWORD=$(openssl rand -base64 24)
WP_ADMIN_PASSWORD=$(openssl rand -base64 24)
SITE_URL=$(primary_url)

cat > "$ENV_FILE" << EOF
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=${MYSQL_DATABASE}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
SITE_URL=${SITE_URL}
EOF
chmod 600 "$ENV_FILE"

log "Bootstrap: pulling images"
cd "$COMPOSE_DIR"
docker compose --profile tools pull

log "Bootstrap: starting database, wordpress, nginx"
docker compose up -d db wordpress nginx

log "Bootstrap: waiting for WordPress PHP-FPM"
for i in $(seq 1 60); do
    if docker compose exec -T wordpress php -r "echo 'ok';" 2>/dev/null | grep -q ok; then
        log "Bootstrap: WordPress PHP-FPM is ready"
        break
    fi
    sleep 2
done

log "Bootstrap: installing WordPress core"
if ! run_wp core is-installed >/dev/null 2>&1; then
    run_wp core install \
        --url="$SITE_URL" \
        --title="$SITE_TITLE" \
        --admin_user="$ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$ADMIN_EMAIL" \
        --skip-email
fi

log "Bootstrap: installing WooCommerce"
run_wp plugin install woocommerce --activate
run_wp rewrite structure '/%postname%/' --hard
run_wp option update blogdescription 'Online store powered by WooCommerce'

cat > "$CRED_FILE" << EOF
=== WooCommerce Docker Credentials ===
Generated: $(date)

Access:
  Store URL: ${SITE_URL}
  Admin URL: ${SITE_URL}/wp-admin/

WordPress Admin:
  User:     ${ADMIN_USER}
  Password: ${WP_ADMIN_PASSWORD}
  Email:    ${ADMIN_EMAIL}

Database:
  Host:     db (internal Docker network)
  Name:     ${MYSQL_DATABASE}
  User:     ${MYSQL_USER}
  Password: ${MYSQL_PASSWORD}

Root DB Password: ${MYSQL_ROOT_PASSWORD}

First Steps:
  1. Open Admin URL and log in
  2. Complete WooCommerce setup wizard
  3. Change admin email and password
  4. Configure HTTPS before enabling real payments
  5. Configure SMTP for order emails

Manage:
  cd /opt/woocommerce
  docker compose ps
  docker compose logs -f
  docker compose restart

Cron/Queue:
  systemctl status woocommerce-cron.timer --no-pager
  /usr/local/sbin/woocommerce-cron.sh
EOF
chmod 600 "$CRED_FILE"

systemctl enable --now woocommerce-cron.timer >/dev/null 2>&1 || true

log "Bootstrap: done - open ${SITE_URL}/wp-admin/ and complete WooCommerce setup"
