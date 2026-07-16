# n8n Workflow Automation Image — Ubuntu 26.04  [built: standalone]
> Image สำเร็จรูป: สร้าง VM → n8n พร้อมใช้ทันทีที่ `http://<IP>/` (port 80 ผ่าน nginx always-on)
>
> **Customer Service app** — ปฏิบัติตาม `docs/playbooks/customer-app-playbook.md`
>
> **Ingress architecture (new):**
> - Port 80 — nginx always-on, serves HTTP directly (default mode)
> - Port 443 — opens when HTTPS enabled (certs present)
> - Port 5678 — localhost only (127.0.0.1), not exposed externally

---

## เป้าหมาย

```text
ลูกค้าสร้าง VM จาก Image
→ systemd เรียก n8n-bootstrap.sh
→ สุ่ม PostgreSQL password + N8N_ENCRYPTION_KEY ใหม่
→ สร้าง /opt/n8n/.env + /root/n8n-credentials.txt
→ เลือก nginx config (HTTP หรือ HTTPS ตาม cert)
→ start PostgreSQL + n8n + nginx (always-on)
→ เข้าเว็บได้ทันทีที่ http://<IP>/
```

| โหมด | รายละเอียด |
|---|---|
| HTTP (default) | พร้อมใช้ทันที `http://<IP>/` ผ่าน nginx port 80 |
| HTTPS | วาง cert/key → `n8n-https-enable` → port 80 redirect → 443 |

---

## โครงสร้างไฟล์

```text
/opt/n8n/docker-compose.yml
/opt/n8n/certs/                         (ว่าง — รอวาง cert)
/opt/n8n/nginx/n8n-http.conf            (HTTP config — port 80 serves directly)
/opt/n8n/nginx/n8n-https.conf           (HTTPS config — port 80 redirect → 443)
/opt/n8n/nginx/n8n.conf                 (active config — copy of http or https)
/usr/local/sbin/n8n-bootstrap.sh
/etc/systemd/system/n8n-bootstrap.service
/root/README-n8n-image.txt
/etc/update-motd.d/99-n8n-image
/usr/local/bin/n8n-status              (helper — status check)
/usr/local/bin/n8n-logs                (helper — tail logs)
/usr/local/bin/n8n-restart             (helper — restart stack)
/usr/local/bin/n8n-upgrade             (helper — upgrade n8n)
/usr/local/bin/n8n-rollback            (helper — rollback n8n)
/usr/local/bin/n8n-exec                (helper — n8n CLI)
/usr/local/bin/n8n-https-enable         (helper — enable HTTPS)
/usr/local/bin/n8n-cert-status          (helper — show cert status)
/usr/local/bin/n8n-https-disable        (helper — disable HTTPS, keep certs)
```

> หมายเหตุ: ถ้า template file ยังไม่มีใน repo ให้ถือว่า task ยังไม่พร้อม build ซ้ำแบบอัตโนมัติ ต้องสร้าง source files ก่อน เช่น `docker-compose.yml`, `n8n-bootstrap.sh`, `n8n-bootstrap.service`

ไฟล์ที่ต้องไม่มีใน Golden Image:
```text
/opt/n8n/.env
/root/n8n-credentials.txt
/var/log/n8n-bootstrap.log
Docker volumes
```

---

## ขั้นตอน Build

### 1. ติดตั้ง base packages

[golden-image VM]

```bash
apt update && apt install -y ca-certificates curl gnupg openssl jq vim htop net-tools
```

### 2. ติดตั้ง Docker

[golden-image VM]

```bash
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" > /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
```

### 3. สร้าง directory

[golden-image VM]

```bash
mkdir -p /opt/n8n/certs /opt/n8n/nginx
chmod 700 /opt/n8n/certs
```

### 4. สร้างไฟล์ static (self-contained — cat > file << 'EOF')

ทุกไฟล์ด้านล่างรันบน golden-image VM ได้โดยตรง ไม่ต้อง copy จาก repo

```bash
# ทุกไฟล์การตั้งค่าและสคริปต์ควบคุมจะถูกดึงจากโฟลเดอร์ source/, nginx/, และ helpers/ โดยตรง เพื่อลดความซ้ำซ้อนของคู่มือ:
#
# - `source/docker-compose.yml` → `/opt/n8n/docker-compose.yml`
# - `nginx/n8n-http.conf` → `/opt/n8n/nginx/n8n-http.conf`
# - `nginx/n8n-https.conf` → `/opt/n8n/nginx/n8n-https.conf`
# - `nginx/n8n.conf` (คัดลอกเริ่มต้นจาก n8n-http.conf) → `/opt/n8n/nginx/n8n.conf`
# - `source/n8n-bootstrap.sh` → `/usr/local/sbin/n8n-bootstrap.sh` (ต้องทำ `chmod +x`)
# - `source/n8n-bootstrap.service` → `/etc/systemd/system/n8n-bootstrap.service`
# - `source/README-n8n-image.txt` → `/root/README-n8n-image.txt`
# - `source/99-n8n-image` → `/etc/update-motd.d/99-n8n-image` (ต้องทำ `chmod +x`)
#
# และสคริปต์อำนวยความสะดวกใน `helpers/` จะถูกคัดลอกไปยัง `/usr/local/bin/` บน VM จริง:
# - `helpers/n8n-status` → `/usr/local/bin/n8n-status` (chmod +x)
# - `helpers/n8n-logs` → `/usr/local/bin/n8n-logs` (chmod +x)
# - `helpers/n8n-restart` → `/usr/local/bin/n8n-restart` (chmod +x)
# - `helpers/n8n-upgrade` → `/usr/local/bin/n8n-upgrade` (chmod +x)
# - `helpers/n8n-rollback` → `/usr/local/bin/n8n-rollback` (chmod +x)
# - `helpers/n8n-exec` → `/usr/local/bin/n8n-exec` (chmod +x)
# - `helpers/n8n-https-enable` → `/usr/local/bin/n8n-https-enable` (chmod +x)
# - `helpers/n8n-cert-status` → `/usr/local/bin/n8n-cert-status` (chmod +x)
# - `helpers/n8n-https-disable` → `/usr/local/bin/n8n-https-disable` (chmod +x)
```

### 5. เปิด systemd service

[golden-image VM]

```bash
systemctl daemon-reload
systemctl enable n8n-bootstrap.service
```

### 6. ทดสอบ bootstrap + pull images

[golden-image VM]

```bash
/usr/local/sbin/n8n-bootstrap.sh
docker pull nginx:stable
docker pull n8nio/n8n:2.29.8
docker pull postgres:16
```

> หลัง bootstrap ต้องเห็น containers 3 ตัว: postgres, n8n, nginx (all Up)
> ทดสอบ: `curl -sI http://localhost:80/` → 200/302 (ผ่าน nginx port 80)
> ทดสอบ: `curl -sI http://127.0.0.1:5678/` → 200/302 (direct n8n localhost)

### 7. Phase 1 — App cleanup ก่อน capture

[golden-image VM]

```bash
cd /opt/n8n
docker compose down --remove-orphans
docker compose down -v              # removes volumes
rm -f /opt/n8n/.env /root/n8n-credentials.txt /var/log/n8n-bootstrap.log
docker volume prune -f

# Reset nginx config to HTTP default (remove any HTTPS sync from test)
cp /opt/n8n/nginx/n8n-http.conf /opt/n8n/nginx/n8n.conf

# Purge unlisted artifacts (playbook §7) — keep only static files
find /opt/n8n -type f ! -name "docker-compose.yml" ! -name "bootstrap.sh" ! -name "*.conf" ! -name "README*" ! -name "MOTD*" -not -path "*/nginx/*" -delete
find /root -type f -name "*.md" -not -name "README*" -delete 2>/dev/null || true

# ห้ามใช้ docker image prune -a !!!
```

### 8. Pre-Capture Gate — AI verify after Phase 1

[golden-image VM]

```bash
# Service enabled
systemctl is-enabled n8n-bootstrap.service

# Static files present
ls -l /opt/n8n/docker-compose.yml /usr/local/sbin/n8n-bootstrap.sh
ls -l /opt/n8n/nginx/n8n-http.conf /opt/n8n/nginx/n8n-https.conf /opt/n8n/nginx/n8n.conf

# Helper scripts present and executable (9 total)
for h in n8n-status n8n-logs n8n-restart n8n-upgrade n8n-rollback n8n-exec \
         n8n-https-enable n8n-cert-status n8n-https-disable; do
  test -x "/usr/local/bin/$h" && echo "OK: $h" || echo "MISS: $h"
done

# Docker images preserved
docker images --format '{{.Repository}}:{{.Tag}}' | grep -E 'n8nio/n8n|postgres|nginx'

# No runtime artifacts
test ! -e /opt/n8n/.env
test ! -e /root/n8n-credentials.txt
test ! -e /var/log/n8n-bootstrap.log
test -z "$(docker ps -q --filter label=com.docker.compose.project=n8n)"
test -z "$(docker volume ls -q --filter label=com.docker.compose.project=n8n)"

# Certs dir empty (no certs in golden image)
test -z "$(ls -A /opt/n8n/certs/ 2>/dev/null)"

# nginx active config = HTTP default (not HTTPS)
diff -q /opt/n8n/nginx/n8n.conf /opt/n8n/nginx/n8n-http.conf
```

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

จากนั้น snapshot/create image ใน OpenStack:

[OpenStack client]

```text
ubuntu-26.04-n8n-workflow-https-ready-YYYYMM
```

> **AI verify — 1-shot scripts (ประหยัด token ~80%):**
> - **Phase 1:** `upload --localPath "docs/references/verify-phase1-template.sh" --remotePath "/tmp/verify-phase1.sh"` → cleanup → `execute-command "bash /tmp/verify-phase1.sh n8n"`
> - **Phase 2:** `upload --localPath "docs/references/verify-phase2-template.sh" --remotePath "/tmp/verify-phase2.sh"` → cleanup → `execute-command "bash /tmp/verify-phase2.sh"`
> - **Expected:** `VERIFY:PASS` หรือ `VERIFY:FAIL <error_tags>`


---

## Bootstrap Logic

| สถานะ | พฤติกรรม |
|---|---|
| VM ใหม่ (ไม่มี `.env`) | สุ่ม password + key ใหม่, `N8N_PROTOCOL=http`, start postgres + n8n + nginx |
| Reboot (HTTP mode) | ใช้ค่าเดิม, update IP ใน WEBHOOK_URL/N8N_HOST, sync HTTP nginx config |
| Reboot (HTTPS mode, มี cert) | ใช้ค่าเดิม, preserve domain, sync HTTPS nginx config |
| Reboot (HTTPS mode, ไม่มี cert) | fallback to HTTP + fix `.env`, sync HTTP nginx config, warn |
| หลัง `n8n-https-disable` | `.env` protocol=http, nginx config=HTTP — แม้ cert ยังอยู่ (preserve user intent) |

---

## วิธีเปิด HTTPS

### แบบอัตโนมัติ (แนะนำ)

```bash
# 1. ชี้ DNS ไป IP ของ VM
# 2. วาง cert ที่ตำแหน่งคงที่
#    /opt/n8n/certs/fullchain.pem  (chmod 644)
#    /opt/n8n/certs/privkey.pem    (chmod 600)
# 3. รัน helper
n8n-https-enable
#    → ถาม domain name, แก้ .env, activate HTTPS config, restart stack
```

### แบบ manual (advanced)

```bash
# 1. วาง cert ตามตำแหน่งข้างต้น
# 2. แก้ /opt/n8n/.env:
#    N8N_HOST=n8n.customer.com
#    N8N_PROTOCOL=https
#    WEBHOOK_URL=https://n8n.customer.com/
#    N8N_SECURE_COOKIE=true
#    N8N_PROXY_HOPS=1
# 3. Activate HTTPS config:
cp /opt/n8n/nginx/n8n-https.conf /opt/n8n/nginx/n8n.conf
# 4. Restart:
cd /opt/n8n && docker compose down && docker compose up -d
```

> หมายเหตุ: `N8N_PROXY_HOPS=1` ทั้ง HTTP และ HTTPS mode เพราะ nginx always-on อยู่หน้า n8n เสมอ

---

## วิธีปิด HTTPS

```bash
n8n-https-disable
# → confirm, revert .env to http://<IP>/, activate HTTP config, restart
# → cert files PRESERVED at /opt/n8n/certs/ — ไม่ลบ
```

หลัง disable ถ้า reboot → bootstrap จะใช้ HTTP config (แม้ cert ยังอยู่) เพราะ `.env` protocol=http → preserve user intent

---

## ข้อควรระวัง

- `/opt/n8n/.env` มี secret — ห้ามลบหลังใช้งานแล้ว
- ห้ามเปลี่ยน `N8N_ENCRYPTION_KEY` หลังสร้าง credentials ใน n8n
- ห้าม `docker compose down -v` บนเครื่องลูกค้า — ลบ volume PostgreSQL/n8n data
- Snapshot VM → VM ใหม่จะเป็น clone (data เดิม) ไม่ใช่ fresh instance
- ใน HTTP mode, bootstrap อัปเดต WEBHOOK_URL/N8N_HOST อัตโนมัติเมื่อ IP เปลี่ยน (playbook §1B)
- Port 5678 bound to `127.0.0.1` only — external access ผ่าน nginx port 80 (HTTP) หรือ 443 (HTTPS) เท่านั้น
- `N8N_PROXY_HOPS=1` ทุก mode เพราะ nginx always-on อยู่หน้า n8n เสมอ
- ถ้า `.env` protocol=https แต่ cert หาย → bootstrap fallback to HTTP อัตโนมัติ + แก้ `.env`
- หลัง `n8n-https-disable` cert files ยังอยู่ แต่ bootstrap จะใช้ HTTP config เพราะ `.env` protocol=http

---

## Acceptance Criteria (Wakka ตรวจก่อน snapshot)
- [ ] n8n-bootstrap.service enabled (`systemctl is-enabled n8n-bootstrap.service` = enabled)
- [ ] no secrets on disk (no `.env`, no `n8n-credentials.txt`, no `n8n-bootstrap.log`)
- [ ] Docker stack: no containers running, docker images preserved (n8n, postgres:16, nginx:stable)
- [ ] No Docker volumes left (`docker volume ls --filter label=com.docker.compose.project=n8n` = empty)
- [ ] Static files in /opt/n8n: docker-compose.yml, nginx/n8n-http.conf, nginx/n8n-https.conf, nginx/n8n.conf (= HTTP default)
- [ ] certs/ dir empty (no certs in golden image)
- [ ] Helper scripts present and executable (9 total): n8n-status, n8n-logs, n8n-restart, n8n-upgrade, n8n-rollback, n8n-exec, n8n-https-enable, n8n-cert-status, n8n-https-disable
- [ ] n8n port bind = 127.0.0.1:5678 (not 0.0.0.0:5678) in docker-compose.yml
- [ ] nginx always-on (no profiles in docker-compose.yml)
- [ ] MOTD executable and shows correct fields (Access, Creds, Config, Data, Logs, Helpers, Setup)
- [ ] README present at /root/README-n8n-image.txt
- [ ] nginx active config = HTTP default (`diff n8n.conf n8n-http.conf` = identical)
- [ ] n8n health check responds (tested in Step 6 — `curl -sI http://localhost:80/` returns 200/302)

---

## Record Build Manifest

หลัง pre-capture gate ผ่าน ให้สร้าง/อัปเดต `apps/n8n/n8n-build-manifest.md` ด้วยข้อมูล version ที่ verify จาก golden-image VM เท่านั้น:

```bash
lsb_release -ds
docker version
docker compose version
docker buildx version
dpkg-query -W docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
docker images --digests --format '{{.Repository}}:{{.Tag}} {{.Digest}}'
```

เก็บเฉพาะ Base OS, Docker stack package versions แบบ minimal, Docker/Compose/Buildx versions, container image tag + digest และ build notes สั้นๆ. ห้ามเก็บ image name, Glance ID, server ID, floating IP, VM IP, hostname, OpenStack context หรือ credentials.
