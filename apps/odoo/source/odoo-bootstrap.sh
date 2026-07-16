#!/bin/bash
set -euo pipefail

ENV_FILE="/opt/odoo/.env"
CRED_FILE="/root/odoo-credentials.txt"
LOG_FILE="/var/log/odoo-bootstrap.log"
COMPOSE_DIR="/opt/odoo"
CONF_FILE="/opt/odoo/config/odoo.conf"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

wait_for_http() {
    for _ in $(seq 1 90); do
        if curl -fsS http://127.0.0.1/web/login >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    return 1
}

if [ -f "$ENV_FILE" ]; then
    log "Bootstrap: .env exists — starting services"
    cd "$COMPOSE_DIR"
    docker compose up -d
    log "Bootstrap: done (reusing existing config)"
    exit 0
fi

log "Bootstrap: first boot — generating secrets"

POSTGRES_DB="odoo_prod"
POSTGRES_USER="odoo"
POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')
ODOO_MASTER_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
ODOO_ADMIN_LOGIN="admin"
ODOO_ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')

install -d -m 700 /opt/odoo/config /opt/odoo/addons /opt/odoo/backups /opt/odoo/certs

cat > "$ENV_FILE" << EOF
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
ODOO_MASTER_PASSWORD=${ODOO_MASTER_PASSWORD}
ODOO_ADMIN_LOGIN=${ODOO_ADMIN_LOGIN}
ODOO_ADMIN_PASSWORD=${ODOO_ADMIN_PASSWORD}
EOF
chmod 600 "$ENV_FILE"

cat > "$CONF_FILE" << EOF
[options]
admin_passwd = ${ODOO_MASTER_PASSWORD}
db_host = db
db_port = 5432
db_user = ${POSTGRES_USER}
db_password = ${POSTGRES_PASSWORD}
db_name = ${POSTGRES_DB}
dbfilter = ^${POSTGRES_DB}$
list_db = False
proxy_mode = True
without_demo = all
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons
data_dir = /var/lib/odoo
workers = 1
max_cron_threads = 1
gevent_port = 8072
limit_memory_soft = 1073741824
limit_memory_hard = 1610612736
limit_time_cpu = 600
limit_time_real = 1200
EOF
chmod 640 "$CONF_FILE"

/usr/local/sbin/odoo-tune-workers.sh "$CONF_FILE" | tee -a "$LOG_FILE"

cat > "$CRED_FILE" << EOF
=== Odoo Docker Credentials ===
Generated: $(date)

Web:
  URL: http://<VM-IP>/
  HTTPS cert path: /opt/odoo/certs/fullchain.pem + /opt/odoo/certs/privkey.pem

Odoo:
  Database: ${POSTGRES_DB}
  Admin login: ${ODOO_ADMIN_LOGIN}
  Admin password: ${ODOO_ADMIN_PASSWORD}
  Master password: ${ODOO_MASTER_PASSWORD}

PostgreSQL:
  Host: db (internal Docker network)
  Database: ${POSTGRES_DB}
  User: ${POSTGRES_USER}
  Password: ${POSTGRES_PASSWORD}

Manage:
  cd /opt/odoo
  docker compose ps
  docker compose logs -f
  docker compose restart

Backup:
  /usr/local/sbin/odoo-backup.sh

Security:
  Change the Odoo admin password after first login.
EOF
chmod 600 "$CRED_FILE"

cd "$COMPOSE_DIR"
log "Bootstrap: pulling images"
docker compose pull

log "Bootstrap: starting database"
docker compose up -d db
for _ in $(seq 1 60); do
    if docker compose exec -T db pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
        log "Bootstrap: PostgreSQL is ready"
        break
    fi
    sleep 2
done

log "Bootstrap: initializing Odoo database ${POSTGRES_DB} without demo data"
docker compose run --rm odoo odoo -d "$POSTGRES_DB" -i base --without-demo=all --stop-after-init

log "Bootstrap: setting initial admin password"
docker compose run --rm odoo odoo shell -d "$POSTGRES_DB" << EOF
admin = env.ref('base.user_admin')
admin.write({'login': '${ODOO_ADMIN_LOGIN}', 'password': '${ODOO_ADMIN_PASSWORD}'})
env.cr.commit()
EOF

log "Bootstrap: starting Odoo + Nginx"
docker compose up -d

if wait_for_http; then
    log "Bootstrap: Odoo is ready — open http://<VM-IP>/"
else
    log "Bootstrap: WARNING Odoo web did not become ready within timeout"
fi
