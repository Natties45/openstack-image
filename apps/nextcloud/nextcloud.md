# Nextcloud Image — Ubuntu 26.04  [built: production-korry-gate2; customer-service]
> Image สำเร็จรูป: สร้าง VM → auto-install → เปิด browser ใช้งานได้เลย, ใช้ IP ก่อน และเพิ่ม domain/HTTPS ภายหลัง

---

## เป้าหมาย

```text
ลูกค้าสร้าง VM จาก Image
→ systemd เรียก nextcloud-bootstrap.sh
→ detect IP/hostname → update trusted_domains
→ สุ่ม PostgreSQL password + admin password สำหรับ VM นั้น
→ สร้าง /opt/nextcloud/.env + /root/nextcloud-credentials.txt
→ docker compose up -d จาก Docker images ที่ pre-pull ไว้ใน golden image
→ เปิด http://<IP> ใช้งานได้เลย (admin pre-created, password สุ่ม)
```

| โหมด | รายละเอียด |
|---|---|
| HTTP | พร้อมใช้ทันที `http://<IP>` |
| Domain | เพิ่มภายหลังด้วย `occ config:system:set trusted_domains` |
| HTTPS | วาง cert/key เองที่ `/opt/nextcloud/certs/`, แล้วเปิด profile `https` |

## Rebuild Decision Baseline

| เรื่อง | ตัดสินใจ |
|---|---|
| Install flow | **Auto-install** ให้เสร็จตอน first boot |
| Admin user | `admin` |
| Admin password | สุ่มต่อ VM แล้วเก็บใน `/root/nextcloud-credentials.txt` (`chmod 600`) |
| Runtime data | Bind mount ที่ `/var/lib/nextcloud/` เพื่อให้เห็น data จริงใน VM และย้ายไป attached volume ง่าย |
| First boot internet | **ไม่พึ่ง internet 100%** — ห้าม `docker compose pull` ตอน runtime |
| Docker image pinning | Pin patch/minor ให้แน่นขึ้น ไม่ใช้ tag ลอยกว้าง |
| HTTPS | User วาง cert เองที่ `/opt/nextcloud/certs/fullchain.pem` และ `privkey.pem` |
| Backup | มีคู่มือก่อน ยังไม่เพิ่ม backup script |

> สถานะปัจจุบัน: source เดิมยังต้องปรับให้ครบตาม baseline นี้ก่อน rebuild/capture รอบใหม่

---

## ก่อนเริ่ม — Pre-flight Verification

> **ก่อน SSH เข้า VM** — image build เป็น standalone workflow ใช้ temp env ใต้ `tmp/` และลบทิ้งหลังจบงาน

| เช็ค | ได้จาก | ถ้ายังไม่พร้อม |
|---|---|---|
| Guest image Ubuntu 26.04 สร้างเสร็จแล้ว | `_guest-images.md` → Ubuntu 26.04 ✅ เสร็จ | ต้องสร้าง guest image ก่อน |
| VM สร้างจาก guest image ที่ผ่าน Set 1-3 ครบ | `tmp/nextcloud-build.env` หรือ output ที่ user ส่งมา | สร้าง VM จาก guest image |
| Build guide พร้อม `[รอ rebuild]` | header tag บน | ต้องปรับ source/docs ให้ตรง baseline นี้ก่อน build |
| SSH/OpenStack credentials | `tmp/nextcloud-build.env` | เติมเฉพาะตอน build แล้วลบทิ้ง |

**เมื่อ SSH เข้า VM แล้ว — verify บน VM:**

```bash
lsb_release -a | grep Release          # ต้อง: 26.04 หรือ codename "resolute"
grep URIs /etc/apt/sources.list.d/ubuntu.sources  # ต้อง: mirrors.openlandscape.cloud หรือ mirror1.ku.ac.th
curl -sI https://download.docker.com | head -1    # ต้อง: HTTP/2 200
df -h /                                   # ต้อง: Avail > 5G
```

---

## โครงสร้างไฟล์

```text
/opt/nextcloud/docker-compose.yml
/opt/nextcloud/nginx/default.conf
/opt/nextcloud/nginx/default-https.conf
/opt/nextcloud/certs/                         (ว่าง — รอวาง cert)
/etc/nextcloud-image/image.conf               (metadata, no secret)
/usr/local/sbin/nextcloud-bootstrap.sh
/etc/systemd/system/nextcloud-bootstrap.service
/root/README-nextcloud-image.txt
/etc/update-motd.d/99-nextcloud-image

/var/lib/nextcloud/app/                       (Nextcloud app/data bind mount)
/var/lib/nextcloud/db/                        (PostgreSQL data bind mount)
/var/lib/nextcloud/redis/                     (Redis data bind mount)
```

แนวคิด path:

| Path | ใช้ทำอะไร | แก้บ่อยไหม |
|---|---|---|
| `/opt/nextcloud/` | compose/config/control files | บางครั้ง |
| `/var/lib/nextcloud/` | runtime data จริงทั้งหมด | ไม่ควรแก้ตรงถ้าไม่จำเป็น |
| `/root/nextcloud-credentials.txt` | admin/DB credentials ของ VM นั้น | อ่านเมื่อจำเป็น, ห้าม dump ลง repo/chat |
| `/etc/nextcloud-image/` | metadata ของ image ไม่มี secret | ใช้ช่วย debug |

ไฟล์ที่ต้องไม่มีใน Golden Image:
```text
/opt/nextcloud/.env
/root/nextcloud-credentials.txt
/var/log/nextcloud-bootstrap.log
Docker volumes
/var/lib/nextcloud/* runtime data จาก test
Docker containers จาก test
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

### 3. สร้าง directory

[golden-image VM]

```bash
mkdir -p /opt/nextcloud/{nginx,certs} /etc/nextcloud-image /var/lib/nextcloud/{app,db,redis}
chmod 700 /opt/nextcloud/certs
```

### 4. คัดลอกไฟล์ static

> **Reference:** Source files อยู่ใน `apps/nextcloud/` — ใช้ตรวจสอบหรือ copy โดยตรงก็ได้

ไฟล์ที่ต้องวางบน VM ก่อน build image:
- `docker-compose.yml` → `/opt/nextcloud/docker-compose.yml`
- `nginx/default.conf` → `/opt/nextcloud/nginx/default.conf`
- `nginx/default-https.conf` → `/opt/nextcloud/nginx/default-https.conf`
- `nextcloud-bootstrap.sh` → `/usr/local/sbin/nextcloud-bootstrap.sh` (chmod +x)
- `nextcloud-bootstrap.service` → `/etc/systemd/system/nextcloud-bootstrap.service`
- `README-nextcloud-image.txt` → `/root/README-nextcloud-image.txt`
- `99-nextcloud-image` → `/etc/update-motd.d/99-nextcloud-image` (chmod +x)
- `image.conf` → `/etc/nextcloud-image/image.conf` (no secret)

**docker-compose.yml** และการตั้งค่าอื่นๆ จะถูกดึงจากโฟลเดอร์ `source/` โดยตรง:
- `source/docker-compose.yml` → `/opt/nextcloud/docker-compose.yml`
- `source/nginx/default.conf` → `/opt/nextcloud/nginx/default.conf`
- `source/nginx/default-https.conf` → `/opt/nextcloud/nginx/default-https.conf`
- `source/nextcloud-bootstrap.sh` → `/usr/local/sbin/nextcloud-bootstrap.sh` (ต้องทำ `chmod +x`)
- `source/nextcloud-bootstrap.service` → `/etc/systemd/system/nextcloud-bootstrap.service`
- `source/README-nextcloud-image.txt` → `/root/README-nextcloud-image.txt`
- `source/image.conf` → `/etc/nextcloud-image/image.conf`
- `source/99-nextcloud-image` → `/etc/update-motd.d/99-nextcloud-image` (ต้องทำ `chmod +x`)

สามารถดูรายละเอียดของไฟล์ควบคุมและการตั้งค่าจริงได้ในไดเรกทอรี `source/` ของชุด Repository นี้

### 5. เปิด systemd service

[golden-image VM]

```bash
systemctl daemon-reload
systemctl enable nextcloud-bootstrap.service

# ⚠️ ต้อง verify ว่า enable สำเร็จ — ถ้า disabled snapshot จะไม่ทำงาน!
systemctl is-enabled nextcloud-bootstrap.service
# ต้องได้ output: enabled
```

### 6. Pre-pull images + ทดสอบ bootstrap

[golden-image VM]

```bash
# Pre-pull images — ทำไว้ก่อน snapshot
# ประโยชน์: VM ที่สร้างจาก image boot ครั้งแรกได้โดยไม่พึ่ง internet
# ห้ามลบ images ตอน cleanup!
docker pull postgres:16.9
docker pull redis:7.4-alpine
docker pull nextcloud:30.0-apache
docker pull nginx:1.27-alpine

# ทดสอบ bootstrap (จะสร้าง .env, start services)
# ถ้าสำเร็จจะเห็น: Bootstrap: done และ occ status ต้อง installed: true
/usr/local/sbin/nextcloud-bootstrap.sh
```

### 7. Phase 1 — App cleanup ก่อน capture

[golden-image VM]

Runtime files เช่น `.env`, `nextcloud-credentials.txt`, bootstrap log และ `/var/lib/nextcloud/*` เป็น temp data จากการทดสอบ ต้องลบก่อน capture เสมอ เพื่อให้ VM ใหม่ที่สร้างจาก image bootstrap แล้วสร้าง secrets/data ชุดใหม่เอง. AI ต้อง verify ทุกขั้นผ่าน MCP SSH; หลัง Phase 1 ยัง SSH เข้าได้.

```bash
cd /opt/nextcloud

# Stop HTTPS profile (if tested)
docker compose --profile https down --remove-orphans 2>/dev/null

# Stop all services + remove volumes (ไม่ลบ images)
docker compose down -v

# ลบ runtime/temp data ก่อน capture — ห้ามเก็บ secret เข้า image
rm -f /opt/nextcloud/.env /root/nextcloud-credentials.txt /var/log/nextcloud-bootstrap.log
rm -rf /var/lib/nextcloud/app/* /var/lib/nextcloud/db/* /var/lib/nextcloud/redis/*
docker volume prune -f

# ⚠️ ห้ามใช้ docker image prune -a !!!
# เพราะจะลบ pulled images ที่ pre-pull ไว้ — ต้องเก็บไว้ใน image สุดท้าย
```

### 8. Pre-Capture Gate — AI verify after Phase 1

เปลี่ยนเป็น **Pre-Capture Gate หลัง Phase 1**. หลัง gate ผ่าน AI ต้องถาม user ก่อนเข้า Phase 2 เพราะ Phase 2 จะลบ SSH access และ poweroff.

[golden-image VM]

```bash
# 1. ต้องมี service enabled
systemctl is-enabled nextcloud-bootstrap.service
# ต้องได้: enabled (ถ้าได้ disabled → ทำใหม่ที่ข้อ 5)

# 2. ตรวจสอบไฟล์ที่ต้องมี
ls -l /opt/nextcloud/docker-compose.yml
ls -l /opt/nextcloud/nginx/default.conf
ls -l /opt/nextcloud/nginx/default-https.conf
ls -l /usr/local/sbin/nextcloud-bootstrap.sh
ls -l /root/README-nextcloud-image.txt
ls -l /etc/update-motd.d/99-nextcloud-image
ls -l /etc/nextcloud-image/image.conf

# 3. ตรวจสอบว่า containers ไม่มีรันอยู่
docker compose -f /opt/nextcloud/docker-compose.yml ps
# ต้องไม่มี container แสดง

# 4. ตรวจสอบ Docker images ที่ pre-pull ไว้ (ต้องยังอยู่)
docker images | grep -E "postgres|redis|nextcloud|nginx"
# ต้องเห็น: postgres:16.9, redis:7.4-alpine, nextcloud:30.0-apache, nginx:1.27-alpine

# 5. ตรวจสอบว่าไม่มี .env หรือ credentials
ls -la /opt/nextcloud/.env 2>/dev/null || echo ".env: ไม่มี (ถูกต้อง)"
ls -la /root/nextcloud-credentials.txt 2>/dev/null || echo "credentials: ไม่มี (ถูกต้อง)"

# 6. ตรวจสอบว่าไม่มี volumes จาก test bootstrap
if docker volume ls --format '{{.Name}}' | grep -qi nextcloud; then
  echo "ERROR: runtime volumes remain"
  exit 1
fi
echo "volumes: ไม่มี (ถูกต้อง)"

```

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
ubuntu-26.04-nextcloud-30-YYYYMMDD
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
> # execute-command "bash /tmp/verify-phase1.sh nextcloud"
> # Expected: VERIFY:PASS หรือ VERIFY:FAIL <error_tags>
> ```


> **AI verify — 1-shot verify script:** ใช้ `docs/references/verify-phase1-template.sh` — upload + run ครั้งเดียว แทน 10 คำสั่งแยก
> ```bash
> # AI execution pattern (ไม่ใช่ manual step):
> # upload --localPath "docs/references/verify-phase1-template.sh" --remotePath "/tmp/verify-phase1.sh"
> # cleanup commands (ข้างบน)
> # execute-command "bash /tmp/verify-phase1.sh nextcloud"
> ```


---

## Bootstrap Logic

| สถานะ | พฤติกรรม |
|---|---|
| VM ใหม่ (ไม่มี `.env`) | ตรวจทุก IP (`get_all_ips`) → สุ่ม secrets แบบ alphanumeric → สร้าง .env + credentials → start |
| Reboot (มี `.env` แล้ว) | ใช้ค่าเดิม, start containers, **append IP ใหม่** ถ้ามี (ไม่ลบ IP เก่า) |
| ลูกค้าถอด/เปลี่ยน IP | IP เก่าคงอยู่, IP ใหม่ถูกเพิ่ม — ไม่มีผลต่อการเข้าใช้งาน |
| ลูกค้าเพิ่ม domain เอง | bootstrap ใช้อ่าน trusted_domains จาก occ → ไม่แตะ entries ที่มีอยู่แล้ว |
| ก่อน capture image | ต้องลบ `.env`, `nextcloud-credentials.txt`, bootstrap log, และ volumes |
| VM ใหม่จาก image ที่ cleanup แล้ว | bootstrap สร้าง `.env` + credentials ชุดใหม่ตอน boot ครั้งแรก |
| Snapshot VM ที่ใช้งานแล้ว | clone data เดิม — ไม่ใช่ golden image fresh boot |
| HTTPS | วาง cert + `docker compose --profile https up -d` |

---

## วิธีเปิด HTTPS

### ขั้นตอน

1. ชี้ DNS ไป Floating IP
2. วาง cert: `/opt/nextcloud/certs/fullchain.pem`, `/opt/nextcloud/certs/privkey.pem`
3. `[nextcloud-vm]` `chmod 644 /opt/nextcloud/certs/fullchain.pem && chmod 600 /opt/nextcloud/certs/privkey.pem`
4. เปิด HTTPS:
   ```bash
   cd /opt/nextcloud
   docker compose --profile https up -d
   ```
5. ตรวจสอบ:
   ```bash
   curl -sI https://yourdomain.com | head -1
   # HTTP/2 200
   ```

> Nextcloud รู้จัก HTTPS อัตโนมัติผ่าน `X-Forwarded-Proto` จาก nginx → ไม่ต้องแก้ config หรือ DB

### ได้ Certificate จากไหน

| วิธี | เหมาะกับ | ขั้นตอน |
|---|---|---|
| **ซื้อ cert** | องค์กร, ต้องการ trusted CA | ซื้อจาก DigiCert, GoDaddy, Namecheap ฯลฯ |
| **Let's Encrypt (แนะนำ)** | ทุกคน — ฟรี, trusted | `certbot certonly --manual -d yourdomain.com` |
| **Cert จากองค์กร** | มี wildcard cert อยู่แล้ว | copy cert ไปวางที่ `certs/` |

### Let's Encrypt วิธีทำ (manual, optional)

```bash
# 1. ติดตั้ง certbot
apt install certbot

# 2. ขอ cert (ต้องมี DNS ชี้มาที่ IP แล้ว)
certbot certonly --manual -d yourdomain.com --preferred-challenges dns

# 3. จะได้ไฟล์ 2 ไฟล์:
#   /etc/letsencrypt/live/yourdomain.com/fullchain.pem
#   /etc/letsencrypt/live/yourdomain.com/privkey.pem

# 4. copy ไปวาง
cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem /opt/nextcloud/certs/
cp /etc/letsencrypt/live/yourdomain.com/privkey.pem /opt/nextcloud/certs/

# 5. ทำขั้นตอน 3-5 ข้างบนได้เลย
```

### Auto-renew Let's Encrypt (optional)

> รอบ rebuild นี้ยังไม่ใส่ certbot helper เป็น default ใน image; ถ้าต้องการ auto-renew ให้ user ทำเพิ่มเองหลังมี domain/HTTPS พร้อมแล้ว

```bash
# สร้าง renew script
cat > /usr/local/sbin/nc-cert-renew.sh << 'EOF'
#!/bin/bash
certbot renew --quiet --deploy-hook "docker compose -f /opt/nextcloud/docker-compose.yml restart nginx-https"
EOF
chmod +x /usr/local/sbin/nc-cert-renew.sh

# เพิ่ม cron job (ทุกวันเช้า 03:00)
echo "0 3 * * * /usr/local/sbin/nc-cert-renew.sh" >> /etc/crontab
```

---

## Backup & Restore

### Backup

```bash
# Backup database
cd /opt/nextcloud
docker compose exec db pg_dump -U nextcloud nextcloud > nc-db-backup-$(date +%Y%m%d).sql

# Backup runtime data ทั้งหมด
tar czf nc-data-backup-$(date +%Y%m%d).tar.gz -C /var/lib nextcloud

# Backup config/control files แบบไม่เปิด secret ใน chat/repo
tar czf nc-config-backup-$(date +%Y%m%d).tar.gz -C /opt nextcloud
```

### Restore

```bash
# Restore database
cd /opt/nextcloud
docker compose exec -T db psql -U nextcloud nextcloud < nc-db-backup-YYYYMMDD.sql

# Restore data
tar xzf nc-data-backup-YYYYMMDD.tar.gz -C /var/lib
docker compose restart
```

---

## Upgrade Nextcloud

```bash
cd /opt/nextcloud

# Put in maintenance mode
docker compose exec -u33 nextcloud ./occ maintenance:mode --on

# Pull new image
docker compose pull nextcloud

# Restart with new image
docker compose up -d

# Turn off maintenance mode
docker compose exec -u33 nextcloud ./occ maintenance:mode --off
```

---

## ข้อควรระวัง

- `/opt/nextcloud/.env` มี password — ห้ามลบหลังใช้งานแล้ว
- ห้ามลบ `/var/lib/nextcloud` บนเครื่องลูกค้า — เป็น data จริงทั้งหมด
- ถ้าจะย้ายไป attached volume ให้ stop containers, rsync `/var/lib/nextcloud/`, แล้ว mount volume ใหม่ที่ path เดิม `/var/lib/nextcloud`
- ถ้าสลับระหว่าง HTTP ↔ HTTPS ต้อง `docker compose stop nginx` ก่อนเปลี่ยน profile
- Snapshot VM → VM ใหม่เป็น clone (data เดิม) ไม่ใช่ fresh instance
- SMTP → ใช้ Nextcloud Mail SMTP plugin ตั้งค่า SMTP ภายนอก
- หลังแก้ config ใดๆ → restart ทั้ง stack เสมอ (`docker compose restart`) ไม่ใช่แค่ container เดียว
- ถ้า trusted_domains ไม่ถูกต้อง → เปิดเว็บไม่ได้ → bootstrap รีเฟรชอัตโนมัติตอน reboot; แก้ manual: `NEXTCLOUD_TRUSTED_DOMAINS` ใน `.env` แล้ว `docker compose restart nextcloud`
- ⚠️ **ทุก `docker compose` command ต้อง `--profile http`** — nginx อยู่ใน profile ถ้าใช้ `docker compose down/restart` โดยไม่มี `--profile http` → nginx ไม่ถูก manage → port 80 ถูกจอง → container ใหม่ล้มเหลว

---

## Admin Password Reset

### วิธี 1: `occ` (แนะนำ)

```bash
cd /opt/nextcloud
docker compose exec -u33 nextcloud ./occ user:resetpassword admin
# ใส่ password ใหม่
```

### วิธี 2: ผ่าน Web UI

1. เปิด `http://<IP>/login`
2. กด "Forgot password?"
3. ใส่ admin username → ส่ง reset link ไป email (ต้องตั้ง SMTP ก่อน)

## Glance Image Properties

| Property | ค่า |
|---|---|
| ชื่อ | `ubuntu-26.04-nextcloud-30-YYYYMMDD` |
| OS distro | `ubuntu` |
| OS version | `26.04` |
| Architecture | `x86_64` |
| Min disk | `20 GB` |
| Min RAM | `2048 MB` |
| Image type | `app` |
| Tags | `nextcloud, file-sharing, docker, postgresql, redis` |

---

## Record Build Manifest

หลัง pre-capture gate ผ่าน ให้สร้าง/อัปเดต `apps/nextcloud/nextcloud-build-manifest.md` ด้วยข้อมูล version ที่ verify จาก golden-image VM เท่านั้น:

```bash
lsb_release -ds
docker version
docker compose version
docker buildx version
dpkg-query -W docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
docker images --digests --format '{{.Repository}}:{{.Tag}} {{.Digest}}'
```

เก็บเฉพาะ Base OS, Docker stack package versions แบบ minimal, Docker/Compose/Buildx versions, container image tag + digest และ build notes สั้นๆ. ห้ามเก็บ image name, Glance ID, server ID, floating IP, VM IP, hostname, OpenStack context หรือ credentials.
