#!/usr/bin/env bash
# opencode-bootstrap.sh — First-boot script for OpenCode AI Coding Agent golden image
# Creates random password, environment file, starts opencode service
set -euo pipefail

LOG="/var/log/opencode-bootstrap.log"
exec > >(tee -a "$LOG") 2>&1

echo "[opencode-bootstrap] $(date -u +'%Y-%m-%dT%H:%M:%SZ')"

# ── Generate random password (16 chars alphanumeric) ──
OP_PASSWORD=$(openssl rand -base64 18 | tr -d '+/=' | head -c 16)

# ── Create environment file ──
mkdir -p /etc/opencode
cat > /etc/opencode/environment << ENVEOF
OPENCODE_SERVER_USERNAME=opencode
OPENCODE_SERVER_PASSWORD=${OP_PASSWORD}
ENVEOF
chmod 600 /etc/opencode/environment

# ── Ensure runtime directories for opencode user ──
mkdir -p /home/opencode/.local/share/opencode
mkdir -p /home/opencode/.cache/opencode
chown -R opencode:opencode /home/opencode/.local /home/opencode/.cache /home/opencode/.config

# ── Start opencode service ──
systemctl daemon-reload
systemctl enable --now opencode.service

# ── Mark bootstrapped ──
touch /etc/opencode/.bootstrapped

echo "[opencode-bootstrap] Done. Web UI: http://localhost:4096"
