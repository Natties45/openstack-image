#!/bin/bash
set -e

COMPOSE_DIR="/opt/woocommerce"
LOG_FILE="/var/log/woocommerce-cron.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

cd "$COMPOSE_DIR"

if [ ! -f .env ]; then
    log "skip: .env not found"
    exit 0
fi

if ! docker compose ps --status running wordpress >/dev/null 2>&1; then
    log "skip: wordpress container is not running"
    exit 0
fi

log "run: wp cron event run --due-now"
docker compose --profile tools run --rm cli cron event run --due-now || true

if docker compose --profile tools run --rm cli help action-scheduler >/dev/null 2>&1; then
    log "run: wp action-scheduler run"
    docker compose --profile tools run --rm cli action-scheduler run --batch-size=25 || true
fi
