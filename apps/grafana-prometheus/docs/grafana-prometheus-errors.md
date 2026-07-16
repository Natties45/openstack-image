# Grafana+Prometheus — AI Mistakes Log

> บันทึกคำสั่งที่ AI ให้แล้วพังระหว่าง build image นี้

## 2026-06-15 Build VM

| Date | Phase | Failed command | Error | Root cause | Fix |
|---|---|---|---|---|---|
| 2026-06-15 | Local SSH helper | `python -m pip install --user paramiko` | `Microsoft Visual C++ 14.0 or greater is required` while building `cffi` for Python 3.15 | Local Python 3.15 alpha had no compatible wheel for dependency chain | Used temporary Node `ssh2` helper instead; no credential written to repo |
| 2026-06-15 | Validate configs | `docker run --rm -v /opt/monitoring/prometheus:/etc/prometheus:ro prom/prometheus:latest promtool check config /etc/prometheus/prometheus.yml` | `prometheus: error: unexpected promtool` | `prom/prometheus:latest` image entrypoint is `prometheus`, so `promtool` was passed as an argument | Use `docker run --rm --entrypoint promtool ... check config ...` |
| 2026-06-15 | Pull images | `docker compose -f /opt/monitoring/docker-compose.yml pull` | Docker Hub/CloudFront `TLS handshake timeout` | Transient network pull timeout | Retry pulls per service; images pulled successfully |
| 2026-06-15 | Bootstrap | `/usr/local/sbin/grafana-prometheus-bootstrap.sh` | `env: $'bash\r': No such file or directory` | Scripts uploaded from Windows had CRLF line endings | Run `sed -i 's/\r$//'` on executable scripts after copy; added to guide |
| 2026-06-15 | Smoke test | `curl -fsS http://127.0.0.1:9093/-/healthy` | Alertmanager restart loop; logs showed `open /etc/alertmanager/alertmanager.yml: permission denied` | Guide set config file permission to `600`, but Alertmanager container does not read it as root | Change permission to `644`; Alertmanager became healthy |
| 2026-06-15 | Post-test coverage | Console login / MOTD path was not tested | User saw `run-parts: failed to exec /etc/update-motd.d/99-grafana-prometheus-image: No such file or directory` on console login | Post-check missed `/etc/update-motd.d` execution and CRLF/shebang validation; file can exist but fail if shebang has CRLF | Added MOTD/run-parts/shebang checks to post-check; verify with `run-parts /etc/update-motd.d` and `head -1 ... \| od -An -tx1` |

---

## 2026-07-13 IP Change Test — Bootstrap IP Detection

| Date | Phase | Failed command | Error | Root cause | Fix |
|---|---|---|---|---|---|
| 2026-07-13 | IP change test | `get_primary_ip()` uses `hostname -I \| awk '{print $1}'` | Detected private IP (10.10.20.149) instead of public IP (203.154.16.44) on multi-NIC VM. GRAFANA_ROOT_URL, INFO file, and MOTD all showed wrong IP. | `hostname -I` returns all IPs in arbitrary order; `awk '{print $1}'` chose the first (private) interface. VM has ens3 (private 10.10.20.x) and ens4 (public 203.154.16.x). | Changed all 3 files (bootstrap.sh, MOTD, monitoring-reset-grafana-password) to use `ip -4 route get 1 \| sed` to detect default-route source IP (public), with `hostname -I` fallback. |
| 2026-07-13 | IP change test | `monitoring-reset-grafana-password` INFO content | Script writes INFO file in **Thai** (Customer Service 9 requires English-only for user-facing files). Overwrites English INFO from bootstrap on password reset. | Script was created before English-only requirement was enforced. Also had old `hostname -I` IP detection. | Replaced Thai INFO content with English version matching bootstrap.sh `write_info_file()`. Fixed IP detection. |

---

## 2026-07-13 Cleanup — Healthcheck Bugs (Pre-existing)

| Date | Phase | Failed command | Error | Root cause | Fix |
|---|---|---|---|---|---|
| 2026-07-13 | healthcheck | `healthcheck: test: ["CMD-SHELL", "wget -q http://localhost:80/..."]` | `wget: can't connect to remote host: Connection refused` — nginx consistently unhealthy | `localhost` resolves to `::1` (IPv6) in Alpine's Busybox wget, but nginx listens only on `0.0.0.0:80` (IPv4). `localhost` has both `127.0.0.1` and `::1` in `/etc/hosts`, and Busybox wget prefers IPv6. | Changed to `http://127.0.0.1:80/` — forces IPv4 connection. Nginx healthcheck passed immediately after fix. |
| 2026-07-13 | healthcheck | `healthcheck: test: ["CMD-SHELL", "wget -q http://localhost:9115/health..."]` | `OCI runtime exec failed: exec: "/bin/sh": stat /bin/sh: no such file or directory` | `prom/blackbox-exporter:master-distroless` has no `/bin/sh`, no shell, no binaries at all. `CMD-SHELL` tries to run `/bin/sh -c wget...` which fails. | Changed to `disable: true` — distroless image has no shell/tools for healthcheck. Auto-restart via `restart: unless-stopped` is sufficient. |

---

## Template

| Date | Phase | Failed command | Error | Root cause | Fix |
|---|---|---|---|---|---|
| — | — | — | — | — | — |
