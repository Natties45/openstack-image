# Docker Platform Image — Ubuntu 26.04  [พร้อม build; personal-use]
> Image สำเร็จรูป: สร้าง VM → Docker CE + Portainer + Nginx Proxy Manager พร้อมใช้ → ลูกค้าอ่าน credentials ใน VM แล้วเข้า Web UI ได้ทันที

---

## เป้าหมาย

```text
ลูกค้าสร้าง VM จาก Image
→ systemd เรียก docker-platform-bootstrap.sh
→ สุ่ม Portainer admin password และ Nginx Proxy Manager password
→ start Docker + Portainer + Nginx Proxy Manager
→ เขียน /root/docker-platform-credentials.txt
→ ลูกค้า SSH เข้า VM อ่าน README/credentials
→ เข้า https://<IP>:9443 และ http://<IP>:81 ใช้งานได้เลย
```

| รายการ | ค่า |
|---|---|
| Base OS | Ubuntu 26.04 |
| Docker | Docker CE จาก official Docker apt repo |
| Compose | Docker Compose plugin (`docker compose`) |
| Build tool | Docker Buildx plugin |
| Container UI | Portainer CE LTS |
| Domain/HTTPS UI | Nginx Proxy Manager |
| Minimum flavor | 1 vCPU / 2GB RAM / 15GB disk |

---

## Customer URLs

| Service | URL | Login |
|---|---|---|
| Portainer CE | `https://<VM-IP>:9443` | `/root/docker-platform-credentials.txt` |
| Nginx Proxy Manager | `http://<VM-IP>:81` | `/root/docker-platform-credentials.txt` |
| Public HTTP gateway | `http://<VM-IP>` | NPM proxy hosts |
| Public HTTPS gateway | `https://<VM-IP>` | NPM proxy hosts |

Security group:
- Public: TCP `80`, `443`
- Admin only: TCP `22`, `81`, `9443`

---

## Design

| เรื่อง | ตัดสินใจ |
|---|---|
| Docker package source | official Docker apt repo, ไม่ใช้ `snap`, ไม่ใช้ Ubuntu `docker.io` |
| Portainer | start ตอน first boot, bootstrap สุ่ม admin password ผ่าน API |
| Nginx Proxy Manager | start ตอน first boot, bootstrap พยายามเปลี่ยน default password ผ่าน API |
| Database | ให้ examples/templates, ไม่ start default |
| Docker group | ไม่ auto-add user เพราะ root-equivalent |
| Logging | `json-file` พร้อม `max-size=10m`, `max-file=3` |
| Golden image | pre-pull images ได้ แต่ห้ามเหลือ containers/volumes/runtime data |

---

## ก่อนเริ่ม — Pre-flight Verification

| เช็ค | ได้จาก | ถ้ายังไม่พร้อม |
|---|---|---|
| Guest image Ubuntu 26.04 สร้างเสร็จแล้ว | `_guest-images.md` → Ubuntu 26.04 เสร็จ | ต้องสร้าง guest image ก่อน |
| VM สร้างจาก guest image ที่ผ่าน Set 1-3 ครบ | standalone build | สร้าง VM จาก guest image |
| Build guide พร้อม `[พร้อม build]` | header tag บน | ต้องสร้าง source files ก่อน |
| SSH credentials | `tmp/docker-platform-build.env` (gitignored) | — |

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
- Ubuntu 26.04 หรือ codename ที่ตรงกับ guide
- DNS ออก internet ได้
- disk free มากกว่า 5GB
- RAM อย่างน้อย 2GB

---

## โครงสร้างไฟล์

```text
/opt/docker-platform/docker-compose.yml
/opt/docker-platform/.env                         (first boot สร้างจริง)
/opt/docker-platform/examples/postgres/docker-compose.yml
/opt/docker-platform/examples/mariadb/docker-compose.yml
/opt/docker-platform/examples/redis/docker-compose.yml
/opt/docker-platform/examples/nginx-demo/docker-compose.yml
/usr/local/sbin/docker-platform-bootstrap.sh
/etc/systemd/system/docker-platform-bootstrap.service
/root/README-docker-platform-image.txt
/root/docker-platform-credentials.txt             (first boot สร้างจริง)
/etc/update-motd.d/99-docker-platform-image
/etc/docker/daemon.json
```

ไฟล์/สถานะที่ต้องไม่มีใน Golden Image:

```text
/opt/docker-platform/.env
/root/docker-platform-credentials.txt
/var/log/docker-platform-bootstrap.log
/var/lib/docker-platform-firstboot.done
running containers
Docker volumes portainer_data, npm_data, npm_letsencrypt
runtime credentials
```

---

## ขั้นตอน Build

### 1. ติดตั้ง base packages

[golden-image VM]

```bash
apt update && apt install -y ca-certificates curl gnupg openssl jq vim htop net-tools
```

### 2. ติดตั้ง Docker CE + plugins

[golden-image VM]

```bash
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
# อัปโหลดไฟล์จาก repository ไปยัง VM: source/docker.sources → /etc/apt/sources.list.d/docker.sources
# (หมายเหตุ: สคริปต์อัตโนมัติจะประเมินและตั้งค่า Suites/Architectures ให้ตรงกับ OS ของ VM)
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
```

### 2.5 Configure Docker log rotation

[golden-image VM]

```bash
mkdir -p /etc/docker
# อัปโหลดไฟล์จาก repository ไปยัง VM: source/daemon.json → /etc/docker/daemon.json
systemctl restart docker
```

### 3. สร้าง directories

[golden-image VM]

```bash
mkdir -p /opt/docker-platform/examples/{postgres,mariadb,redis,nginx-demo}
chmod 755 /opt/docker-platform
```

### 4. วาง source files

#### `/opt/docker-platform/docker-compose.yml`

[golden-image VM]

```bash
# อัปโหลดไฟล์จาก repository ไปยัง VM: source/docker-compose.yml → /opt/docker-platform/docker-compose.yml
```

#### `/usr/local/sbin/docker-platform-bootstrap.sh`

[golden-image VM]

```bash
# อัปโหลดไฟล์จาก repository ไปยัง VM: source/docker-platform-bootstrap.sh → /usr/local/sbin/docker-platform-bootstrap.sh
chmod +x /usr/local/sbin/docker-platform-bootstrap.sh
```

#### `/etc/systemd/system/docker-platform-bootstrap.service`

[golden-image VM]

```bash
# อัปโหลดไฟล์จาก repository ไปยัง VM: source/docker-platform-bootstrap.service → /etc/systemd/system/docker-platform-bootstrap.service
```

#### `/root/README-docker-platform-image.txt`

[golden-image VM]

```bash
# อัปโหลดไฟล์จาก repository ไปยัง VM: source/README-docker-platform-image.txt → /root/README-docker-platform-image.txt
```

#### `/etc/update-motd.d/99-docker-platform-image`

[golden-image VM]

```bash
# อัปโหลดไฟล์จาก repository ไปยัง VM: source/99-docker-platform-image → /etc/update-motd.d/99-docker-platform-image
chmod +x /etc/update-motd.d/99-docker-platform-image
```

### 5. วาง example templates

[golden-image VM]

```bash
# อัปโหลดตัวอย่างการรันฐานข้อมูล/แอปพลิเคชันจาก repository ไปยัง VM:
# - examples/postgres/docker-compose.yml → /opt/docker-platform/examples/postgres/docker-compose.yml
# - examples/mariadb/docker-compose.yml → /opt/docker-platform/examples/mariadb/docker-compose.yml
# - examples/redis/docker-compose.yml → /opt/docker-platform/examples/redis/docker-compose.yml
# - examples/nginx-demo/docker-compose.yml → /opt/docker-platform/examples/nginx-demo/docker-compose.yml
```

### 6. Enable bootstrap service

[golden-image VM]

```bash
systemctl daemon-reload
systemctl enable docker-platform-bootstrap.service
```

### 7. Pre-pull images

[golden-image VM]

```bash
cat > /opt/docker-platform/.env << 'EOF'
TZ=Asia/Bangkok
EOF
chmod 600 /opt/docker-platform/.env

docker compose -f /opt/docker-platform/docker-compose.yml --env-file /opt/docker-platform/.env pull
docker pull hello-world:latest
docker pull postgres:17-alpine
docker pull mariadb:lts
docker pull redis:7-alpine
docker pull nginx:stable-alpine
```

### 8. Test bootstrap แล้ว Phase 1 app cleanup runtime data

[golden-image VM]

```bash
/usr/local/sbin/docker-platform-bootstrap.sh
docker compose -f /opt/docker-platform/docker-compose.yml --env-file /opt/docker-platform/.env ps
curl -k -sI https://127.0.0.1:9443 | head -1
curl -sI http://127.0.0.1:81 | head -1

docker compose -f /opt/docker-platform/docker-compose.yml --env-file /opt/docker-platform/.env down -v
rm -f /opt/docker-platform/.env
rm -f /root/docker-platform-credentials.txt
rm -f /var/log/docker-platform-bootstrap.log
rm -f /var/lib/docker-platform-firstboot.done
```

> ต้องใช้ `down -v` เฉพาะตอน cleanup golden image เพื่อไม่ให้ Portainer/NPM runtime data จาก test ติดไปใน image

### 9. Pre-Capture Gate — AI verify after Phase 1

[golden-image VM]

```bash
set -e

systemctl is-enabled docker-platform-bootstrap.service
systemctl is-enabled docker
docker version
docker compose version
docker images portainer/portainer-ce:lts --format '{{.Repository}}:{{.Tag}}' | grep -q '^portainer/portainer-ce:lts$'
docker images jc21/nginx-proxy-manager:latest --format '{{.Repository}}:{{.Tag}}' | grep -q '^jc21/nginx-proxy-manager:latest$'
docker images postgres:17-alpine --format '{{.Repository}}:{{.Tag}}' | grep -q '^postgres:17-alpine$'
docker images mariadb:lts --format '{{.Repository}}:{{.Tag}}' | grep -q '^mariadb:lts$'
docker images redis:7-alpine --format '{{.Repository}}:{{.Tag}}' | grep -q '^redis:7-alpine$'
docker images nginx:stable-alpine --format '{{.Repository}}:{{.Tag}}' | grep -q '^nginx:stable-alpine$'

if docker ps -q | grep -q .; then
  echo "ERROR: running containers remain"
  docker ps
  exit 1
fi
echo "containers: stopped"

if docker volume ls --format '{{.Name}}' | grep -E '^(portainer_data|npm_data|npm_letsencrypt)$'; then
  echo "ERROR: runtime volumes remain"
  exit 1
fi
echo "volumes: absent"

test ! -e /opt/docker-platform/.env && echo ".env: absent"
test ! -e /root/docker-platform-credentials.txt && echo "credentials: absent"
test ! -e /var/log/docker-platform-bootstrap.log && echo "bootstrap log: absent"
test ! -e /var/lib/docker-platform-firstboot.done && echo "firstboot marker: absent"
test -f /opt/docker-platform/docker-compose.yml && echo "compose: present"
test -f /root/README-docker-platform-image.txt && echo "README: present"
```

ห้าม capture ถ้า:
- bootstrap service disabled
- Docker service disabled
- required images ไม่ถูก pull ไว้
- containers ยังรัน
- runtime volumes ยังอยู่
- `.env`, credentials, first boot marker, bootstrap log ยังอยู่

AI ต้องถาม user ก่อน Phase 2 เพราะ Phase 2 จะลบ SSH access และ poweroff.

### 10. Phase 2 — OS cleanup + poweroff (final)

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
> # execute-command "bash /tmp/verify-phase1.sh docker-platform"
> # Expected: VERIFY:PASS หรือ VERIFY:FAIL <error_tags>
> ```


> ห้าม `apt clean`, `apt autoremove`, `docker image prune -a` เพราะ image นี้ตั้งใจเก็บ package cache และ Docker images ที่ pre-pull ไว้

---

## หลังลูกค้าสร้าง VM จาก Image

### อ่าน credentials

[customer VM]

```bash
cat /root/README-docker-platform-image.txt
cat /root/docker-platform-credentials.txt
```

### ตรวจ services

[customer VM]

```bash
systemctl status docker --no-pager
systemctl status docker-platform-bootstrap.service --no-pager
docker compose -f /opt/docker-platform/docker-compose.yml --env-file /opt/docker-platform/.env ps
```

### เข้า Web UI

```text
Portainer CE: https://<VM-IP>:9443
Nginx Proxy Manager: http://<VM-IP>:81
```

### ใช้ Nginx Proxy Manager ขอ HTTPS

1. ชี้ DNS เช่น `app.example.com` ไปที่ floating IP ของ VM
2. เข้า NPM `http://<VM-IP>:81`
3. Add Proxy Host
4. ใส่ Domain Names: `app.example.com`
5. ใส่ Forward Hostname/IP: ชื่อ container หรือ IP/port ภายใน
6. ไป tab SSL แล้วกด Request a new SSL Certificate
7. เปิด `https://app.example.com`

---

## Source Files

```text
apps/docker-platform/docker-platform.md
apps/docker-platform/docs/docker-platform-review.md
apps/docker-platform/docs/docker-platform-errors.md
apps/docker-platform/source/docker-compose.yml
apps/docker-platform/source/docker-platform-bootstrap.sh
apps/docker-platform/source/docker-platform-bootstrap.service
apps/docker-platform/source/README-docker-platform-image.txt
apps/docker-platform/source/99-docker-platform-image
apps/docker-platform/examples/postgres/docker-compose.yml
apps/docker-platform/examples/mariadb/docker-compose.yml
apps/docker-platform/examples/redis/docker-compose.yml
apps/docker-platform/examples/nginx-demo/docker-compose.yml
```

---

## Record Build Manifest

หลัง pre-capture gate ผ่าน ให้สร้าง/อัปเดต `apps/docker-platform/docker-platform-build-manifest.md` ด้วยข้อมูล version ที่ verify จาก golden-image VM เท่านั้น:

```bash
lsb_release -ds
docker version
docker compose version
docker buildx version
dpkg-query -W docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
docker images --digests --format '{{.Repository}}:{{.Tag}} {{.Digest}}'
```

เก็บเฉพาะ Base OS, Docker stack package versions แบบ minimal, Docker/Compose/Buildx versions, container image tag + digest และ build notes สั้นๆ. ห้ามเก็บ image name, Glance ID, server ID, floating IP, VM IP, hostname, OpenStack context หรือ credentials.
