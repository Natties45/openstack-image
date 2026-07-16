# Nextcloud Build Manifest

> Non-secret golden image build history. Do not record runtime/OpenStack context.

---

## Latest Build

| Field | Value |
|---|---|
| App | nextcloud |
| Status | ✅ built |
| Build date | 2026-07-09 |
| Base OS | Ubuntu 26.04 LTS |
| Source guide | `apps/nextcloud/nextcloud.md` |

## Host Packages

| Package | Version |
|---|---|
| docker-ce | 5:29.6.1-1~ubuntu.26.04~resolute |
| docker-ce-cli | 5:29.6.1-1~ubuntu.26.04~resolute |
| containerd.io | 2.2.5-1~ubuntu.26.04~resolute |
| docker-buildx-plugin | 0.35.0-1~ubuntu.26.04~resolute |
| docker-compose-plugin | 5.3.1-1~ubuntu.26.04~resolute |

## Runtime Tools

| Tool | Version |
|---|---|
| Docker Engine | 29.6.1 |
| Docker Compose | v5.3.1 |
| Docker Buildx | 0.35.0 |

## Container Images

| Image | Digest |
|---|---|
| nextcloud:30.0-apache | sha256:fb966733647ea03f0446b0c22eac9733c8eb616d37b960caca9d4c3010e14a08 |
| postgres:16.9 | sha256:ddfe3e8713e3ee5b8f286082cb12512488dfbf3f5a1ecb0b74a42e6055af0a5f |
| redis:7.4-alpine | sha256:6ab0b6e7381779332f97b8ca76193e45b0756f38d4c0dcda72dbb3c32061ab99 |
| nginx:1.27-alpine | sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10 |

## Build Notes

- Redis password alphanumeric-only (gen_password) — no `+`, `/`, `=` to break Redis URI
- Multi-IP trusted_domains via `get_all_ips()` — filters Docker bridge IPs
- Append-only trusted_domains logic — never removes old IPs or user-added domains
- memcache.local=APCu (default Nextcloud 30+), locking+distributed=Redis
- Resource limits: db=512M, nextcloud=1G, redis=256M, nginx=128M
- System cron: */5 * * * * for cron.php
- PHP opcache tuned: interned_strings=16, max_files=10000, memory=128
- Helper scripts: nc-occ, nc-status, nc-logs, nc-restart, nc-upgrade, nc-rollback — all with --profile http
- nginx healthcheck uses 127.0.0.1 (not nextcloud hostname) — fixed unhealthy status
- nginx proxy timeout: 300s
- README/MOTD includes First Time Setup (login, change password, add domain)
- All tests passed: reboot survive, docker restart survive, WebDAV upload/download/delete, IP change (138→162), helper scripts 6/6

## Changelog

| Date | Change |
|---|---|
| 2026-07-07 | Initial build — Ubuntu 26.04 + Nextcloud 30.0.17 + PostgreSQL 16.9 + Redis 7.4 + Nginx 1.27 |
| 2026-07-07 | Production hardening: Redis password, resource limits, memcache, opcache, cron, helper scripts, upgrade/rollback |
| 2026-07-08 | Fixing multi-interface VM detection in bootstrap script - prioritize ens4 (public) over ens3 (private) |
| 2026-07-08 | Fix Redis password special chars (alphanumeric-only), get_all_ips(), append-only trusted_domains, nc-upgrade/nc-rollback --profile http, nginx healthcheck 127.0.0.1, First Time Setup in README/MOTD |
| 2026-07-08 | Pre-capture cleanup (Layer 1 app + Layer 2 OS light + authorized_keys last) and image captured. Post-test on fresh VM from captured image: PASS 12/12 (browser login, WebDAV, no leftover artifacts) |
| 2026-07-09 | Established Customer App Playbook (`docs/playbooks/customer-app-playbook.md`) + prompt kit — Nextcloud as reference implementation; README First Time Setup no longer forces password change (gen_password 24-char is strong enough) |
| 2026-07-09 | Rebuild on new VM (203.154.16.62): Docker 29.6.1, all 4 images pre-pulled, bootstrap auto-install PASS, browser login + dashboard PASS, cleanup done. Fixed REIDS_PASSWORD typo in deployed compose. |

## Do Not Record

- Image name
- Glance ID
- Server ID
- Floating IP or VM IP
- Hostname
- OpenStack project/user/auth context
- Passwords, tokens, private keys, or runtime credentials
