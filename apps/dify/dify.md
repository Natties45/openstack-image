# Dify CE Image — Ubuntu 26.04 [build ล้มเหลว; test-dev-tool]

> **Final Design:** 11 containers — ไม่รวม plugin_daemon (marketplace)
> **Build Result:** Core Dify ทำงานได้ (setup, app, workflow, knowledge base) แต่ frontend ยังเรียก plugin endpoints → `PluginDaemonInnerError` → error notification เด้งใน UI
>
> **Root Cause:** Dify API มี plugin system ฝังใน code — ลบ plugin_daemon container ไม่พอ, ต้อง disable/remove ฝั่ง API ด้วยถึงจะเงียบ
>
> **Known Workarounds:**
> 1. error เป็น cosmetic — กด X ปิดได้, ไม่กระทบ core features
> 2. ถ้าอยากเงียบสนิท → ต้องใช้ official dify docker-compose เต็มรูปแบบ (git clone + env template)
> 3. หรือรอ Dify stable version ที่ plugin daemon endpoint ตรงกับ frontend
>
> ดู `dify-errors.md` สำหรับรายละเอียด build/pitfalls

> Image สำเร็จรูป: สร้าง VM → Dify CE พร้อมใช้งาน → เข้า Web UI ตั้งค่าผ่าน /install → ต่อ LLM API → ใช้งาน AI platform ได้ทันที

---

## เป้าหมาย

```text
ลูกค้าสร้าง VM จาก Image
→ systemd เรียก dify-bootstrap.sh
→ สร้าง SECRET_KEY + passwords → เขียน .env
→ start Docker + Dify 11 containers
→ เขียน /root/dify-credentials.txt (มี INIT_PASSWORD)
→ ลูกค้า SSH เข้า VM อ่าน README/credentials
→ เข้า http://<IP>/install → ใส่ INIT_PASSWORD → สร้างบัญชี admin
→ Settings → Model Providers → ใส่ API key → เริ่มใช้งาน
```

| รายการ | ค่า |
|---|---|
| Base OS | Ubuntu 26.04 |
| Docker | Docker CE จาก official Docker apt repo |
| Compose | Docker Compose plugin (`docker compose`) |
| Dify API | `langgenius/dify-api:1.14.2` |
| Dify Web | `langgenius/dify-web:1.14.2` |
| Sandbox | `langgenius/dify-sandbox:0.2.15` |
| PostgreSQL | `postgres:15-alpine` |
| Redis | `redis:6-alpine` |
| Nginx | `nginx:stable-alpine` |
| SSRF Proxy | `ubuntu/squid:latest` |
| Weaviate | `semitechnologies/weaviate:1.27.0` |
| Minimum flavor | 4 vCPU / 8 GB RAM / 25 GB disk |

---

## Customer URLs

| Service | URL | Purpose |
|---|---|---|
| Dify Console | `http://<VM-IP>` | Web UI — chat, workflow, knowledge base |
| Initial Setup | `http://<VM-IP>/install` | ตั้งค่า INIT_PASSWORD + สร้าง admin (ครั้งแรกเท่านั้น) |

Security group:
- Public: TCP `80`
- Admin only: TCP `22`

---

## Design

| เรื่อง | ตัดสินใจ | เหตุผล |
|---|---|---|
| Docker package source | official Docker apt repo | ไม่ใช้ snap, ไม่ใช้ Ubuntu docker.io |
| Stack | 11 containers — official Dify Docker images | Dify ออกแบบมาเป็น multi-service — ลดไม่ได้โดยไม่เสียฟีเจอร์ |
| Reverse proxy | `nginx:stable-alpine` บน VM port 80 | static config — ไม่ต้องใช้ envsubst template |
| Database | PostgreSQL 15 Alpine | default + recommended โดย Dify |
| Vector DB | Weaviate 1.27.0 | default ใน Dify, 1 container, community test มากสุด |
| Redis | Redis 6 Alpine พร้อม password | required — Celery broker + cache |
| Sandbox security | SSRF proxy (Squid) + dedicated network (internal) | ป้องกัน sandbox หลุดออก internet โดยตรง |
| Collaboration | api_websocket เปิด default | real-time workflow canvas สำหรับ multi-user |
| LLM | external API only | ไม่ bundle Ollama — Dify ตัว platform ไม่ใช้ GPU |
| INIT_PASSWORD | สุ่มตอน first boot | ป้องกัน unauthorized setup |
| Workers | CELERY_WORKER_AMOUNT=2 | ลด RAM peak สำหรับ VM 4 vCPU |
| Telemetry | CHECK_UPDATE_URL= | air-gapped golden image ไม่โทรออก |
| Logging | `json-file` พร้อม `max-size=10m`, `max-file=3` | ป้องกัน disk เต็ม |
| License | Dify Open Source License | free self-host single-org; ห้าม multi-tenant, ห้ามลบ LOGO |
| Golden image | pre-pull Docker images ได้ แต่ห้ามเหลือ containers/runtime data/credentials |

---

## ก่อนเริ่ม — Pre-flight Verification

| เช็ค | ได้จาก | ถ้ายังไม่พร้อม |
|---|---|---|
| Guest image Ubuntu 26.04 สร้างเสร็จแล้ว | `_guest-images.md` → Ubuntu 26.04 เสร็จ | ต้องสร้าง guest image ก่อน |
| VM สร้างจาก guest image ที่ผ่าน Set 1-3 ครบ | standalone build | สร้าง VM จาก guest image |
| Build guide พร้อม `[พร้อม build]` | header tag บน | ต้องสร้าง source files ก่อน |
| SSH credentials | `tmp/dify-build.env` (gitignored) | — |

**เมื่อ SSH เข้า VM แล้ว — verify บน VM:**

[golden-image VM]

```bash
lsb_release -a | grep Release
grep URIs /etc/apt/sources.list.d/ubuntu.sources
curl -sI https://download.docker.com | head -1
df -h /
free -h
```

ต้องได้:
- Ubuntu 26.04
- DNS ออก internet ได้
- disk free ≥ 20 GB
- RAM ≥ 8 GB

---

## โครงสร้างไฟล์

```text
/opt/dify/docker-compose.yml
/opt/dify/nginx/dify.conf
/opt/dify/storage/                              (first boot สร้างจริง — bind mount)
/opt/dify/.env                                  (first boot สร้างจริง)
/usr/local/sbin/dify-bootstrap.sh
/etc/systemd/system/dify-bootstrap.service
/root/README-dify-image.txt
/root/dify-credentials.txt                      (first boot สร้างจริง)
/etc/update-motd.d/99-dify-image
/etc/docker/daemon.json
```

ไฟล์/สถานะที่ต้องไม่มีใน Golden Image:

```text
/opt/dify/.env
/root/dify-credentials.txt
/var/log/dify-bootstrap.log
/var/lib/dify-firstboot.done
running containers
Docker volumes (dify_postgres_data, dify_redis_data, etc.) — ใช้ down -v ลบทั้งหมด
runtime credentials
```

---

## ขั้นตอน Build

### 1. ติดตั้ง base packages

[golden-image VM]

```bash
apt update && apt install -y ca-certificates curl gnupg openssl vim htop net-tools
```

### 2. ติดตั้ง Docker CE + plugins

[golden-image VM]

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

### 2.5 Configure Docker log rotation

[golden-image VM]

```bash
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
systemctl restart docker
```

### 3. สร้าง directories

[golden-image VM]

```bash
mkdir -p /opt/dify/nginx
chmod 755 /opt/dify /opt/dify/nginx
```

### 4. วาง source files

#### `/opt/dify/docker-compose.yml` — Dify CE 11 services (API, Worker, Web, DB, Redis, Nginx, Vector DB, Sandbox, SSRF Proxy, WebSocket)

[golden-image VM]

```bash
# ทุกไฟล์การตั้งค่าและสคริปต์ควบคุมจะถูกดึงจากโฟลเดอร์ source/ และ nginx/ โดยตรง เพื่อลดความซ้ำซ้อนของคู่มือ:
#
# - `source/docker-compose.yml` → `/opt/dify/docker-compose.yml`
# - `nginx/dify.conf` → `/opt/dify/nginx/dify.conf`
# - `source/dify-bootstrap.sh` → `/usr/local/sbin/dify-bootstrap.sh` (ต้องทำ `chmod +x`)
# - `source/dify-bootstrap.service` → `/etc/systemd/system/dify-bootstrap.service`
# - `source/README-dify-image.txt` → `/root/README-dify-image.txt`
# - `source/99-dify-image` → `/etc/update-motd.d/99-dify-image` (ต้องทำ `chmod +x`)
```

### 5. Enable bootstrap service

[golden-image VM]

```bash
systemctl daemon-reload
systemctl enable dify-bootstrap.service
```

### 6. Pre-pull Docker images

[golden-image VM]

> ขั้นตอนนี้ใช้เวลานาน — 12 images รวม ~3-4 GB

```bash
cat > /opt/dify/.env << 'EOF'
TZ=Asia/Bangkok
EOF
chmod 600 /opt/dify/.env

docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env pull

docker images --format '{{.Repository}}:{{.Tag}} {{.Size}}'
```

### 7. Test bootstrap แล้ว Phase 1 app cleanup runtime data

[golden-image VM]

```bash
/usr/local/sbin/dify-bootstrap.sh

docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env ps

sleep 180

docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env ps

curl -sI http://127.0.0.1:80 | head -1

docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env down -v

rm -f /opt/dify/.env
rm -f /root/dify-credentials.txt
rm -f /var/log/dify-bootstrap.log
rm -f /var/lib/dify-firstboot.done

ls /opt/dify/.env 2>&1 | grep -q 'No such file' && echo ".env: deleted"
ls /root/dify-credentials.txt 2>&1 | grep -q 'No such file' && echo "credentials: deleted"
ls /var/log/dify-bootstrap.log 2>&1 | grep -q 'No such file' && echo "bootstrap log: deleted"
ls /var/lib/dify-firstboot.done 2>&1 | grep -q 'No such file' && echo "firstboot marker: deleted"
```

> ใช้ `down -v` ลบ volumes ด้วย — PostgreSQL volume เก็บรหัสจาก build test ซึ่งจะ mismatch กับรหัสที่ bootstrap สร้างใหม่บน VM ถัดไป Dify ไม่มี model/data ที่ต้อง pre-pull ใน volume เหมือน Ollama

### 8. Pre-Capture Gate — AI verify after Phase 1

[golden-image VM]

```bash
set -e

systemctl is-enabled dify-bootstrap.service
systemctl is-enabled docker
docker version
docker compose version

docker images langgenius/dify-api:1.14.2 --format '{{.Repository}}:{{.Tag}}' | grep -q '^langgenius/dify-api:1.14.2$'
docker images langgenius/dify-web:1.14.2 --format '{{.Repository}}:{{.Tag}}' | grep -q '^langgenius/dify-web:1.14.2$'
docker images langgenius/dify-sandbox:0.2.15 --format '{{.Repository}}:{{.Tag}}' | grep -q '^langgenius/dify-sandbox:0.2.15$'
docker images postgres:15-alpine --format '{{.Repository}}:{{.Tag}}' | grep -q '^postgres:15-alpine$'
docker images redis:6-alpine --format '{{.Repository}}:{{.Tag}}' | grep -q '^redis:6-alpine$'
docker images nginx:stable-alpine --format '{{.Repository}}:{{.Tag}}' | grep -q '^nginx:stable-alpine$'
docker images ubuntu/squid:latest --format '{{.Repository}}:{{.Tag}}' | grep -q '^ubuntu/squid:latest$'
docker images semitechnologies/weaviate:1.27.0 --format '{{.Repository}}:{{.Tag}}' | grep -q '^semitechnologies/weaviate:1.27.0$'

if docker ps -q | grep -q .; then
  echo "FATAL: running containers remain"
  docker ps
  exit 1
fi
echo "containers: stopped"

if docker volume ls --format '{{.Name}}' | grep -qE '^dify_'; then
  echo "WARNING: dify volumes still exist — expected empty after down -v"
fi

test ! -e /opt/dify/.env && echo ".env: absent"
test ! -e /root/dify-credentials.txt && echo "credentials: absent"
test ! -e /var/log/dify-bootstrap.log && echo "bootstrap log: absent"
test ! -e /var/lib/dify-firstboot.done && echo "firstboot marker: absent" || { echo "FATAL: firstboot marker still exists"; exit 1; }
test -f /opt/dify/docker-compose.yml && echo "compose: present"
test -f /opt/dify/nginx/dify.conf && echo "nginx config: present"
test -f /root/README-dify-image.txt && echo "README: present"
```

ห้าม capture ถ้า:
- bootstrap service disabled
- Docker service disabled
- required Docker images ไม่ถูก pull ครบทั้ง 9 images
- containers ยังรัน
- volumes หาย
- `.env`, credentials, first boot marker, bootstrap log ยังอยู่

AI ต้องถาม user ก่อน Phase 2 เพราะ Phase 2 จะลบ SSH access และ poweroff.

### 9. Phase 2 — OS cleanup + poweroff (final)

[golden-image VM]

```bash
cloud-init clean --logs --seed
rm -rf /var/lib/cloud/instances/* /var/lib/cloud/instance /var/lib/cloud/sem/*
rm -f /etc/netplan/50-cloud-init.yaml 2>/dev/null || true
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id 2>/dev/null || true
ln -sf /etc/machine-id /var/lib/dbus/machine-id 2>/dev/null || true
rm -f /root/.bash_history /home/*/.bash_history
rm -rf /tmp/* /var/tmp/*
find /var/log -type f -name '*.log' -exec truncate -s 0 {} +
truncate -s 0 /var/log/wtmp /var/log/btmp /var/log/lastlog 2>/dev/null || true
rm -f /etc/ssh/ssh_host_*
find /etc/ssh/sshd_config.d -maxdepth 1 -type f -name '*.conf' ! -name '00-image-build.conf' -delete 2>/dev/null || true
fstrim -av || true
sync
rm -f /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys
poweroff
```

> **AI verify — ใช้ 1-shot verify script:** `docs/references/verify-phase2-template.sh` — upload → cleanup → verify → authorized_keys → poweroff
> ```bash
> # AI execution pattern (ไม่ใช่ manual step):
> # upload --localPath "docs/references/verify-phase2-template.sh" --remotePath "/tmp/verify-phase2.sh"
> # cleanup commands (ข้างบน)
> # execute-command "bash /tmp/verify-phase2.sh"
> # Expected: VERIFY:PASS หรือ VERIFY:FAIL <error_tags>
> ```


> **AI verify — ใช้ 1-shot verify script (ประหยัด token ~80%):**
> ```bash
> # upload --localPath "docs/references/verify-phase1-template.sh" --remotePath "/tmp/verify-phase1.sh"
> # execute-command "bash /tmp/verify-phase1.sh dify"
> # Expected: VERIFY:PASS หรือ VERIFY:FAIL <error_tags>
> ```


> ห้าม `apt clean`, `apt autoremove`, `docker image prune -a` — image นี้ตั้งใจเก็บ package cache และ Docker images ที่ pre-pull ไว้

---

## หลังลูกค้าสร้าง VM จาก Image

### อ่าน README

[customer VM]

```bash
cat /root/README-dify-image.txt
cat /root/dify-credentials.txt
```

### ตรวจ services

[customer VM]

```bash
systemctl status docker --no-pager
systemctl status dify-bootstrap.service --no-pager
docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env ps
```

### Setup Dify

```text
1. เปิด browser → http://<VM-IP>/install
2. ใส่ INIT_PASSWORD จาก /root/dify-credentials.txt
3. สร้าง admin account (email + password)
4. Settings → Model Providers → Add provider → ใส่ API key
5. เริ่มสร้าง App/Knowledge Base/Workflow ได้ทันที
```

### อัปเดต Dify

[customer VM]

```bash
# แก้ไข image tag ใน /opt/dify/docker-compose.yml ก่อน
docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env pull
docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env up -d
```

> ⚠️ หลังอัปเดต Dify จะรัน database migration อัตโนมัติ (`MIGRATION_ENABLED=true` default) — ห้ามเปลี่ยน `SECRET_KEY` เพราะจะ invalidate ทุก session/file URL/OAuth

### Backup database

[customer VM]

```bash
docker exec dify-postgres pg_dump -U postgres dify > /root/dify-backup-$(date +%Y%m%d).sql
```

### ลด RAM usage

[customer VM]

```bash
sed -i 's/CELERY_WORKER_AMOUNT=2/CELERY_WORKER_AMOUNT=1/' /opt/dify/.env
docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env up -d
```

---

## Acceptance Criteria (Cloud ตรวจก่อน snapshot)

- [ ] docker.service enabled
- [ ] dify-bootstrap.service enabled
- [ ] Docker images pre-pulled ครบ 9 images
- [ ] no containers running
- [ ] no Docker volumes present
- [ ] `.env`, `dify-credentials.txt`, `dify-bootstrap.log`, `dify-firstboot.done` — absent
- [ ] `/opt/dify/docker-compose.yml` — present
- [ ] `/opt/dify/nginx/dify.conf` — present
- [ ] `/root/README-dify-image.txt` — present
- [ ] no secrets on disk

## Record Build Manifest

หลัง pre-capture gate ผ่าน ให้ Cloud สร้าง/อัปเดต `apps/dify/dify-build-manifest.md` ด้วยข้อมูล version ที่ verify จาก golden-image VM เท่านั้น:

```bash
lsb_release -ds
docker version
docker compose version
docker images --digests --format '{{.Repository}}:{{.Tag}} {{.Digest}}'
```

เก็บเฉพาะ Base OS, Docker stack package versions แบบ minimal, Docker/Compose versions, container image tag + digest และ build notes สั้นๆ. ห้ามเก็บ image name, Glance ID, server ID, floating IP, VM IP, hostname, OpenStack context หรือ credentials.

---

## Source Files

```text
apps/dify/dify.md
apps/dify/dify-review.md
apps/dify/dify-errors.md
apps/dify/docker-compose.yml
apps/dify/nginx/dify.conf
apps/dify/dify-bootstrap.sh
apps/dify/dify-bootstrap.service
apps/dify/README-dify-image.txt
apps/dify/99-dify-image
```
