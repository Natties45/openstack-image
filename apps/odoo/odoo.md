# Odoo Image Build Guide — Ubuntu 26.04  [พร้อม build; customer-service]

คู่มือฉบับย่อสำหรับการสร้าง Golden Image Odoo 18 บน Ubuntu 26.04 (อ้างอิงไฟล์ source ทั้งหมดจาก repository)

---

## 1. การเตรียมระบบ (Host OS)

รันคำสั่งเหล่านี้เพื่อเตรียม Ubuntu 26.04 VM ก่อนเริ่มประกอบระบบ:

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

# กำหนด Docker log rotation
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

---

## 2. โครงสร้างโฟลเดอร์และการวางไฟล์

สร้างโฟลเดอร์สำหรับ Odoo บนโฮสต์:

```bash
mkdir -p /opt/odoo/{nginx,config,addons,certs,backups}
chmod 700 /opt/odoo/certs /opt/odoo/backups
```

คัดลอกไฟล์จาก repository ไปวางตามพาธต่อไปนี้บน VM:

| Source File (in repo) | Target Path (on VM) | Mode / Permissions | Note |
|---|---|---|---|
| `source/docker-compose.yml` | `/opt/odoo/docker-compose.yml` | `600` | docker compose configuration |
| `source/nginx/default.conf` | `/opt/odoo/nginx/default.conf` | `644` | nginx HTTP config |
| `source/nginx/default-https.conf` | `/opt/odoo/nginx/default-https.conf` | `644` | nginx HTTPS config |
| `source/odoo-bootstrap.sh` | `/usr/local/sbin/odoo-bootstrap.sh` | `755` (executable) | first-boot logic script |
| `helpers/odoo-tune-workers.sh` | `/usr/local/sbin/odoo-tune-workers.sh` | `755` (executable) | memory/CPU worker tuner |
| `helpers/odoo-backup.sh` | `/usr/local/sbin/odoo-backup.sh` | `755` (executable) | database + filestore backup |
| `source/odoo-bootstrap.service` | `/etc/systemd/system/odoo-bootstrap.service` | `644` | systemd oneshot unit |
| `source/README-odoo-image.txt` | `/root/README-odoo-image.txt` | `600` | user guide on VM |
| `source/99-odoo-image` | `/etc/update-motd.d/99-odoo-image` | `755` (executable) | SSH login MOTD |

หลังวางไฟล์ระบบ ให้เปิดการทำงานของ systemd service:

```bash
systemctl daemon-reload
systemctl enable odoo-bootstrap.service
```

---

## 3. การเตรียม Image & Pull Container ล่วงหน้า

รันคำสั่งเหล่านี้เพื่อดึง Docker Images มาเตรียมไว้สำหรับ Offline-safety:

```bash
cd /opt/odoo
# สร้าง .env ชั่วคราวเพื่อรัน pull
cat > .env << 'EOF'
POSTGRES_DB=odoo_prod
POSTGRES_USER=odoo
POSTGRES_PASSWORD=temp
ODOO_MASTER_PASSWORD=temp
ODOO_ADMIN_LOGIN=admin
ODOO_ADMIN_PASSWORD=temp
EOF
docker compose pull
rm -f .env
```

---

## 4. การล้างข้อมูล (App Cleanup) ก่อนทำ Snapshot (Phase 1)

หลังจากเสร็จสิ้นการทดสอบการบูตครั้งแรก ให้ล้างข้อมูลทั้งหมดเพื่อให้ VM ที่ถูกสร้างใหม่สุ่มรหัสผ่านใหม่:

```bash
cd /opt/odoo
docker compose --profile https down --volumes --remove-orphans 2>/dev/null || true
docker compose down --volumes --remove-orphans
rm -f /opt/odoo/.env
rm -f /opt/odoo/config/odoo.conf
rm -f /root/odoo-credentials.txt
rm -f /var/log/odoo-bootstrap.log
rm -f /opt/odoo/worker-sizing.txt
rm -f /opt/odoo/certs/fullchain.pem /opt/odoo/certs/privkey.pem
docker volume prune -f
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
