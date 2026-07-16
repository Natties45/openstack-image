# Application Image Catalog

> Ubuntu 26.04-based ready-to-use application images for OpenStack
> **Build Pattern:** Docker Compose app stack + systemd bootstrap + pre-pull images -> QCOW2 -> Glance

**Last upstream check:** 2026-07-16

---

## Column Rules

Catalog นี้ใช้ข้อมูลที่ตรวจได้จริงเท่านั้น ไม่ใช้คะแนนความนิยม/ความง่ายแบบเดาเอง

| Column | ความหมาย |
|---|---|
| `Repo Status` | สถานะ source/guide ใน repo ตอนนี้ |
| `Image Target` | version/stack ที่ guide หรือ source ใน repo ตั้งใจ build จริง |
| `Upstream Signal` | version ล่าสุดหรือ signal ล่าสุดที่ตรวจจาก upstream วันนี้ ยังไม่ได้แปลว่า image build แล้ว |
| `Minimum Size` | baseline สำหรับ VM เล็กสุดที่ควรเริ่มทดสอบ ไม่ใช่ sizing สำหรับ production traffic |
| `Manifest` | link ไป `apps/{app}/docs/{app}-build-manifest.md`; ถ้ายังไม่มีให้ใส่ `pending` |
| `Next Action` | สิ่งถัดไปที่ต้องทำเพื่อให้ build/rebuild ได้จริง |

> **หมายเหตุ Customer Service apps:** ถ้า `Usage Type = Customer Service` → build/rebuild/cleanup/post-test ต้องทำตาม `docs/AI-PIPELINE.md` และ `app-for-customer` skill

---

## Current Repo Images

| App | Category | Usage Type | Repo Status | Repo Folder | Image Target | Upstream Signal | Stack | Minimum Size | Manifest | Next Action |
|---|---|---|---|---|---|---|---|---|---|---|
| **WordPress** | CMS / Blog | **Customer Service** | built: standalone | `apps/wordpress/` | `wordpress:7.0.0-php8.3-fpm` + `mariadb:11.4.8` + `nginx:1.30.3` + `wp-cli:2.12.0` | WordPress 7.0 latest | PHP-FPM + MariaDB + Nginx + WP-CLI | 1 vCPU / 1 GB / 10 GB | [`manifest`](wordpress/docs/wordpress-build-manifest.md) | Ready for capture/deploy |
| **WooCommerce** | E-Commerce | **Customer Service** | พร้อม build | `apps/woocommerce/` | WordPress + WooCommerce bootstrap | WooCommerce 10.8.1 | PHP-FPM + MariaDB + Nginx + WP-CLI | 2 vCPU / 2 GB / 15 GB | [`manifest`](woocommerce/docs/woocommerce-build-manifest.md) | Build ecommerce image แยกจาก WordPress |
| **Nextcloud** | Collaboration / File Sharing | **Customer Service** | built: production | `apps/nextcloud/` | `nextcloud:30.0-apache` + `postgres:16.9` + `redis:7.4-alpine` + `nginx:1.27-alpine` | Nextcloud 34.0.0 | Nextcloud Apache + PostgreSQL + Redis + Nginx | 2 vCPU / 2 GB / 20 GB | [`manifest`](nextcloud/docs/nextcloud-build-manifest.md) | Rebuilt — ready for capture/deploy |
| **Odoo** | Business / ERP / CRM | **Customer Service** | พร้อม build | `apps/odoo/` | `odoo:18.0` + `postgres:16` + `nginx:1.27` | Odoo 19 stable/recommended | Python/Odoo + PostgreSQL + Nginx | 2 vCPU / 2-4 GB / 20 GB | [`manifest`](odoo/docs/odoo-build-manifest.md) | ใช้ Odoo 18 guide ต่อ หรือทำ review ก่อน upgrade เป็น 19 |
| **Grafana+Prometheus** | Monitoring / Analytics | **Customer Service** | ผ่านตรวจ | `apps/grafana-prometheus/` | `grafana/grafana-oss:11.6.5` + `prom/prometheus:v3.13.1` + `nginx:stable-alpine` | Grafana 11.6.5; Prometheus 3.13.1 LTS | Grafana + Prometheus + Alertmanager + Exporters + Nginx | 2 vCPU / 2 GB / 15 GB | [`manifest`](grafana-prometheus/docs/grafana-prometheus-build-manifest.md) | IP change test PASS — ready for cleanup/capture |
| **n8n** | Automation / AI no-GPU | **Customer Service** | built: standalone | `apps/n8n/` | `n8nio/n8n:2.29.8` + `postgres:16` + `nginx:stable` | n8n 2.29.8 | Node.js + PostgreSQL + Nginx | 1-2 vCPU / 2 GB / 10 GB | [`manifest`](n8n/docs/n8n-build-manifest.md) | VM SHUTOFF; ready for OpenStack capture |
| **Docker Platform** | DevOps / Platform | **Personal Use** | พร้อม build | `apps/docker-platform/` | Docker CE + Portainer + Nginx Proxy Manager | Portainer 2.39.3 LTS; NPM 2.15.1 | Docker CE + Portainer + NPM | 1 vCPU / 2 GB / 15 GB | [`manifest`](docker-platform/docs/docker-platform-build-manifest.md) | Verify image tags/pins แล้ว build |
| **Ollama + Open WebUI** | AI / Local LLM Chatbot | **Personal Use** | built: standalone | `apps/ollama-openwebui/` | `ollama/ollama:latest` + `ghcr.io/open-webui/open-webui:main` | Ollama v0.30.10; Open WebUI v0.9.6 | Ollama + Open WebUI (Docker Compose) | 2-4 vCPU / 8-16 GB / 30 GB | [`manifest`](ollama-openwebui/docs/ollama-openwebui-build-manifest.md) | Ready for capture/deploy |
| **AnythingLLM** | AI / RAG no-GPU | **Personal Use** | built: standalone | `apps/anythingllm/` | `mintplexlabs/anythingllm:1.14.0` + Nginx | AnythingLLM 1.14.0 | Node.js + SQLite/LanceDB + Nginx | 2 vCPU / 2-4 GB / 10 GB | [`manifest`](anythingllm/docs/anythingllm-build-manifest.md) | Ready for capture/deploy |
| **Dify CE** | AI / RAG / Workflow | **Test/Dev Tool** | build ล้มเหลว | `apps/dify/` | `langgenius/dify-api:1.14.2` + Web + PostgreSQL + Redis + Nginx + Weaviate + Sandbox | Dify 1.14.2 | Python Flask + Celery + Next.js + PostgreSQL 15 + Redis 6 + Nginx + Weaviate + Sandbox + SSRF Proxy | 4 vCPU / 8 GB / 25 GB | pending | Frontend calls plugin endpoints hardcoded — ต้องใช้ official compose หรือรอ plugin daemon stable |
| **OpenCode** | DevOps / AI Coding Agent | **Test/Dev Tool** | พร้อม build | `apps/opencode/` | opencode binary v1.17.9 | opencode latest | opencode binary + systemd | 1 vCPU / 1 GB / 10 GB | pending | Verify bootstrap และ build |
| **OpenClaw** | AI Gateway / Assistant | **Customer Service** | review drafted; planning in progress | `apps/openclaw/` | `openclaw/openclaw:v2026.7.1` | `v2026.7.1` | OpenClaw gateway + CLI + Docker Compose | 2 vCPU / 2-4 GB / 20 GB | pending | Review/plan approved → build guide + source |
| **LEMP Stack** | Dev/Base Stack | **Dev/Base Stack** | built: standalone | `apps/lemp/` | `nginx:1.30.3` + `php:8.3-fpm` + `mariadb:11.4.12` | Nginx 1.30.3 stable; PHP 8.3.31; MariaDB 11.4.12 LTS | Nginx + PHP-FPM + MariaDB | 1 vCPU / 1 GB / 10 GB | [`manifest`](lemp/docs/lemp-build-manifest.md) · [`manual`](lemp/docs/manual.html) | VM SHUTOFF; ready for OpenStack capture |

---

## Recommended Next Builds

> เรียงจากความพร้อมของ repo + value ของ image สำเร็จรูป + stack ที่ควรคุมได้ ไม่ใช่คะแนน popularity

| Order | App | Category | Why Now | Required Work |
|---|---|---|---|---|
| 1 | **Ollama + Open WebUI** | AI / Local LLM Chatbot | built: standalone + post-test PASS | Ready for snapshot capture |
| 2 | **n8n** | Automation / AI no-GPU → **Customer Service** | built: standalone; Phase 1 PASS; Phase 2 PASS; poweroff completed | VM SHUTOFF; ready for OpenStack capture |
| 3 | **Vaultwarden** | Security / Password Manager | stack เบา, value ชัด, bootstrap secret ต่อ VM ทำได้ตรงไปตรงมา | ทำ community review → build guide/source |
| 4 | **Dify CE** | AI / RAG / Workflow | review + guide พร้อมแล้ว 12 containers stack พร้อม build | Build + verify standalone |
| 5 | **AnythingLLM** | AI / RAG no-GPU | เหมาะเป็น AI image แบบไม่ต้องมี GPU ถ้าใช้ external LLM API | ทำ community review → build guide/source |
| 6 | **Nextcloud upstream sync** | Collaboration / File Sharing | captured; upstream 34.0.0 vs source 30.0 — gap widening | ตัดสินว่าจะ rebuild เป็น 34 หรือ maintain 30 (LTS-style) |
| 7 | **WooCommerce build** | E-Commerce | source พร้อมและเป็น variant ที่ชัดจาก WordPress | build + verify standalone |
| 8 | **Umami** | Monitoring / Analytics | analytics image เบา ใช้ PostgreSQL และเหมาะกับ self-host | ทำ community review → build guide/source |
| 9 | **Chatwoot CE** | Support / Helpdesk | business value สูง แต่ stack หนักกว่า apps เบา | ทำ review เรื่อง sizing, email, storage, bootstrap |
| 10 | **NocoDB** | No-code DB | Airtable replacement ใช้กับทีม non-tech ได้ | ทำ review เรื่อง CE/free features และ database mode |

---

## Catalog By Category

### CMS / E-Commerce

| App | Purpose | Usage Type | Repo Status | Image Target | Upstream Signal | Stack | Minimum Size | Next Action |
|---|---|---|---|---|---|---|---|---|
| **WordPress** | CMS/blog/website | **Customer Service** | built: standalone | `wordpress:7.0.0-php8.3-fpm` + `nginx:1.30.3` | WordPress 7.0 latest | PHP-FPM + MariaDB + Nginx + WP-CLI | 1 vCPU / 1 GB / 10 GB | Ready for capture/deploy |
| **WooCommerce** | Online store image | **Customer Service** | พร้อม build | WordPress + WooCommerce bootstrap | WooCommerce 10.8.1 | PHP-FPM + MariaDB + Nginx + WP-CLI | 2 vCPU / 2 GB / 15 GB | Build standalone ecommerce image |

### Collaboration / File Sharing

| App | Purpose | Usage Type | Repo Status | Image Target | Upstream Signal | Stack | Minimum Size | Next Action |
|---|---|---|---|---|---|---|---|---|
| **Nextcloud** | File sharing + collaboration | **Customer Service** | built: production | `nextcloud:30.0-apache` | Nextcloud 34.0.0 | Nextcloud Apache + PostgreSQL + Redis + Nginx | 2 vCPU / 2 GB / 20 GB | Captured — verify upstream drift later |

### Automation / AI No-GPU

| App | Purpose | Repo Status | Image Target | Upstream Signal | Stack | Minimum Size | Next Action |
|---|---|---|---|---|---|---|---|
| **n8n** | Workflow automation + AI nodes | built: standalone; Phase 1 PASS; Phase 2 PASS; poweroff completed | `n8nio/n8n:2.29.8` + `postgres:16` + `nginx:stable` | n8n 2.29.8 | Node.js + PostgreSQL + Nginx | 1-2 vCPU / 2 GB / 10 GB | VM SHUTOFF; ready for OpenStack capture |
| **Ollama + Open WebUI** | Local LLM web UI + Ollama | built: standalone; post-test PASS; no-cleanup | `ollama/ollama:latest` + `ghcr.io/open-webui/open-webui:main` | Ollama v0.30.10; Open WebUI v0.9.6 | Ollama + Open WebUI (Docker Compose) | 2-4 vCPU / 8-16 GB / 30 GB | Ready for capture/deploy |
| **AnythingLLM** | RAG / document Q&A / workspaces | built: standalone | `mintplexlabs/anythingllm:1.14.0` + Nginx | AnythingLLM 1.14.0 | Node.js + SQLite/LanceDB + Nginx | 2 vCPU / 2-4 GB / 10 GB | Ready for capture/deploy |
| **Dify CE** | Production AI app/RAG/workflow platform | build ล้มเหลว | `langgenius/dify-api:1.14.2` + Web + PostgreSQL + Redis + Nginx + Weaviate + Sandbox | Dify 1.14.2 | Python Flask + Celery + Next.js + PostgreSQL 15 + Redis 6 + Nginx + Weaviate + Sandbox + SSRF Proxy | 4 vCPU / 8 GB / 25 GB | Build + verify standalone |

### Business / ERP / CRM

| App | Purpose | Usage Type | Repo Status | Image Target | Upstream Signal | Stack | Minimum Size | Next Action |
|---|---|---|---|---|---|---|---|---|
| **Odoo** | ERP/CRM/Inventory/Website | **Customer Service** | พร้อม build | `odoo:18.0` | Odoo 19 stable/recommended | Python/Odoo + PostgreSQL + Nginx | 2 vCPU / 2-4 GB / 20 GB | Optional Odoo 19 research/upgrade |

### DevOps / Platform

| App | Purpose | Repo Status | Image Target | Upstream Signal | Stack | Minimum Size | Next Action |
|---|---|---|---|---|---|---|---|
| **Docker Platform** | Docker CE + management UI + proxy UI | พร้อม build | Docker CE + Portainer + NPM | Portainer 2.39.3 LTS; NPM 2.15.1 | Docker CE + Portainer + Nginx Proxy Manager | 1 vCPU / 2 GB / 15 GB | Verify pins/current tags |
| **OpenCode** | AI coding agent | พร้อม build | opencode binary v1.17.9 | opencode latest | opencode binary + systemd | 1 vCPU / 1 GB / 10 GB | Verify bootstrap และ build |

### Monitoring / Analytics

| App | Purpose | Repo Status | Image Target | Upstream Signal | Stack | Minimum Size | Next Action |
|---|---|---|---|---|---|---|---|
| **Grafana+Prometheus** | VM / website / service monitoring | ผ่านตรวจ | `grafana/grafana-oss:11.6.5` + `prom/prometheus:v3.13.1` + `nginx:stable-alpine` | Grafana 11.6.5; Prometheus 3.13.1 LTS | Grafana + Prometheus + Alertmanager + Exporters + Nginx | 2 vCPU / 2 GB / 15 GB | IP change test PASS — ready for cleanup/capture |

### Database / Base Stack

| App | Purpose | Repo Status | Image Target | Upstream Signal | Stack | Minimum Size | Next Action |
|---|---|---|---|---|---|---|---|
| **LEMP Stack** | Nginx + PHP-FPM + MariaDB base stack | built: standalone | `nginx:1.30.3` + `php:8.3-fpm` + `mariadb:11.4.12` | Nginx 1.30.3 stable; PHP 8.3.31; MariaDB 11.4.12 LTS | Nginx + PHP-FPM + MariaDB | 1 vCPU / 1 GB / 10 GB | Phase 1 cleanup done; Phase 2 pending |

---

## วิธี Build

ทุก app image ใช้ framework กลางจาก [`AI-PIPELINE.md`](../docs/AI-PIPELINE.md) แล้วอ่าน checklist ของแต่ละ app:

```text
Phase 0: Ubuntu guest image ตาม guide ของ app นั้น
Phase A: SSH -> apt install docker-ce + compose plugin
Phase 1: วาง docker-compose.yml + bootstrap.sh + systemd service
Phase 2: Pull images ล่วงหน้า (docker compose pull)
Phase 3: ทดสอบ bootstrap -> cleanup .env/credentials -> poweroff -> capture
```

### Docker Compose ทั่วไป

```yaml
services:
  app:      # application (PHP-FPM / Node.js / Python / Go)
  db:       # database (MySQL / PostgreSQL / SQLite volume)
  proxy:    # reverse proxy (Nginx / Caddy / Traefik)

volumes:
  app_data:
  db_data:
```
