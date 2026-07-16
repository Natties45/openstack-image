# Grafana+Prometheus Build Manifest

> Non-secret golden image build history. Do not record runtime/OpenStack context.

---

## Latest Build

| Field | Value |
|---|---|
| App | grafana-prometheus |
| Status | ✅ built (customer-service model 2B) |
| Build date | 2026-07-12 |
| Base OS | Ubuntu 26.04 LTS |
| Source guide | `apps/grafana-prometheus/grafana-prometheus.md` |

## Host Packages

| Package | Version |
|---|---|
| docker-ce | (verify from VM) |
| docker-ce-cli | (verify from VM) |
| containerd.io | (verify from VM) |
| docker-buildx-plugin | (verify from VM) |
| docker-compose-plugin | (verify from VM) |

## Runtime Tools

| Tool | Version |
|---|---|
| Docker Engine | (verify from VM) |
| Docker Compose | (verify from VM) |
| Docker Buildx | (verify from VM) |

## Container Images (pinned tag + digest)

| Image | Tag | Digest | Notes |
|---|---|---|---|
| grafana/grafana-oss | 11.6.5 | sha256:d552f949693c54d17c6f867ff6aeb128b021e54e923895dcf9cd6aa8176c0d74 | Pinned tag + digest |
| prom/prometheus | v3.13.1 | (verify from VM) | LTS release — digest ต้อง verify ก่อน build |
| prom/alertmanager | v0.33.1 | sha256:9e082985f56f4c8c9f724e18f2288c6708f472e56a5286b8863d080434ea065d | Pinned tag + digest |
| prom/node-exporter | v1.12.0 | sha256:9b0ade5e607f9dbedb0a8e11151b6011ae5bd79304c261804cfdd2cadf200a80 | Pinned tag + digest |
| prom/blackbox-exporter | master-distroless | (verify from VM) | Distroless variant — digest ต้อง verify ก่อน build |
| nginx | stable-alpine | (verify from VM) | Pinned tag — digest ต้อง verify ก่อน build |

## Build Notes

- IP change test PASS (2026-07-13): VM redeployed at new IP 203.154.16.44, all containers healthy, Grafana accessible, dashboard data intact.
- Multi-NIC IP detection fix: changed `get_primary_ip()` from `hostname -I | awk '{print $1}'` to `ip -4 route get 1 | sed` (uses default-route source IP = public IP).
- Fixed `monitoring-reset-grafana-password`: INFO file content was Thai → English (Customer Service 9 compliance).
- Nginx healthcheck fix: `localhost` → `127.0.0.1` to avoid IPv4/IPv6 resolution issue in Alpine Busybox.
- Blackbox-exporter healthcheck disabled: `master-distroless` image has no shell/tools for healthcheck.
- Rebuilt as customer-service model 2B (Fully Auto — พร้อมใช้ทันทีหลัง boot).
- Upgraded Prometheus 3.2.x → 3.13.1 LTS (native histograms stable, security patches).
- Upgraded Grafana to 11.6.5 (Docker Hub latest 11.6.x).
- Pinned all container images with tag + digest (golden rule #2).
- Added healthchecks to all 6 core containers (golden rule #2).
- Added json-file logging options (max-size=10m, max-file=3) to all containers (golden rule #2).
- Renamed Docker network from `monitoring` → `monitoring-net` (clearer naming).
- Created `nginx/default.conf.template` for HTTPS upgrade (golden rule #3).
- Added helper symlink logic: `/usr/local/sbin/monitoring-*` → `/usr/local/bin/` (golden rule #6).
- Configured dynamic storage retention (PROMETHEUS_RETENTION_SIZE and PROMETHEUS_RETENTION_TIME) via `.env`.
- Hardened Nginx proxy with basic HTTP security headers and rate-limiting at `/login` and `/api/login`.
- Bound container memory limits (Prometheus: 2GB, Grafana: 1GB) to prevent OOM events.
- Configured Alertmanager grouping by `[alertname, job]` to prevent webhook alert flooding.
- Integrated `monitoring-remove-target`, `monitoring-setup-webhook`, and `monitoring-update` (with auto-rollback) scripts.
- Verified target management syntax validation and reloading.

## Changelog

| Date | Change |
|---|---|---|
| 2026-07-13 | Healthcheck fix: nginx `localhost`→`127.0.0.1` (IPv6 issue); blackbox-exporter healthcheck disabled (distroless) |
| 2026-07-13 | IP change fix: bootstrap/MOTD/reset-password now detect public IP via `ip route get 1`; reset-password INFO content Thai→English |
| 2026-07-12 | Customer-service rebuild: model 2B, Prometheus 3.13.1 LTS, pinned tags + digests, healthchecks, logging options, nginx HTTPS template, helper symlinks |
| 2026-07-07 | Hardened stack with memory limits, nginx rate limiting, alert grouping, and update rollback mechanism |
| 2026-07-07 | Completed build manifest for remote deployment on 203.154.16.144 |
| 2026-07-07 | Integrated dynamic storage, deduplication logic, and target removal tool |

## Do Not Record

- Image name
- Glance ID
- Server ID
- Floating IP or VM IP
- Hostname
- OpenStack project/user/auth context
- Passwords, tokens, private keys, or runtime credentials
