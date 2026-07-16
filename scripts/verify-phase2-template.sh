#!/usr/bin/env bash
# verify-phase2-template.sh — OS / Golden-Image Cleanup Verification (Phase 2)
# =============================================================================
# One-shot verify script — deployed by AI via MCP upload, then run via
#   execute-command "bash /tmp/verify-phase2.sh"
#
# Run BEFORE the final authorized_keys removal (that step destroys SSH).
#
# Output: VERIFY:PASS  หรือ  VERIFY:FAIL <space-separated error tags>
#
# Intentionally does NOT use set -e — every check must run for a complete
# error summary in one round-trip.
#
# See docs/AI-PIPELINE.md → Verify Strategy.
#
# Version: 2026-07-10
# =============================================================================

set -uo pipefail

ERR=""

# --- Phase 2 checks follow docs/AI-PIPELINE.md §Phase 2 order ---

# 1. No bash history files
[ ! -f /root/.bash_history ] || ERR+="hist "
for HF in /home/*/.bash_history; do
  [ -f "$HF" ] && ERR+="hist "
done

# 2. /tmp and /var/tmp must be empty
find /tmp /var/tmp -mindepth 1 -print -quit 2>/dev/null | grep -q . && ERR+="tmp "

# 3. All .log files truncated
find /var/log -type f -name '*.log' -size +0 -print -quit 2>/dev/null | grep -q . && ERR+="logs "

# 4. wtmp / btmp / lastlog must be size 0
for F in /var/log/wtmp /var/log/btmp /var/log/lastlog; do
  [ "$(stat -c%s "$F" 2>/dev/null || echo 1)" = "0" ] || ERR+="$(basename "$F") "
done

# 5. cloud-init cleaned
find /var/lib/cloud/instances -mindepth 1 -print -quit 2>/dev/null | grep -q . && ERR+="cloud "

# 6. netplan removed (Ubuntu/Debian)
[ ! -f /etc/netplan/50-cloud-init.yaml ] || ERR+="netplan "

# 7. machine-id truncated
[ ! -s /etc/machine-id ] || ERR+="mid "
# Verify dbus symlink exists on Debian/Ubuntu (non-fatal if absent on RPM)
if [ -f /var/lib/dbus/machine-id ] && [ ! -L /var/lib/dbus/machine-id ]; then
  ERR+="dbuslink "
fi

# 8. SSH host keys removed
ls /etc/ssh/ssh_host_* >/dev/null 2>&1 && ERR+="hostkeys "

# 9. sshd_config.d only has 00-image-build.conf (or empty)
for F in /etc/ssh/sshd_config.d/*.conf; do
  [ -f "$F" ] || continue
  [ "$(basename "$F")" = "00-image-build.conf" ] || ERR+="sshdconf "
done

# 10. Repo backup removed
[ ! -e /var/backups/image-build/repos ] || ERR+="repos "

# 11. authorized_keys still present? (if run BEFORE final removal)
#     NOTE: this is expected to warn. The FINAL removal happens after this verify.
[ -f /root/.ssh/authorized_keys ] && [ -s /root/.ssh/authorized_keys ] && echo "NOTE: authorized_keys still present (will be removed after verify)"

# --- Result ---
if [ -n "$ERR" ]; then
  echo "VERIFY:FAIL $ERR"
  exit 1
else
  echo "VERIFY:PASS"
  exit 0
fi
