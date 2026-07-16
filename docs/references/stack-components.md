# Stack Components Catalog

> Component สำเร็จรูป — Cid เลือกผสมตาม research  
> ทุก entry มี: snippet + When to use + When NOT + Real-world reference

---

## Database Components

### db: mariadb

**When to use:** app ต้องการ MySQL-compatible database, community แนะนำ MariaDB เร็วกว่า MySQL

**When NOT:** app ใช้ PostgreSQL, app มี SQLite ในตัว, app เป็น stateless

**docker-compose snippet:**
```yaml
db:
  image: mariadb:lts
  restart: unless-stopped
  volumes:
    - db_data:/var/lib/mysql
  environment:
    MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
    MARIADB_DATABASE: ${MARIADB_DATABASE}
    MARIADB_USER: ${MARIADB_USER}
    MARIADB_PASSWORD: ${MARIADB_PASSWORD}
  healthcheck:
    test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
    interval: 10s
    retries: 5
```

**Real-world:** WordPress

---

### db: postgres

**When to use:** app ต้องการ PostgreSQL (Odoo, n8n, Nextcloud, GitLab)

**When NOT:** app ใช้ MySQL (WordPress), app มี SQLite ในตัว

**docker-compose snippet:**
```yaml
db:
  image: postgres:17-alpine
  restart: unless-stopped
  volumes:
    - db_data:/var/lib/postgresql/data
  environment:
    POSTGRES_PASSWORD: ${DB_PASSWORD}
    POSTGRES_DB: ${DB_NAME}
    POSTGRES_USER: ${DB_USER}
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d {DB_NAME}"]
    interval: 10s
    retries: 5
```

**Version strategy:** Pin minor (17), ไม่ pin patch (alpine จะได้ security update)

**Real-world:** Odoo, n8n, Nextcloud

---

## Reverse Proxy Components

### proxy: nginx

**When to use:** app ต้องการ reverse proxy เพื่อ HTTPS, static file serving, gzip, webhook forwarding

**When NOT:** app serve HTTP ได้สมบูรณ์ในตัวและ HTTPS ไม่จำเป็น, app ใช้ Caddy auto-SSL

**docker-compose snippet:**
```yaml
proxy:
  image: nginx:stable-alpine
  restart: unless-stopped
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    - app_data:/var/www/html:ro  # ถ้า app เป็น PHP
```

**Nginx config requirements:**
- `client_max_body_size` ≥ upload limit ของ app
- `fastcgi_param HTTPS $https if_not_empty` — app รู้เองว่าใช้ HTTP/HTTPS
- ถ้า app เป็น PHP: `try_files` rewrite rules
- **WebSocket endpoints** — app ที่ใช้ WebSocket ต้องมี `location` block เฉพาะด้วย `proxy_set_header Upgrade $http_upgrade` + `Connection "Upgrade"` ไม่ใช่แค่ `location /` (ซึ่งมัก set `Connection ''` เพื่อ HTTP keepalive — ค่านี้จะ strip WebSocket handshake)
  - n8n example: `/rest/push` (UI push channel สำหรับ real-time workflow execution status), `/(webhook|webhook-test)` — ถ้าขาด block เฉพาะ → browser ได้ "Lost connection to the server" เมื่อ execute workflow

**Real-world:** WordPress, Nextcloud, n8n

---

### proxy: caddy

**When to use:** ต้องการ auto-SSL (Let's Encrypt) โดยไม่ต้อง config เพิ่ม

**When NOT:** ไม่มี domain จริง (IP-only VM), ต้องการ custom SSL cert

> Caddy ยังไม่มี real-world reference ใน catalog นี้ — ใช้เมื่อ research แนะนำ

---

## Cache Components

### cache: redis

**When to use:** app ต้องการ object cache หรือ session cache (Nextcloud, WordPress กรณี traffic สูง)

**When NOT:** app ไม่มี cache adapter, research ไม่พูดถึง, traffic ต่ำ

**docker-compose snippet:**
```yaml
cache:
  image: redis:7-alpine
  restart: unless-stopped
  volumes:
    - cache_data:/data
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 10s
    retries: 3
```

**Real-world:** Nextcloud

---

### vector-db: weaviate

**When to use:** app ต้องการ vector database สำหรับ AI embedding/RAG — Weaviate เป็นตัวเลือก default ของ platform ที่ deploy ด้วย Docker Compose

**When NOT:** app ใช้ built-in vector store (LanceDB/SQLite), app มี vector store น้อยมากใช้ pgvector พอ, หรือต้องการ performance สูงมาก (ใช้ Qdrant/Milvus)

**docker-compose snippet:**
```yaml
weaviate:
  image: semitechnologies/weaviate:1.27.0
  restart: unless-stopped
  environment:
    AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: "true"
    PERSISTENCE_DATA_PATH: /var/lib/weaviate
    DEFAULT_VECTORIZER_MODULE: none
    CLUSTER_HOSTNAME: node1
  volumes:
    - weaviate_data:/var/lib/weaviate
```

**Known risk:** Weaviate อาจใช้ RAM พุ่งสูง 3-6 GB ถ้ามี knowledge base จำนวนมาก — monitor memory, หรือเปลี่ยนเป็น pgvector/Qdrant สำหรับ production

**Real-world:** Dify CE

---

### infra: ssrf-proxy

**When to use:** app มี code execution sandbox ที่ต้องป้องกัน SSRF (Server-Side Request Forgery) — sandbox container ต้อง route HTTP ผ่าน proxy ก่อนออก internet

**When NOT:** app ไม่มี sandbox, sandbox อยู่บน network isolated อยู่แล้ว, หรือใช้ alternative SSRF protection (e.g. iptables rules)

**docker-compose snippet:**
```yaml
ssrf_proxy:
  image: ubuntu/squid:latest
  restart: unless-stopped
  volumes:
    - ssrf_proxy_cache:/var/spool/squid
  networks:
    - main-net
    - sandbox-net

sandbox:
  image: <sandbox-image>:<version>
  restart: unless-stopped
  environment:
    HTTP_PROXY: http://ssrf_proxy:3128
    HTTPS_PROXY: http://ssrf_proxy:3128
  networks:
    - sandbox-net
```

**Network design:** SSRF proxy bridge 2 networks — main-net (app ↔ proxy) + sandbox-net (proxy ↔ sandbox, internal). Sandbox ต้องไม่เข้า main-net โดยตรง

**Real-world:** Dify CE

---

## App Runtime Components

### monitoring: prometheus-grafana

**When to use:** image ต้องการ self-service VM / website / service monitoring พร้อม dashboard และ alerting

**When NOT:** user ต้องการ log aggregation/tracing เป็นหลัก, หรือ monitoring ถูกผูกกับ provider control plane/credential เฉพาะ

**docker-compose pattern:**
```yaml
services:
  grafana:
    image: grafana/grafana:latest
    restart: unless-stopped
    environment:
      GF_SECURITY_ADMIN_USER: ${GRAFANA_ADMIN_USER:-admin}
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD}
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro

  prometheus:
    image: prom/prometheus:latest
    restart: unless-stopped
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.retention.time=30d
      - --web.enable-lifecycle
    volumes:
      - prometheus_data:/prometheus
      - ./prometheus:/etc/prometheus:ro

  alertmanager:
    image: prom/alertmanager:latest
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    restart: unless-stopped
    pid: host
    command:
      - --path.rootfs=/host
    volumes:
      - /:/host:ro,rslave

  blackbox-exporter:
    image: prom/blackbox-exporter:latest
    restart: unless-stopped
```

**Self-service requirements:**
- First boot generate random Grafana admin password ต่อ VM
- Reboot ห้ามเปลี่ยน password
- มี `monitoring-reset-grafana-password` สำหรับกรณีลืม password
- เพิ่ม targets ผ่าน file_sd + helper scripts ไม่บังคับ user แก้ YAML เองตั้งแต่แรก
- Public expose เฉพาะ reverse proxy; Prometheus/Alertmanager/exporters ไม่ควร expose public
- Prometheus TSDB ใช้ local volume/disk ไม่ใช้ NFS/SMB/EFS-like storage

**Real-world:** Grafana+Prometheus

---

### app: php-fpm

**When to use:** app เขียนด้วย PHP (WordPress, Nextcloud, Moodle)

**Base pattern:**
```yaml
app:
  image: <app-image>:<version>
  restart: unless-stopped
  volumes:
    - app_data:/var/www/html
  environment:
    - APACHE_RUN_USER=#33
    - APACHE_RUN_GROUP=#33
```

**UID/GID:** PHP-FPM มักใช้ UID 33 (www-data) — nginx ต้อง mount volume ด้วย UID ตรงกัน

---

### app: node

**When to use:** app เขียนด้วย Node.js (n8n, Ghost, Uptime Kuma)

**Base pattern:**
```yaml
app:
  image: <app-image>:<version>
  restart: unless-stopped
  volumes:
    - app_data:/home/node/.n8n  # example
  environment:
    - NODE_ENV=production
```

**Real-world:** n8n

---

### app: python

**When to use:** app เขียนด้วย Python (Odoo)

**Base pattern:**
```yaml
app:
  image: <app-image>:<version>
  restart: unless-stopped
  volumes:
    - app_data:/var/lib/odoo
  ports:
    - "8069:8069"
```

**Real-world:** Odoo

---

### app: go

**When to use:** app เขียนด้วย Go (Gitea, Grafana, Prometheus, Ollama)

**Base pattern:**
```yaml
app:
  image: <app-image>:<version>
  restart: unless-stopped
  volumes:
    - app_data:/data
  ports:
    - "3000:3000"
```

**Real-world:** — (ยังไม่มีใน catalog นี้ จะเพิ่มเมื่อ build app จริง)

---

### app: generic

**When to use:** app runtime ที่ไม่มีใน catalog นี้ — ใช้ base pattern, ดัดแปลงตาม research

**Base pattern:**
```yaml
app:
  image: <app-image>:<version>
  restart: unless-stopped
  volumes:
    - app_data:/data
```

**Real-world:** สำหรับ app ที่ runtime อยู่นอก php-fpm, node, python, go

---

## Research-Backed Candidate Patterns

> Pattern กลุ่มนี้มาจาก catalog research วันที่ 2026-06-14 ยังไม่ถือเป็น real-world built component จนกว่าจะมี `apps/{app}/` ที่ build สำเร็จ

### pattern: ai-rag-no-gpu

**When to use:** app image กลุ่ม AI/RAG ที่ต้องใช้ได้บน VM ไม่มี GPU โดยใช้ external LLM API เป็น default และ optional local Ollama CPU สำหรับโมเดลเล็ก

**When NOT:** user คาดหวัง inference เร็วระดับ production local LLM, ต้องรัน 7B+ หลาย concurrent users, หรือต้องการ air-gapped performance สูงโดยไม่มี GPU

**Candidate apps:** AnythingLLM, Flowise, Open WebUI, LiteLLM Proxy  
**Real-world (built):** Dify CE, Ollama+Open WebUI

**Design rules:**
- Default image ต้อง boot ได้โดยไม่ต้องมี GPU และไม่ pull model ใหญ่ตอน first boot
- แยก `APP_SECRET`, API keys, model provider config ออกจาก golden image; สร้าง/รับค่าตอน first boot
- ถ้าใช้ external API ให้เปิด UI เพื่อใส่ key ภายหลัง หรือเก็บ key ใน `/root/{app}-credentials.txt` เฉพาะตอน user ตั้งเอง
- ถ้า optional Ollama CPU ให้ระบุชัดว่า 1B-4B model เหมาะกับ 4-8 GB RAM; 7B ต้อง 8-16 GB RAM และช้า
- ห้ามโฆษณาว่า “offline AI เร็ว” ถ้าไม่มี GPU; ให้ใช้คำว่า “CPU-capable / API-provider ready”

**Base compose shape:**
```yaml
services:
  app:
    image: <ai-app-image>:<version>
    restart: unless-stopped
    environment:
      APP_SECRET: ${APP_SECRET}
      # Provider keys are optional and should be added after first boot.
    volumes:
      - app_data:/app/data
    ports:
      - "3000:3000"

volumes:
  app_data:
```

**Resource floor:** UI/RAG app only 1-2 vCPU, 2-4 GB RAM; Dify-class full stack 4 vCPU, 8 GB RAM (12 containers: API, Worker, Worker Beat, Web, Plugin Daemon, WebSocket, PostgreSQL, Redis, Nginx, Sandbox, SSRF Proxy, Weaviate)

**Real-world built:** Ollama+Open WebUI (2 containers, 8 GB), Dify CE (12 containers, 8 GB)

**Research references:** AnythingLLM, Flowise, Dify, Open WebUI docs/release pages checked 2026-06-14; Dify built 2026-06-21

---

### pattern: lightweight-saas-replacement

**When to use:** app image ที่แทน SaaS per-seat/per-usage ได้ชัด เช่น password manager, analytics, helpdesk, Airtable-like DB, project management

**When NOT:** app ต้องผูก domain/SMTP/payment provider จำนวนมากจน first boot ใช้งานไม่ได้, หรือ CE มี feature จำกัดจนไม่พอใช้งานจริง

**Candidate apps:** Vaultwarden, Umami, Chatwoot CE, NocoDB, Plane CE, Cal.com, Coolify

**Design rules:**
- First boot ต้องสร้าง admin password/token ต่อ VM และเขียน credential ไว้ที่ `/root/{app}-credentials.txt` ด้วย `chmod 600`
- ถ้า browser feature บังคับ HTTPS เช่น Vaultwarden Web Crypto ให้บอกชัดว่า HTTP ใช้ evaluate ได้ แต่ production ต้องมี domain/HTTPS
- ถ้า app ต้อง SMTP ให้ boot ได้ก่อนโดย SMTP optional; UI/admin ค่อยตั้งภายหลัง
- ใช้ SQLite เมื่อ upstream แนะนำและเหมาะกับ small team; ใช้ PostgreSQL เมื่อ app/scale ต้องการ
- ไม่เปิด admin/internal ports public ถ้าไม่จำเป็น; bind DB/Redis เฉพาะ Docker network

**Base compose shape:**
```yaml
services:
  app:
    image: <saas-replacement-image>:<version>
    restart: unless-stopped
    environment:
      APP_URL: ${APP_URL:-http://localhost}
      ADMIN_PASSWORD: ${ADMIN_PASSWORD}
    volumes:
      - app_data:/data
    ports:
      - "80:80"

volumes:
  app_data:
```

**Resource floor:** lightweight single-container apps 1 vCPU, 512 MB-1 GB RAM; Rails/Django multi-service apps 2-4 vCPU, 4 GB RAM

**Research references:** Vaultwarden, Umami, Chatwoot, Plane, Coolify docs/release pages checked 2026-06-14

---

## Host / Non-Docker Components

### host: docker-ce

**When to use:** image เป็น general-purpose Docker host หรือ app guide ต้องการ Docker Engine บน VM โดยตรง

**When NOT:** app ใช้ systemd-native โดยไม่ต้องรัน container, หรือ platform ใช้ managed Kubernetes/container service อยู่แล้ว

**Install snippet:**
```bash
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
cat > /etc/apt/sources.list.d/docker.sources << EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
```

**Daemon defaults:**
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

**Security notes:** Docker group เป็น root-equivalent; Docker published ports อาจ bypass UFW rules ให้ใช้ OpenStack security group และ `DOCKER-USER` เมื่อต้อง restrict source

**Real-world:** Docker Platform, WordPress, Nextcloud, Odoo

---

### ui: portainer-ce

**When to use:** ต้องการ Web UI สำหรับจัดการ Docker host ให้ beginner/SMB ใช้ง่าย

**When NOT:** ต้องการ minimal hardened host, ไม่ต้องการ expose admin UI, หรือใช้ orchestrator/management platform อื่นแล้ว

**docker-compose snippet:**
```yaml
services:
  portainer:
    image: portainer/portainer-ce:lts
    container_name: portainer
    restart: always
    ports:
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

volumes:
  portainer_data:
    name: portainer_data
```

**Security notes:** Portainer mount `/var/run/docker.sock` จึงควบคุม Docker host ได้ทั้งหมด; เปิดเฉพาะ `9443` default, ไม่เปิด `8000` Edge tunnel ถ้าไม่ได้ใช้ Edge Agents

**Real-world:** Docker Platform

---

### ui: nginx-proxy-manager

**When to use:** ลูกค้าทั่วไปต้องการ Web UI สำหรับจัด domain, reverse proxy, และ Let's Encrypt cert โดยไม่ต้องเขียน Nginx config เอง

**When NOT:** ต้องการ minimal host, ต้องการ config-as-code ล้วน, หรือทีมถนัด Caddy/Traefik มากกว่า Web UI

**docker-compose snippet:**
```yaml
services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - "80:80"
      - "81:81"
      - "443:443"
    environment:
      TZ: ${TZ:-Asia/Bangkok}
      DISABLE_IPV6: "true"
    volumes:
      - npm_data:/data
      - npm_letsencrypt:/etc/letsencrypt

volumes:
  npm_data:
  npm_letsencrypt:
```

**Security notes:** เปิด `80/443` public สำหรับเว็บ, จำกัด `81` เฉพาะ admin IP; upstream default login คือ `admin@example.com` / `changeme` และควรให้ bootstrap เปลี่ยนผ่าน API ก่อนส่ง credentials ให้ลูกค้า

**Real-world:** Docker Platform

---

### systemd-native

**When to use:** research บอกว่า Docker ไม่เหมาะ, app ต้องการ bare-metal performance, หรือ app architecture ไม่เข้า Docker pattern

**When NOT:** app มี Docker image อย่างเป็นทางการและ Docker ทำให้ deploy ง่ายกว่า

**Base pattern:**
```bash
# Install script — install app โดยตรง ไม่ผ่าน container
# ตัวอย่าง: apt install <app>, configure, systemctl enable

# Systemd unit
cat > /etc/systemd/system/<app>.service << 'EOF'
[Unit]
Description=<App>
After=network.target

[Service]
ExecStart=/usr/bin/<app>
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable <app>
```

**Real-world:** OpenCode (binary download + systemd service + bootstrap oneshot)

**Extended pattern — systemd-native with bootstrap:**

```bash
# ── Dedicated system user ──
useradd -r -m -d /home/<app> -s /bin/bash <app>

# ── Binary install (download from GitHub Releases) ──
VERSION="X.Y.Z"
curl -fsSL https://github.com/<org>/<repo>/releases/download/v${VERSION}/<binary>.tar.gz | tar xz
cp <binary> /usr/local/bin/<app>
chmod +x /usr/local/bin/<app>

# ── Bootstrap oneshot (runs once, generates password/config) ──
cat > /etc/systemd/system/<app>-bootstrap.service << 'EOF'
[Unit]
Description=<App> First-Boot Bootstrap
After=network.target network-online.target
Wants=network-online.target
ConditionPathExists=!/etc/<app>/.bootstrapped

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/<app>-bootstrap.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# ── Persistent service (User=<app>, EnvironmentFile) ──
cat > /etc/systemd/system/<app>.service << 'EOF'
[Unit]
Description=<App> Service
After=network.target <app>-bootstrap.service

[Service]
Type=simple
User=<app>
Group=<app>
EnvironmentFile=/etc/<app>/environment
ExecStart=/usr/local/bin/<app> --hostname 0.0.0.0 --port <PORT>
Restart=always
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable <app>-bootstrap.service
```

**Key differences from Docker pattern:**
- No `docker-compose.yml` — binary installed directly on host
- Bootstrap oneshot generates secrets (password/token) per VM → `EnvironmentFile`
- Service uses `User=<app>` for isolation (substitute for container)
- `systemctl enable <app>-bootstrap.service` (oneshot) **not** `<app>.service` — persistent service start โดย bootstrap
- Pre-capture cleanup: remove generated secrets, stop persistent service, disable persistent service

**Real-world apps using this pattern:**
- OpenCode (binary download v1.17.9, random password, dedicated user, fake xdg-open for headless)

---



## How to Add New Component

เมื่อ build app ใหม่แล้วพบว่าต้องมี component ที่ยังไม่มีใน catalog:

1. เขียน snippet — จากของจริงที่ build สำเร็จแล้ว
2. ใส่ When to use / When NOT — อ้างอิง research
3. ใส่ Real-world reference — อย่างน้อย 1 app
4. ใส่ที่นี่ — `docs/references/stack-components.md`

**หลักการ:** เพิ่มเมื่อมี app จริงที่ใช้ ไม่เพิ่มจากทฤษฎี

---

**Version:** 2026-06-16
**Referenced by:** `(moved to skill)`
