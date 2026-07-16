#!/bin/bash
set -euo pipefail

CONF_FILE="${1:-/opt/odoo/config/odoo.conf}"

CPU_COUNT=$(nproc)
RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)

if [ "$RAM_MB" -lt 3000 ]; then
    WORKERS=1
    MODE="small"
elif [ "$RAM_MB" -lt 5000 ]; then
    WORKERS=2
    MODE="light"
else
    CPU_WORKERS=$((CPU_COUNT * 2 + 1))
    RAM_WORKERS=$(((RAM_MB - 1024) / 768))
    if [ "$RAM_WORKERS" -lt 2 ]; then
        RAM_WORKERS=2
    fi
    if [ "$CPU_WORKERS" -lt "$RAM_WORKERS" ]; then
        WORKERS=$CPU_WORKERS
    else
        WORKERS=$RAM_WORKERS
    fi
    MODE="normal"
fi

if [ ! -f "$CONF_FILE" ]; then
    echo "ERROR: config not found: $CONF_FILE" >&2
    exit 1
fi

sed -i "s/^workers = .*/workers = ${WORKERS}/" "$CONF_FILE"
sed -i "s/^max_cron_threads = .*/max_cron_threads = 1/" "$CONF_FILE"

cat > /opt/odoo/worker-sizing.txt << EOF
Mode: ${MODE}
Detected CPU: ${CPU_COUNT}
Detected RAM MB: ${RAM_MB}
Configured workers: ${WORKERS}
Generated: $(date -Is)
EOF

echo "Configured Odoo workers=${WORKERS} mode=${MODE} cpu=${CPU_COUNT} ram_mb=${RAM_MB}"
