# Ollama + Open WebUI Image — Ubuntu 26.04  [built: standalone; post-test PASS; no-cleanup]
> Image สำเร็จรูป: สร้าง VM → Ollama + Open WebUI พร้อมใช้งาน → เข้า Web UI ได้ทันที พร้อมโมเดล pre-pulled

---

## เป้าหมาย

```text
ลูกค้าสร้าง VM จาก Image
→ systemd เรียก ollama-openwebui-bootstrap.sh
→ start Docker + Ollama + Open WebUI
→ เขียน /root/ollama-openwebui-credentials.txt
→ ลูกค้า SSH เข้า VM อ่าน README/credentials
→ เข้า http://<IP>:3000 สร้างบัญชีแรก → เริ่มแชทกับโมเดลได้เลย
```

| รายการ | ค่า |
|---|---|
| Base OS | Ubuntu 26.04 |
| Docker | Docker CE จาก official Docker apt repo |
| Compose | Docker Compose plugin (`docker compose`) |
| Ollama | `ollama/ollama:latest` (v0.30.10) |
| Open WebUI | `ghcr.io/open-webui/open-webui:main` (v0.9.6) |
| Pre-pulled Models | `gemma3:4b`, `llama3.2:1b` |
| Minimum flavor | 2 vCPU / 8 GB RAM / 30 GB disk |

---

## Customer URLs

| Service | URL | Login |
|---|---|---|
| Open WebUI | `http://<VM-IP>:3000` | สร้างบัญชีแรก → admin |
| Ollama API | `http://127.0.0.1:11434` | internal เท่านั้น |

Security group:
- Public: TCP `3000`
- Admin only: TCP `22`

---

## Design

| เรื่อง | ตัดสินใจ |
|---|---|
| Docker package source | official Docker apt repo, ไม่ใช้ `snap`, ไม่ใช้ Ubuntu `docker.io` |
| Stack pattern | แยก 2 containers (Ollama + Open WebUI) — ไม่ใช้ bundled `:ollama` tag |
| GPU | CPU-only; GPU support เป็น optional สำหรับอนาคต |
| Ollama port binding | `127.0.0.1:11434` — localhost only, Open WebUI เชื่อมผ่าน Docker network |
| Open WebUI port binding | `0.0.0.0:3000` — user เข้าถึงจากภายนอก |
| Models | pre-pull `gemma3:4b` + `llama3.2:1b` ลง volume ก่อน capture |
| Memory management | `OLLAMA_KEEP_ALIVE=5m` — unload โมเดลจาก RAM หลังไม่ใช้ 5 นาที |
| Signup | `ENABLE_SIGNUP=true` (default) — user สร้างบัญชีแรกเอง |
| Docker group | ไม่ auto-add user เพราะ root-equivalent |
| Logging | `json-file` พร้อม `max-size=10m`, `max-file=3` |
| License | Open WebUI custom license — ต้องคง "Open WebUI" brand สำหรับ >50 users; Ollama MIT |
| Golden image | pre-pull Docker images + Ollama models ได้ แต่ห้ามเหลือ containers/volumes/runtime data |

---

## ก่อนเริ่ม — Pre-flight Verification

| เช็ค | ได้จาก | ถ้ายังไม่พร้อม |
|---|---|---|
| Guest image Ubuntu 26.04 สร้างเสร็จแล้ว | `_guest-images.md` → Ubuntu 26.04 เสร็จ | ต้องสร้าง guest image ก่อน |
| VM สร้างจาก guest image ที่ผ่าน Set 1-3 ครบ | standalone build | สร้าง VM จาก guest image |
| Build guide พร้อม `[พร้อม build]` | header tag บน | ต้องสร้าง source files ก่อน |
| SSH credentials | `tmp/ollama-openwebui-build.env` (gitignored) | — |

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
- disk free มากกว่า 15 GB
- RAM อย่างน้อย 8 GB

---

## โครงสร้างไฟล์

```text
/opt/ollama-openwebui/docker-compose.yml
/opt/ollama-openwebui/.env                      (first boot สร้างจริง)
/usr/local/sbin/ollama-openwebui-bootstrap.sh
/etc/systemd/system/ollama-openwebui-bootstrap.service
/root/README-ollama-openwebui-image.txt
/root/ollama-openwebui-credentials.txt          (first boot สร้างจริง)
/etc/update-motd.d/99-ollama-openwebui-image
/etc/docker/daemon.json
```

ไฟล์/สถานะที่ต้องไม่มีใน Golden Image:

```text
/opt/ollama-openwebui/.env
/root/ollama-openwebui-credentials.txt
/var/log/ollama-openwebui-bootstrap.log
/var/lib/ollama-openwebui-firstboot.done
running containers
Docker volumes ollama_models, open-webui_data
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
mkdir -p /opt/ollama-openwebui
chmod 755 /opt/ollama-openwebui
```

### 4. วาง source files

#### `/opt/ollama-openwebui/docker-compose.yml`

[golden-image VM]

```bash
# อัปโหลดไฟล์จาก repository ไปยัง VM: source/docker-compose.yml → /opt/ollama-openwebui/docker-compose.yml

#### `/usr/local/sbin/ollama-openwebui-bootstrap.sh`

[golden-image VM]

```bash
# อัปโหลดไฟล์จาก repository ไปยัง VM: source/ollama-openwebui-bootstrap.sh → /usr/local/sbin/ollama-openwebui-bootstrap.sh
chmod +x /usr/local/sbin/ollama-openwebui-bootstrap.sh

#### `/etc/systemd/system/ollama-openwebui-bootstrap.service`

[golden-image VM]

```bash
# อัปโหลดไฟล์จาก repository ไปยัง VM: source/ollama-openwebui-bootstrap.service → /etc/systemd/system/ollama-openwebui-bootstrap.service

#### `/root/README-ollama-openwebui-image.txt`

[golden-image VM]

```bash
# อัปโหลดไฟล์จาก repository ไปยัง VM: source/README-ollama-openwebui-image.txt → /root/README-ollama-openwebui-image.txt

#### `/etc/update-motd.d/99-ollama-openwebui-image`

[golden-image VM]

```bash
# อัปโหลดไฟล์จาก repository ไปยัง VM: source/99-ollama-openwebui-image → /etc/update-motd.d/99-ollama-openwebui-image
chmod +x /etc/update-motd.d/99-ollama-openwebui-image

### 5. Enable bootstrap service

[golden-image VM]

```bash
systemctl daemon-reload
systemctl enable ollama-openwebui-bootstrap.service
```

### 6. Pre-pull Docker images + Ollama models

[golden-image VM]

> ขั้นตอนนี้ใช้เวลานานเพราะต้อง pull Docker images (~1.4 GB สำหรับ ollama image) และดาวน์โหลด LLM models (~3-5 GB)

```bash
cat > /opt/ollama-openwebui/.env << 'EOF'
TZ=Asia/Bangkok
EOF
chmod 600 /opt/ollama-openwebui/.env

docker compose -f /opt/ollama-openwebui/docker-compose.yml --env-file /opt/ollama-openwebui/.env pull

docker compose -f /opt/ollama-openwebui/docker-compose.yml --env-file /opt/ollama-openwebui/.env up -d ollama

sleep 5

docker exec ollama ollama pull gemma3:4b
docker exec ollama ollama pull llama3.2:1b

docker exec ollama ollama list

docker compose -f /opt/ollama-openwebui/docker-compose.yml --env-file /opt/ollama-openwebui/.env down
```

> หมายเหตุ policy ล่าสุด: golden image ต้องเป็น fresh first boot จึงลบ runtime/model volumes ด้วยใน cleanup (`down -v`). ถ้าต้อง pre-load models ให้ทำเป็นขั้นตอน build ใหม่และ manifest ชัดเจน ไม่เก็บ volume test ค้างข้าม VM.

### 7. Test bootstrap แล้ว Phase 1 app cleanup runtime data

[golden-image VM]

```bash
/usr/local/sbin/ollama-openwebui-bootstrap.sh

docker compose -f /opt/ollama-openwebui/docker-compose.yml --env-file /opt/ollama-openwebui/.env ps

curl -sI http://127.0.0.1:3000 | head -1

curl -s http://127.0.0.1:11434/api/tags | head -20

docker compose -f /opt/ollama-openwebui/docker-compose.yml --env-file /opt/ollama-openwebui/.env down -v

rm -f /opt/ollama-openwebui/.env
rm -f /root/ollama-openwebui-credentials.txt
rm -f /var/log/ollama-openwebui-bootstrap.log
rm -f /var/lib/ollama-openwebui-firstboot.done
docker volume prune -f

ls /opt/ollama-openwebui/.env 2>&1 | grep -q 'No such file' && echo ".env: deleted"
ls /root/ollama-openwebui-credentials.txt 2>&1 | grep -q 'No such file' && echo "credentials: deleted"
ls /var/log/ollama-openwebui-bootstrap.log 2>&1 | grep -q 'No such file' && echo "bootstrap log: deleted"
ls /var/lib/ollama-openwebui-firstboot.done 2>&1 | grep -q 'No such file' && echo "firstboot marker: deleted"
```

> ใช้ `down -v` ลบ volumes ด้วย — user เลือกให้ลบ models/runtime volumes เพื่อให้ golden image เป็น fresh first boot จริง

### 8. Pre-Capture Gate — AI verify after Phase 1

[golden-image VM]

```bash
set -e

systemctl is-enabled ollama-openwebui-bootstrap.service
systemctl is-enabled docker
docker version
docker compose version
docker images ollama/ollama:latest --format '{{.Repository}}:{{.Tag}}' | grep -q '^ollama/ollama:latest$'
docker images ghcr.io/open-webui/open-webui:main --format '{{.Repository}}:{{.Tag}}' | grep -q '^ghcr.io/open-webui/open-webui:main$'

if docker ps -q | grep -q .; then
  echo "ERROR: running containers remain"
  docker ps
  exit 1
fi
echo "containers: stopped"

if docker volume ls --format '{{.Name}}' | grep -qE '^(ollama_models|open-webui_data)$'; then
  echo "ERROR: runtime/model volumes remain"
  exit 1
fi
echo "volumes: absent"

docker exec ollama ollama list 2>/dev/null && echo "WARNING: ollama container should not be running" || true

test ! -e /opt/ollama-openwebui/.env && echo ".env: absent"
test ! -e /root/ollama-openwebui-credentials.txt && echo "credentials: absent"
test ! -e /var/log/ollama-openwebui-bootstrap.log && echo "bootstrap log: absent"
test ! -e /var/lib/ollama-openwebui-firstboot.done && echo "firstboot marker: absent" || { echo "FATAL: firstboot marker still exists — golden image will skip bootstrap on first boot"; exit 1; }
test -f /opt/ollama-openwebui/docker-compose.yml && echo "compose: present"
test -f /root/README-ollama-openwebui-image.txt && echo "README: present"

```

ห้าม capture ถ้า:
- bootstrap service disabled
- Docker service disabled
- required Docker images ไม่ถูก pull ไว้
- containers ยังรัน
- runtime/model volumes ยังอยู่
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
> # execute-command "bash /tmp/verify-phase1.sh ollama-openwebui"
> # Expected: VERIFY:PASS หรือ VERIFY:FAIL <error_tags>
> ```


> ห้าม `apt clean`, `apt autoremove`, `docker image prune -a` เพราะ image นี้ตั้งใจเก็บ package cache และ Docker images ที่ pre-pull ไว้. Runtime/model volumes ต้องถูกลบก่อน capture.

---

## หลังลูกค้าสร้าง VM จาก Image

### อ่าน README

[customer VM]

```bash
cat /root/README-ollama-openwebui-image.txt
cat /root/ollama-openwebui-credentials.txt
```

### ตรวจ services

[customer VM]

```bash
systemctl status docker --no-pager
systemctl status ollama-openwebui-bootstrap.service --no-pager
docker compose -f /opt/ollama-openwebui/docker-compose.yml --env-file /opt/ollama-openwebui/.env ps
```

### ตรวจ models ที่ pre-pulled

[customer VM]

```bash
docker exec ollama ollama list
```

### เข้า Web UI

```text
http://<VM-IP>:3000
```

สร้างบัญชีแรก → กลายเป็น admin → เลือกโมเดลจาก dropdown → เริ่มแชท

### Pull โมเดลเพิ่ม

[customer VM]

```bash
docker exec -it ollama ollama pull qwen2.5:1.5b
docker exec -it ollama ollama pull phi3:3.8b
```

### Disable signup (หลังสร้าง admin แล้ว)

[customer VM]

```bash
sed -i 's/ENABLE_SIGNUP=true/ENABLE_SIGNUP=false/' /opt/ollama-openwebui/.env
docker compose -f /opt/ollama-openwebui/docker-compose.yml --env-file /opt/ollama-openwebui/.env up -d
```

### อัปเดต containers

[customer VM]

```bash
docker compose -f /opt/ollama-openwebui/docker-compose.yml --env-file /opt/ollama-openwebui/.env pull
docker compose -f /opt/ollama-openwebui/docker-compose.yml --env-file /opt/ollama-openwebui/.env up -d
```

---

## Source Files

```text
apps/ollama-openwebui/ollama-openwebui.md
apps/ollama-openwebui/docs/ollama-openwebui-review.md
apps/ollama-openwebui/docs/ollama-openwebui-errors.md
apps/ollama-openwebui/source/docker-compose.yml
apps/ollama-openwebui/source/ollama-openwebui-bootstrap.sh
apps/ollama-openwebui/source/ollama-openwebui-bootstrap.service
apps/ollama-openwebui/source/README-ollama-openwebui-image.txt
apps/ollama-openwebui/source/99-ollama-openwebui-image
```

---

## Record Build Manifest

หลัง pre-capture gate ผ่าน ให้สร้าง/อัปเดต `apps/ollama-openwebui/ollama-openwebui-build-manifest.md` ด้วยข้อมูล version ที่ verify จาก golden-image VM เท่านั้น:

```bash
lsb_release -ds
docker version
docker compose version
docker images --digests --format '{{.Repository}}:{{.Tag}} {{.Digest}}'
docker exec ollama ollama --version 2>/dev/null || true
docker exec ollama ollama list 2>/dev/null || true
```

เก็บเฉพาะ Base OS, Docker stack package versions แบบ minimal, Docker/Compose versions, Ollama version, Open WebUI version, container image tag + digest, pre-pulled model list และ build notes สั้นๆ. ห้ามเก็บ image name, Glance ID, server ID, floating IP, VM IP, hostname, OpenStack context หรือ credentials.
