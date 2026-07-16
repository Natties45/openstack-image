=========================================================================
Grafana + Prometheus — File Structure Reference
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
