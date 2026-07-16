#!/usr/bin/env bash
# verify-phase1-template.sh — App Cleanup Verification (Phase 1)
# ==============================================================
# One-shot verify script — deployed by AI via MCP upload, then run via
#   execute-command "bash /tmp/verify-phase1.sh {app}"
#
# Output: VERIFY:PASS  หรือ  VERIFY:FAIL <space-separated error tags>
#
# Intentionally does NOT use set -e: we want every check to run even if
# one fails, so the error summary is complete in a single round-trip.
#
# See docs/AI-PIPELINE.md → Verify Strategy for when to use this script
# vs inline && chain.
#
# Version: 2026-07-10
# ==============================================================

set -uo pipefail

APP="${1:-}"
if [ -z "$APP" ]; then
  echo "Usage: bash $0 <app-name>"
  exit 1
fi

ERR=""

# --- Phase 1 checks follow the order in docs/AI-PIPELINE.md §Phase 1 ---

# 1. Bootstrap service must still be enabled
systemctl is-enabled "${APP}-bootstrap.service" >/dev/null 2>&1 || ERR+="service "

# 2. Containers must be stopped (no running containers)
docker compose -f "/opt/${APP}/docker-compose.yml" ps --format '{{.Names}}' 2>/dev/null | grep -q . && ERR+="containers "

# 3. Docker pre-pull images must NOT have been pruned
#    Acceptable: at least 1 of the standard images still present
IMAGES_OK=0
for PATTERN in "$APP" "postgres" "mariadb" "redis" "nginx" "mysql" "traefik" "portainer"; do
  docker images --format '{{.Repository}}' 2>/dev/null | grep -qiE "$PATTERN" && IMAGES_OK=1
done
[ "$IMAGES_OK" -eq 1 ] || ERR+="noimages "

# 4. No .env file left behind
[ ! -f "/opt/${APP}/.env" ] || ERR+="dotenv "

# 5. No credentials file left behind
[ ! -f "/root/${APP}-credentials.txt" ] || ERR+="creds "

# 6. No bootstrap log from test run
[ ! -f "/var/log/${APP}-bootstrap.log" ] || ERR+="blog "

# 7. No runtime app data in /var/lib/{app}
find "/var/lib/${APP}" -mindepth 1 -print -quit 2>/dev/null | grep -q . && ERR+="data "

# 8. No Docker volumes associated with this app
docker volume ls --format '{{.Name}}' 2>/dev/null | grep -qi "$APP" && ERR+="volumes "

# 9. Only expected static files remain in /opt/{app}
#    This is optional-hard: log unusual files but don't fail pipeline.
BAD_FILES=$(find "/opt/${APP}" -type f ! -name "docker-compose.yml" ! -name "docker-compose*.yml" ! -name "bootstrap.sh" ! -name "*.service" ! -name "image.conf" ! -name "README*" ! -name "MOTD*" ! -name "*.conf" -not -path "*/nginx/*" 2>/dev/null)
if [ -n "$BAD_FILES" ]; then
  # log warning but do NOT add to ERR — app-specific exceptions expected
  echo "WARN:unexpected files in /opt/${APP}: $(echo "$BAD_FILES" | tr '\n' ' ')"
fi

# --- Result ---
if [ -n "$ERR" ]; then
  echo "VERIFY:FAIL $ERR"
  exit 1
else
  echo "VERIFY:PASS"
  exit 0
fi
