# AnythingLLM Image Build Guide — Ubuntu 26.04  [built: standalone; personal-use]

คู่มือฉบับย่อสำหรับการสร้าง Golden Image AnythingLLM บน Ubuntu 26.04 (อ้างอิงไฟล์ source ทั้งหมดจาก repository)

---

## 1. การเตรียมระบบ (Host OS)

รันคำสั่งเหล่านี้เพื่อติดตั้งและกำหนดค่า Docker บนโฮสต์:

```bash
# ติดตั้ง base packages
apt update && apt install -y ca-certificates curl gnupg openssl jq vim htop net-tools

# ติดตั้ง Docker CE
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" > /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
```

---

## 2. โครงสร้างโฟลเดอร์และการวางไฟล์

สร้างโฟลเดอร์สำหรับเก็บข้อมูล AnythingLLM บน VM:

```bash
mkdir -p /opt/anythingllm
```

คัดลอกไฟล์ทั้งหมดจาก repository ไปวางตามพาธต่อไปนี้บน VM:

| Source File (in repo) | Target Path (on VM) | Mode / Permissions | Note |
|---|---|---|---|
| `source/docker-compose.yml` | `/opt/anythingllm/docker-compose.yml` | `600` | docker compose configuration |
| `source/nginx.conf` | `/opt/anythingllm/nginx.conf` | `600` | nginx configuration with upload limits |
| `source/anythingllm-bootstrap.sh` | `/usr/local/sbin/anythingllm-bootstrap.sh` | `755` (executable) | first-boot logic script |
| `source/anythingllm-bootstrap.service` | `/etc/systemd/system/anythingllm-bootstrap.service` | `644` | systemd oneshot unit |
| `helpers/anythingllm-reset-password.sh` | `/usr/local/sbin/anythingllm-reset-password.sh` | `755` (executable) | password reset helper script |
| `source/README-anythingllm-image.txt` | `/root/README-anythingllm-image.txt` | `600` | user guide on VM |
| `source/99-anythingllm-image` | `/etc/update-motd.d/99-anythingllm-image` | `755` (executable) | SSH login MOTD |

ตั้งค่าสิทธิ์ความเป็นเจ้าของ, ลิงก์ และเปิดการใช้งาน systemd service:

```bash
chmod 600 /opt/anythingllm/docker-compose.yml /opt/anythingllm/nginx.conf
ln -sf /usr/local/sbin/anythingllm-reset-password.sh /usr/local/sbin/anythingllm-reset-password
systemctl daemon-reload
systemctl enable anythingllm-bootstrap.service
```

---

## 3. การเตรียม Image & Pull Container ล่วงหน้า

รันคำสั่งเหล่านี้เพื่อดาวน์โหลด Docker Images มาเก็บไว้สำหรับ Offline-safety:

```bash
cd /opt/anythingllm
# ดึง image ล่วงหน้า
docker compose pull
```

---

## 4. การล้างข้อมูล (App Cleanup) ก่อนทำ Snapshot (Phase 1)

```bash
cd /opt/anythingllm
docker compose down -v
rm -f /opt/anythingllm/.env
rm -f /opt/anythingllm/.env.bak
rm -f /root/anythingllm-credentials.txt
rm -f /var/log/anythingllm-bootstrap.log
docker volume rm anythingllm_anythingllm_data 2>/dev/null || true
docker volume rm anythingllm_data 2>/dev/null || true
```

---

## 5. การเคลียร์ OS (OS Cleanup) ก่อน capture (Phase 2)

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
