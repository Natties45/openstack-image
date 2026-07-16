#!/bin/bash
# Helper script to temporarily disable authentication so the admin can log in and reset their password.
set -e

ENV_FILE="/opt/anythingllm/.env"
COMPOSE_DIR="/opt/anythingllm"
RESTORE_NEEDED="false"

restore_auth() {
  if [ "$RESTORE_NEEDED" = "true" ] && [ -f "$ENV_FILE.bak" ]; then
    echo "Restoring authentication before exit..."
    mv "$ENV_FILE.bak" "$ENV_FILE"
    cd "$COMPOSE_DIR"
    docker compose down && docker compose up -d
  fi
}

trap restore_auth EXIT INT TERM

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "=== AnythingLLM Password Reset Helper ==="
echo "This script will temporarily disable authentication to let you log in and reset your password via the UI."
echo ""

# Backup .env
cp "$ENV_FILE" "$ENV_FILE.bak"
RESTORE_NEEDED="true"

# Enable DISABLE_AUTH
if grep -q "DISABLE_AUTH" "$ENV_FILE"; then
  sed -i 's/DISABLE_AUTH=.*/DISABLE_AUTH=true/' "$ENV_FILE"
else
  echo "DISABLE_AUTH=true" >> "$ENV_FILE"
fi

echo "[1/3] Temporarily disabled authentication in .env"
cd "$COMPOSE_DIR"
docker compose down && docker compose up -d
echo "[2/3] Restarted AnythingLLM with authentication disabled"
echo ""
echo ">>> ACTION REQUIRED <<<"
echo "1. Open http://<VM-IP> in your browser."
echo "2. Go to Settings -> Security / Users."
echo "3. Reset your password or manage users."
echo ""
read -p "Once you have reset your password in the browser, press [ENTER] to re-enable security: "

# Restore .env backup
mv "$ENV_FILE.bak" "$ENV_FILE"
RESTORE_NEEDED="false"
echo "[3/3] Re-enabled authentication in .env"
docker compose down && docker compose up -d
echo "AnythingLLM is now secure again with your new password!"
