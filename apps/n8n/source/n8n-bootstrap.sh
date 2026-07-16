#!/bin/bash
set -e

WORK_DIR="/opt/n8n"
ENV_FILE="${WORK_DIR}/.env"
CREDS_FILE="/root/n8n-credentials.txt"
HTTP_CONF="${WORK_DIR}/nginx/n8n-http.conf"
HTTPS_CONF="${WORK_DIR}/nginx/n8n-https.conf"
ACTIVE_CONF="${WORK_DIR}/nginx/n8n.conf"
CERT_DIR="${WORK_DIR}/certs"
CERT_FULLCHAIN="${CERT_DIR}/fullchain.pem"
CERT_PRIVKEY="${CERT_DIR}/privkey.pem"

# ── Helper: generate alphanumeric password (playbook §5) ──
# alphanumeric-only กัน +/= พัง Redis/URI/conn string (Nextcloud bug 2026-07-08)
gen_password() {
    local len="${1:-24}"
    openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c "$len"
}

# ── Helper: collect all reachable IPs (playbook §3-4) ──
# ไม่ assume interface name — ใช้ scope global + กรอง Docker bridge
get_all_ips() {
    ip -4 addr show scope global | grep -vE 'docker[0-9]+|br-' | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | sort -u
}

# ── Helper: pick a public/routable IP if one exists ──
# Filters out RFC1918 private, link-local, loopback, and metadata/dummy ranges.
# Returns empty if no public IP is attached.
get_public_ip() {
    get_all_ips | awk -F'.' '
        $1==10 {next}
        $1==172 && $2>=16 && $2<=31 {next}
        $1==192 && $2==168 {next}
        $1==127 {next}
        $1==169 && $2==254 {next}
        $1==192 && $2==0 && $3==0 {next}
        {print}
    ' | head -1
}

# ── Helper: detect current IP (prefer public, fallback first global, fallback localhost) ──
get_current_ip() {
    local ip
    ip=$(get_public_ip)
    if [ -z "${ip}" ]; then
        ip=$(get_all_ips | head -1)
    fi
    if [ -z "${ip}" ]; then
        ip="localhost"
    fi
    echo "${ip}"
}

# ── Helper: check if certs are present ──
has_certs() {
    [ -f "${CERT_FULLCHAIN}" ] && [ -f "${CERT_PRIVKEY}" ]
}

# ── Helper: read N8N_PROTOCOL from .env ──
get_protocol() {
    grep -oP '(?<=N8N_PROTOCOL=)[^\s]+' "${ENV_FILE}" 2>/dev/null || echo "http"
}

# ── Helper: select nginx config based on .env intent + cert presence ──
# Logic (preserve user intent across reboots):
#   - .env protocol=https + certs present → HTTPS config
#   - .env protocol=https + certs missing  → fallback to HTTP + fix .env
#   - .env protocol=http (or no .env)      → HTTP config (even if certs present)
sync_nginx_conf() {
    local protocol
    protocol=$(get_protocol)

    if [ "${protocol}" = "https" ] && has_certs; then
        if [ ! -f "${ACTIVE_CONF}" ] || ! diff -q "${ACTIVE_CONF}" "${HTTPS_CONF}" >/dev/null 2>&1; then
            cp "${HTTPS_CONF}" "${ACTIVE_CONF}"
            echo "=> Activated HTTPS nginx config (port 80 redirects → 443)"
        fi
    elif [ "${protocol}" = "https" ] && ! has_certs; then
        # .env says https but certs are missing — fallback to HTTP
        echo "=> WARNING: .env says HTTPS but certs missing — falling back to HTTP"
        local fallback_ip
        fallback_ip=$(get_current_ip)
        sed -i "s|N8N_PROTOCOL=.*|N8N_PROTOCOL=http|" "${ENV_FILE}"
        sed -i "s|WEBHOOK_URL=.*|WEBHOOK_URL=http://${fallback_ip}/|" "${ENV_FILE}"
        sed -i "s|N8N_HOST=.*|N8N_HOST=${fallback_ip}|" "${ENV_FILE}"
        sed -i "s|N8N_SECURE_COOKIE=.*|N8N_SECURE_COOKIE=false|" "${ENV_FILE}"
        sed -i "s|N8N_PROXY_HOPS=.*|N8N_PROXY_HOPS=1|" "${ENV_FILE}"
        if [ ! -f "${ACTIVE_CONF}" ] || ! diff -q "${ACTIVE_CONF}" "${HTTP_CONF}" >/dev/null 2>&1; then
            cp "${HTTP_CONF}" "${ACTIVE_CONF}"
            echo "=> Activated HTTP nginx config (port 80 serves directly)"
        fi
    else
        # HTTP mode — use HTTP config even if certs are present (preserve user intent)
        if [ ! -f "${ACTIVE_CONF}" ] || ! diff -q "${ACTIVE_CONF}" "${HTTP_CONF}" >/dev/null 2>&1; then
            cp "${HTTP_CONF}" "${ACTIVE_CONF}"
            echo "=> Activated HTTP nginx config (port 80 serves directly)"
        fi
    fi
}

# ── Helper: update WEBHOOK_URL + N8N_HOST if IP changed (HTTP mode only) ──
# Idempotent: เปลี่ยนเฉพาะค่าที่ IP เปลี่ยน ไม่แตะค่าอื่น (เช่น N8N_ENCRYPTION_KEY)
# ใน HTTPS mode (N8N_PROTOCOL=https) ไม่เปลี่ยน — domain ที่ customer ตั้งไว้ถูกสงวน
# WEBHOOK_URL format ใหม่: http://IP/ (no port — nginx on port 80)
update_env_ip() {
    local new_ip="$1"
    local env_file="$2"
    local old_webhook old_host protocol

    protocol=$(grep -oP '(?<=N8N_PROTOCOL=)[^\s]+' "${env_file}" 2>/dev/null || echo "")

    if [ "${protocol}" = "https" ]; then
        echo "=> HTTPS mode detected — preserving domain in .env"
        return
    fi

    # Extract IP from WEBHOOK_URL=http://IP/ (no port in new format)
    old_webhook=$(grep -oP '(?<=WEBHOOK_URL=http://)[^/:]+' "${env_file}" 2>/dev/null || echo "")
    old_host=$(grep -oP '(?<=N8N_HOST=)[^\s]+' "${env_file}" 2>/dev/null || echo "")

    if [ "${old_webhook}" != "${new_ip}" ]; then
        sed -i "s|WEBHOOK_URL=http://[^/]*|WEBHOOK_URL=http://${new_ip}|" "${env_file}"
        sed -i "s|N8N_HOST=.*|N8N_HOST=${new_ip}|" "${env_file}"
        echo "=> Updated WEBHOOK_URL + N8N_HOST to ${new_ip}"
    fi
}

if [ ! -f "${ENV_FILE}" ]; then
  echo "=> First boot detected. Generating credentials..."
  POSTGRES_USER="n8n"
  POSTGRES_PASSWORD=$(gen_password 24)
  POSTGRES_DB="n8n"
  N8N_ENCRYPTION_KEY=$(gen_password 32)

  # Dynamic IP detection — use first reachable IP as WEBHOOK_URL (playbook §3)
  FIRST_IP=$(get_current_ip)

  # WEBHOOK_URL uses port 80 (nginx) ไม่ใช่ 5678 (direct n8n)
  # N8N_PROXY_HOPS=1 because nginx is always in front of n8n (even in HTTP mode)
  cat <<EOF > "${ENV_FILE}"
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
N8N_HOST=${FIRST_IP}
N8N_PROTOCOL=http
WEBHOOK_URL=http://${FIRST_IP}/
N8N_SECURE_COOKIE=false
N8N_PROXY_HOPS=1
EOF

  cat <<EOF > "${CREDS_FILE}"
========================================
n8n Database & Encryption Credentials
========================================
DO NOT LOSE N8N_ENCRYPTION_KEY!
If lost, you cannot decrypt stored app credentials.

N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}
Database User: ${POSTGRES_USER}
Database Password: ${POSTGRES_PASSWORD}
Database Name: ${POSTGRES_DB}
Access URL: http://${FIRST_IP}/
========================================
EOF
  chmod 600 "${CREDS_FILE}"
  chmod 600 "${ENV_FILE}"
else
  echo "=> .env exists. Checking for IP changes (playbook §1B)..."
  CURRENT_IP=$(get_current_ip)
  update_env_ip "${CURRENT_IP}" "${ENV_FILE}"
fi

# Sync nginx config based on .env intent + cert presence
sync_nginx_conf

echo "=> Starting n8n + nginx via Docker Compose..."
cd "${WORK_DIR}"
docker compose up -d

echo "=> n8n bootstrap complete."
CURRENT_PROTOCOL=$(get_protocol)
if [ "${CURRENT_PROTOCOL}" = "https" ] && has_certs; then
  echo "=> HTTPS active — port 80 redirects to 443"
else
  echo "=> Access URL: http://$(get_current_ip)/"
fi