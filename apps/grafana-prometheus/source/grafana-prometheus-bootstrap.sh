#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/opt/monitoring
ENV_FILE="$APP_DIR/.env"
INFO_FILE=/root/README-grafana-prometheus-image.txt
LOG=/var/log/grafana-prometheus-bootstrap.log
MARKER=/var/lib/grafana-prometheus-firstboot.done

exec > >(tee -a "$LOG") 2>&1

random_secret() {
  openssl rand -base64 32 | tr -d '=+/' | cut -c1-32
}

get_primary_ip() {
  # ใช้ default route source IP (public IP) — fallback ถ้าไม่มี route
  ip -4 route get 1 2>/dev/null | sed -n 's/.*src \([0-9.]*\).*/\1/p' || \
    hostname -I 2>/dev/null | awk '{print $1}'
}

read_env_password() {
  if [ ! -f "$ENV_FILE" ]; then
    return 1
  fi
  awk -F= '$1 == "GRAFANA_ADMIN_PASSWORD" {sub(/^[^=]*=/, ""); print; exit}' "$ENV_FILE"
}

wait_http() {
  local url="$1"
  local name="$2"
  local tries=60
  local i=1
  while [ "$i" -le "$tries" ]; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "$name is ready"
      return 0
    fi
    sleep 3
    i=$((i + 1))
  done
  echo "WARNING: $name did not become ready in time"
  return 1
}

write_info_file() {
  local vm_ip="$1"
  local password="$2"
  cat > "$INFO_FILE" << EOF
Grafana+Prometheus Monitoring Image
====================================

Grafana URL:
  http://${vm_ip:-<VM-IP>}/

Login:
  Username: admin
  Password: $password
EOF
  cat >> "$INFO_FILE" << 'HEREDOC'

=========================================================================
File Structure Reference
=========================================================================

[Main Directory]
  /opt/monitoring/
      Root directory — all monitoring files are located here

[Configuration — Editable]
  /opt/monitoring/docker-compose.yml
      Docker containers: ports, volumes, restart policy

  /opt/monitoring/nginx/default.conf
      Nginx reverse proxy config — edit to add TLS/HTTPS or routes

  /opt/monitoring/nginx/default.conf.template
      HTTPS template — ready for SSL certificate setup

  /opt/monitoring/prometheus/prometheus.yml
      Prometheus config: scrape interval, retention, global settings

  /opt/monitoring/prometheus/rules/alerts.yml
      Alert rules: thresholds for CPU, memory, disk, etc.

  /opt/monitoring/alertmanager/alertmanager.yml
      Alert routing: email, LINE, Slack, webhook

  /opt/monitoring/blackbox/blackbox.yml
      Blackbox exporter config: HTTP, TCP, ICMP probe settings

  /opt/monitoring/grafana/provisioning/
      Auto-provisioning: datasource and dashboard setup

[Target Files — Managed by helper commands]
  /opt/monitoring/prometheus/targets/nodes.yml
      Linux VMs monitored via node_exporter

  /opt/monitoring/prometheus/targets/http.yml
      URLs monitored via HTTP/HTTPS

  /opt/monitoring/prometheus/targets/tcp.yml
      TCP ports monitored

  /opt/monitoring/prometheus/targets/ping.yml
      IPs monitored via ICMP ping

  /opt/monitoring/prometheus/targets/cadvisor.yml
      Container metrics (optional — requires cadvisor profile)

[Dashboards]
  /opt/monitoring/grafana/dashboards/
      Place dashboard JSON files here — Grafana loads them automatically

[Runtime — System-generated, do not modify]

  /opt/monitoring/.env
      Stores passwords and secrets (generated on first boot)

  /root/README-grafana-prometheus-image.txt
      This file

  /var/lib/grafana-prometheus-firstboot.done
      Marker — indicates first boot has completed

[Docker Volumes — Do not delete]

  grafana_data
      Grafana settings, dashboards, users

  prometheus_data
      Historical metrics data

  alertmanager_data
      Alert state and silences

[View Logs]

  docker logs grafana
  docker logs prometheus
  docker logs alertmanager
  docker logs node-exporter
  docker logs blackbox-exporter
  docker logs monitoring-nginx

[Helper Scripts]

  /usr/local/sbin/monitoring-*
      All monitoring helper commands (monitoring-info, monitoring-add-*, etc.)

  /usr/local/sbin/grafana-prometheus-bootstrap.sh
      First boot initialization script

  /etc/systemd/system/grafana-prometheus-bootstrap.service
      systemd service — controls first boot flow

  /etc/update-motd.d/99-grafana-prometheus-image
      MOTD — message shown on SSH login

=========================================================================
HEREDOC
  chmod 600 "$INFO_FILE"
}

echo "[$(date -Is)] Grafana+Prometheus bootstrap started"

if [ -e "$MARKER" ]; then
  echo "Bootstrap already completed; ensuring monitoring services are running"
  systemctl enable --now docker
  docker compose -f "$APP_DIR/docker-compose.yml" --env-file "$ENV_FILE" up -d
  # Re-create helper symlinks (golden rule #6 — idempotent)
  for cmd in /usr/local/sbin/monitoring-*; do
    if [ -x "$cmd" ]; then
      ln -sf "$cmd" "/usr/local/bin/$(basename "$cmd")"
    fi
  done
  if [ ! -s "$INFO_FILE" ] || ! grep -q '^  Password: ' "$INFO_FILE"; then
    EXISTING_GRAFANA_ADMIN_PASSWORD="$(read_env_password || true)"
    if [ -n "$EXISTING_GRAFANA_ADMIN_PASSWORD" ]; then
      write_info_file "$(get_primary_ip)" "$EXISTING_GRAFANA_ADMIN_PASSWORD"
      echo "Info file repaired at $INFO_FILE"
    else
      echo "WARNING: cannot repair $INFO_FILE because $ENV_FILE has no GRAFANA_ADMIN_PASSWORD"
    fi
  fi
  exit 0
fi

mkdir -p "$APP_DIR" /var/lib
chmod 755 "$APP_DIR"

GRAFANA_ADMIN_PASSWORD="$(random_secret)"
GRAFANA_SECRET_KEY="$(random_secret)$(random_secret)"
VM_IP="$(get_primary_ip)"

cat > "$ENV_FILE" << EOF
TZ=Asia/Bangkok
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD
GRAFANA_SECRET_KEY=$GRAFANA_SECRET_KEY
GRAFANA_ROOT_URL=http://${VM_IP:-localhost}/
PROMETHEUS_RETENTION_TIME=30d
PROMETHEUS_RETENTION_SIZE=8GB
EOF
chmod 600 "$ENV_FILE"

systemctl enable --now docker
docker compose -f "$APP_DIR/docker-compose.yml" --env-file "$ENV_FILE" up -d

wait_http "http://127.0.0.1/" "Grafana via Nginx"
write_info_file "$VM_IP" "$GRAFANA_ADMIN_PASSWORD"

# สร้าง symlink จาก /usr/local/sbin/monitoring-* → /usr/local/bin/ (golden rule #6)
# helper commands ต้อง accessible จาก /usr/local/bin/ สำหรับ PATH ทั่วไป
for cmd in /usr/local/sbin/monitoring-*; do
  if [ -x "$cmd" ]; then
    ln -sf "$cmd" "/usr/local/bin/$(basename "$cmd")"
  fi
done

touch "$MARKER"
echo "Info written to $INFO_FILE"
echo "[$(date -Is)] Grafana+Prometheus bootstrap completed"
