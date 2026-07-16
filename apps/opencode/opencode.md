# OpenCode AI Coding Agent Build Guide — Ubuntu 26.04  [พร้อม build; test-dev-tool]

คู่มือฉบับย่อสำหรับการสร้าง Golden Image OpenCode บน Ubuntu 26.04 (อ้างอิงไฟล์ source ทั้งหมดจาก repository)

---

## 1. การเตรียมระบบ (Host OS)

รันคำสั่งเหล่านี้เพื่ออัปเกรดระบบและติดตั้ง dependencies พื้นฐาน:

```bash
# ติดตั้ง base packages
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release openssl unzip file

# กำหนด Cloud-init OpenStack config
mkdir -p /etc/cloud/cloud.cfg.d
cat > /etc/cloud/cloud.cfg.d/99-openstack-imagebuild.cfg << 'EOF'
disable_root: false
preserve_hostname: false
manage_etc_hosts: true
datasource_list: [ConfigDrive, OpenStack, None]
EOF

# ปิดการรัน apt auto-updates และ MOTD news
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer \
  apt-daily.service apt-daily-upgrade.service \
  unattended-upgrades.service 2>/dev/null || true
echo 'ENABLED=0' > /etc/default/motd-news 2>/dev/null || true
```

---

## 2. การสร้างผู้ใช้ดาวน์โหลด Binary และเขียนไฟล์ระบบ

สร้างผู้ใช้เฉพาะสำหรับรันเซอร์วิสเพื่อความปลอดภัย:

```bash
useradd -r -m -d /home/opencode -s /bin/bash opencode
mkdir -p /home/opencode/.local/share/opencode /home/opencode/.cache/opencode /home/opencode/.config/opencode
chown -R opencode:opencode /home/opencode
```

ดาวน์โหลดและแตกไฟล์ OpenCode Standalone Binary:

```bash
OP_VERSION="1.17.9"
DOWNLOAD_URL="https://github.com/anomalyco/opencode/releases/download/v${OP_VERSION}/opencode-linux-x64.tar.gz"

cd /tmp
curl -fsSL -o opencode.tar.gz "$DOWNLOAD_URL"
tar xzf opencode.tar.gz
cp opencode /usr/local/bin/opencode
chmod +x /usr/local/bin/opencode
rm -f opencode opencode.tar.gz
```

คัดลอกไฟล์ระบบจาก repository ไปวางตามพาธต่อไปนี้บน VM:

| Source File (in repo) | Target Path (on VM) | Mode / Permissions | Note |
|---|---|---|---|
| `source/opencode.json` | `/home/opencode/.config/opencode/opencode.json` | `644` | OpenCode config (autoupdate: false) |
| `source/xdg-open` | `/usr/local/bin/xdg-open` | `755` (executable) | fake no-op script for headless |
| `source/opencode-bootstrap.sh` | `/usr/local/sbin/opencode-bootstrap.sh` | `755` (executable) | first-boot logic script |
| `source/opencode-bootstrap.service` | `/etc/systemd/system/opencode-bootstrap.service` | `644` | systemd oneshot unit |
| `source/opencode.service` | `/etc/systemd/system/opencode.service` | `644` | systemd service for web daemon |
| `source/README-opencode-image.txt` | `/root/README-opencode-image.txt` | `600` | user guide on VM |
| `source/99-opencode-image` | `/etc/update-motd.d/99-opencode-image` | `755` (executable) | SSH login MOTD |

ตั้งค่าสิทธิ์ความเป็นเจ้าของและเปิดการใช้งาน systemd services:

```bash
chown opencode:opencode /home/opencode/.config/opencode/opencode.json
systemctl daemon-reload
systemctl enable opencode-bootstrap.service
```

---

## 3. การล้างข้อมูล (App Cleanup) ก่อนทำ Snapshot (Phase 1)

ก่อนทำการ capture ต้องเคลียร์สถานะชั่วคราวและรหัสผ่านจากการทดสอบออกทั้งหมด:

```bash
systemctl stop opencode.service 2>/dev/null || true
systemctl disable opencode.service 2>/dev/null || true
rm -f /etc/opencode/environment
rm -f /etc/opencode/.bootstrapped
rm -f /root/opencode-credentials.txt
rm -f /var/log/opencode-bootstrap.log
rm -rf /home/opencode/.local/share/opencode 2>/dev/null || true
rm -rf /home/opencode/.cache/opencode 2>/dev/null || true
```

---

## 4. การเคลียร์ OS (OS Cleanup) ก่อน capture (Phase 2)

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
