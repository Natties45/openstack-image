# LEMP Stack Image Build Guide — Ubuntu 26.04  [built: standalone] [Phase 2 PASS]

คู่มือฉบับย่อสำหรับการสร้าง Golden Image LEMP Stack (Linux + Nginx + PHP-FPM + MariaDB) บน Ubuntu 26.04 (อ้างอิงไฟล์ source ทั้งหมดจาก repository)

---

## 1. การเตรียมระบบ (Host OS)

รันคำสั่งเหล่านี้เพื่อติดตั้งและกำหนดค่า Docker บนโฮสต์:

```bash
# ติดตั้ง base packages
apt update
apt install -y ca-certificates curl gnupg openssl jq vim nano bash-completion htop net-tools

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

# เพิ่มเติม bash tab-completion สำหรับช่วยเหลือ
cat > /etc/profile.d/99-bash-completion.sh << 'EOF'
#!/bin/bash
if [ -n "${BASH_VERSION:-}" ] && ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
EOF
chmod +x /etc/profile.d/99-bash-completion.sh
```

---

## 2. โครงสร้างโฟลเดอร์และการวางไฟล์

สร้างไดเรกทอรีสำหรับ LEMP stack บน VM:

```bash
mkdir -p /opt/lemp/{config/nginx,config/php,certs,images/db,images/nginx,images/php-fpm}
chmod 700 /opt/lemp/certs
```

คัดลอกไฟล์ทั้งหมดจาก repository ไปวางตามพาธต่อไปนี้บน VM:

| Source File (in repo) | Target Path (on VM) | Mode / Permissions | Note |
|---|---|---|---|
| `source/docker-compose.yml` | `/opt/lemp/docker-compose.yml` | `600` | docker compose configuration |
| `source/images/db/Dockerfile` | `/opt/lemp/images/db/Dockerfile` | `644` | MariaDB custom container build |
| `source/images/php-fpm/Dockerfile` | `/opt/lemp/images/php-fpm/Dockerfile` | `644` | PHP-FPM container with extensions |
| `source/images/nginx/Dockerfile` | `/opt/lemp/images/nginx/Dockerfile` | `644` | Nginx custom container build |
| `source/config/nginx/default.conf` | `/opt/lemp/config/nginx/default.conf` | `644` | nginx HTTP routing config |
| `source/config/nginx/default-https.conf` | `/opt/lemp/config/nginx/default-https.conf` | `644` | nginx HTTPS template config |
| `source/config/php/php.ini` | `/opt/lemp/config/php/php.ini` | `644` | php settings (memory, uploads) |
| `source/lemp-bootstrap.sh` | `/usr/local/sbin/lemp-bootstrap.sh` | `755` (executable) | first-boot logic script |
| `source/lemp-bootstrap.service` | `/etc/systemd/system/lemp-bootstrap.service` | `644` | systemd oneshot unit |
| `source/99-lemp-image` | `/etc/update-motd.d/99-lemp-image` | `755` (executable) | SSH login MOTD |
| `helpers/lemp-status` | `/usr/local/bin/lemp-status` | `755` (executable) | alias command: compose status |
| `helpers/lemp-logs` | `/usr/local/bin/lemp-logs` | `755` (executable) | alias command: compose logs |
| `helpers/lemp-restart` | `/usr/local/bin/lemp-restart` | `755` (executable) | alias command: compose restart |
| `helpers/lemp-shell` | `/usr/local/bin/lemp-shell` | `755` (executable) | alias command: bash into php container |
| `helpers/lemp-db` | `/usr/local/bin/lemp-db` | `755` (executable) | alias command: db shell client |

หลังจากวางไฟล์ระบบเรียบร้อย ให้เปิดระบบ systemd service:

```bash
systemctl daemon-reload
systemctl enable lemp-bootstrap.service
```

---

## 3. การ Build Local Container Images ล่วงหน้า (Offline-Safety)

รันคำสั่งเหล่านี้เพื่อสร้าง Docker images ไว้ในระบบล่วงหน้า:

```bash
cd /opt/lemp
# สร้าง .env ชั่วคราวสำหรับการ build เท่านั้น
TMP_BUILD_PASSWORD=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32)
cat > /opt/lemp/.env << 'EOF'
MARIADB_DATABASE=lempdb
MARIADB_USER=lempuser
EOF
printf 'MARIADB_ROOT_PASSWORD=%s\nMARIADB_PASSWORD=%s\n' "$TMP_BUILD_PASSWORD" "$TMP_BUILD_PASSWORD" >> /opt/lemp/.env

# เริ่มรัน build images ในเครื่อง
docker compose --profile http build --pull
# ลบไฟล์สภาพแวดล้อมชั่วคราวออก
rm -f /opt/lemp/.env
unset TMP_BUILD_PASSWORD
```

---

## 4. การล้างข้อมูล (App Cleanup) ก่อนทำ Snapshot (Phase 1)

```bash
cd /opt/lemp
docker compose --profile https down --remove-orphans 2>/dev/null || true
docker compose --profile http down -v --remove-orphans
rm -f /opt/lemp/.env /root/lemp-credentials.txt /var/log/lemp-bootstrap.log
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
rm -f /root/.bash_history
rm -f /home/*/.bash_history
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