# WooCommerce Image Build Guide — Ubuntu 26.04  [พร้อม build; customer-service]

คู่มือฉบับย่อสำหรับการสร้าง Golden Image WooCommerce (WordPress-derived) บน Ubuntu 26.04 (อ้างอิงไฟล์ source ทั้งหมดจาก repository)

---

## 1. การเตรียมระบบ (Host OS)

รันคำสั่งเหล่านี้เพื่อติดตั้งและเตรียมความพร้อมของ Docker บน Ubuntu 26.04:

```bash
# ติดตั้ง base packages
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release openssl

# ติดตั้ง Docker CE
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
```

---

## 2. โครงสร้างโฟลเดอร์และการวางไฟล์

สร้างโครงสร้างโฟลเดอร์บน VM:

```bash
mkdir -p /opt/woocommerce/{nginx,php,certs}
chmod 700 /opt/woocommerce/certs
```

คัดลอกไฟล์จาก repository ไปวางตามพาธต่อไปนี้บน VM:

| Source File (in repo) | Target Path (on VM) | Mode / Permissions | Note |
|---|---|---|---|
| `source/docker-compose.yml` | `/opt/woocommerce/docker-compose.yml` | `600` | docker compose configuration |
| `source/nginx/default.conf` | `/opt/woocommerce/nginx/default.conf` | `644` | nginx HTTP config |
| `source/nginx/default-https.conf` | `/opt/woocommerce/nginx/default-https.conf` | `644` | nginx HTTPS config |
| `source/php/woocommerce.ini` | `/opt/woocommerce/php/woocommerce.ini` | `644` | php settings for WooCommerce |
| `source/woocommerce-bootstrap.sh` | `/usr/local/sbin/woocommerce-bootstrap.sh` | `755` (executable) | first-boot logic script |
| `source/woocommerce-cron.sh` | `/usr/local/sbin/woocommerce-cron.sh` | `755` (executable) | WP-Cron runner |
| `source/woocommerce-bootstrap.service` | `/etc/systemd/system/woocommerce-bootstrap.service` | `644` | systemd oneshot unit |
| `source/woocommerce-cron.service` | `/etc/systemd/system/woocommerce-cron.service` | `644` | systemd cron script unit |
| `source/woocommerce-cron.timer` | `/etc/systemd/system/woocommerce-cron.timer` | `644` | systemd 5-min timer unit |
| `source/README-woocommerce-image.txt` | `/root/README-woocommerce-image.txt` | `600` | user guide on VM |
| `source/99-woocommerce-image` | `/etc/update-motd.d/99-woocommerce-image` | `755` (executable) | SSH login MOTD |

หลังวางไฟล์ระบบ ให้เปิดการทำงานของ systemd service & timer:

```bash
systemctl daemon-reload
systemctl enable woocommerce-bootstrap.service
systemctl enable woocommerce-cron.timer
```

---

## 3. การเตรียม Image & Pull Container ล่วงหน้า

รันคำสั่งเหล่านี้เพื่อดาวน์โหลด Docker Images มาเก็บไว้สำหรับ Offline-safety:

```bash
cd /opt/woocommerce
# สร้าง .env ชั่วคราวสำหรับการ pre-pull
cat > .env << 'EOF'
MYSQL_ROOT_PASSWORD=prepull-only-root
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=prepull-only-user
SITE_URL=http://localhost
EOF
chmod 600 .env
docker compose --profile tools pull
rm -f .env
```

---

## 4. การล้างข้อมูล (App Cleanup) ก่อนทำ Snapshot (Phase 1)

ลบข้อมูลที่ถูกสร้างระหว่างการทดสอบเพื่อความปลอดภัย:

```bash
cd /opt/woocommerce
docker compose down -v
rm -f /opt/woocommerce/.env
rm -f /root/woocommerce-credentials.txt
rm -f /var/log/woocommerce-bootstrap.log /var/log/woocommerce-cron.log
systemctl reset-failed woocommerce-bootstrap.service woocommerce-cron.service || true
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
