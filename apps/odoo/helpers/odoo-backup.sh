#!/bin/bash
set -euo pipefail

COMPOSE_DIR="/opt/odoo"
BACKUP_DIR="/opt/odoo/backups"
ENV_FILE="/opt/odoo/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: missing $ENV_FILE" >&2
    exit 1
fi

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

cd "$COMPOSE_DIR"
set -a
. "$ENV_FILE"
set +a

TS=$(date +%Y%m%d-%H%M%S)
DB_OUT="$BACKUP_DIR/odoo-${POSTGRES_DB}-${TS}.sql.gz"
DATA_OUT="$BACKUP_DIR/odoo-filestore-${TS}.tar.gz"

docker compose exec -T db pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > "$DB_OUT"
docker run --rm -v odoo_odoo_data:/data:ro -v "$BACKUP_DIR:/backup" alpine:3.20 \
    tar -czf "/backup/$(basename "$DATA_OUT")" -C /data .

chmod 600 "$DB_OUT" "$DATA_OUT"
echo "Backup created:"
echo "  $DB_OUT"
echo "  $DATA_OUT"
