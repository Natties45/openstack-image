# LEMP Stack Build Manifest

> Non-secret golden image build history. Do not record runtime/OpenStack context.

---

## Latest Build

| Field | Value |
|---|---|
| App | LEMP Stack |
| Status | built: standalone |
| Build date | 2026-07-12 |
| Base OS | Ubuntu 26.04 |
| Source guide | `apps/lemp/lemp.md` |

## Host Packages

| Package | Version |
|---|---|
| docker-ce | 5:29.6.1-1~ubuntu.26.04~resolute |
| docker-ce-cli | 5:29.6.1-1~ubuntu.26.04~resolute |
| containerd.io | 2.2.6-1~ubuntu.26.04~resolute |
| docker-buildx-plugin | 0.35.0-1~ubuntu.26.04~resolute |
| docker-compose-plugin | 5.3.1-1~ubuntu.26.04~resolute |

## Runtime Tools

| Tool | Version |
|---|---|
| Docker Engine | 29.6.1 |
| Docker Compose | v5.3.1 |
| Docker Buildx | v0.35.0 |

## Container Images

| Image | Base Digest |
|---|---|
| `lemp-local-mariadb:11.4.12-tools` | `mariadb:11.4.12@sha256:a794d9eb009e20de605858a11f32f63b4075cbd197c650436f0e3b457e4caed7` |
| `lemp-local-php:8.3-fpm-tools` | `php:8.3-fpm@sha256:efaea017a0c269b359a5db12987d221eac127e192f98b60bb849538d2d9a3253` |
| `lemp-local-nginx:1.30.3-tools` | `nginx:1.30.3@sha256:5825bde471b86b270298e80ba1f0f3e515a73da1a17a982632f1c262689f1144` |

## Build Notes

- First build of LEMP Stack Dev Base Image
- PHP extensions installed: pdo_mysql, mysqli, mbstring, gd, zip, intl
- All 3 containers include bash, nano, vim-tiny for dev troubleshooting
- Bootstrap tested: containers healthy, no pull on first boot, DB accessible
- `lemp-db` helper reads root password from credentials file automatically
- Nginx returns 403 on `/` (expected — no index.php yet)
- PHP 8.3.32 (built Jul 2 2026) — newer patch than pinned 8.3.31 tag
- MariaDB 11.4.12 LTS confirmed working

## Changelog

| Date | Change |
|---|---|
| 2026-07-12 | Initial build — LEMP Stack Dev Base Image |

## Do Not Record

- Image name
- Glance ID
- Server ID
- Floating IP or VM IP
- Hostname
- OpenStack project/user/auth context
- Passwords, tokens, private keys, or runtime credentials
