# Guest Images — Build Pipeline

> **Version:** 2026-07-16
> **ใช้กับ:** OpenStack Lab — สร้าง guest image พื้นฐานสำหรับให้ลูกค้าสร้าง VM (9 OS)

---

## OS Comparison

| เรื่อง | AlmaLinux 10 | Debian 13 | Fedora 44 | Rocky 10 | Ubuntu 24.04 | Ubuntu 26.04 |
|---|---|---|---|---|---|---|
| Pkg manager | `dnf` | `apt` | `dnf5` | `dnf` | `apt` | `apt` |
| SSH service | `sshd` | `ssh` | `sshd` | `sshd` | `ssh` | `ssh` |
| Default user | `almalinux` | `debian` | `fedora` | — | `ubuntu` | `ubuntu` |
| Firewall | — | `ufw` | — | — | `ufw` | `ufw` |
| SELinux | Enforcing | — | Enforcing | Enforcing | — | — |
| `/var/lib/dbus/machine-id` | ไม่มี | มี → `ln -sf` | ไม่มี | ไม่มี | มี → `ln -sf` | มี → `ln -sf` |
| Locale pre-set | ไม่ | ไม่ | ใช่ | ไม่ | ไม่ | ไม่ |
| Kernel cleanup | `rpm -qa kernel-core` | `dpkg-query linux-image-*` | `rpm -qa kernel-core` | `rpm -qa kernel-core` | `dpkg-query linux-image-*` | `dpkg-query linux-image-*` |
| MOTD news | — | disable | — | — | disable | disable |

### OS เพิ่มเติม

| เรื่อง | CentOS Stream 10 | Oracle Linux 9 | openSUSE Leap 16.0 |
|---|---|---|---|
| Pkg manager | `dnf` | `dnf` | `zypper` |
| SSH service | `sshd` | `sshd` | `sshd` |
| Default user | `cloud-user` | `opc` | `root` |
| Firewall | `firewalld` | `firewalld` | `firewalld` |
| SELinux | Enforcing | Enforcing | — (AppArmor) |
| `/var/lib/dbus/machine-id` | ไม่มี | ไม่มี | มี → `ln -sf` |
| Locale pre-set | ไม่ | ไม่ | ใช่ |
| Kernel cleanup | `rpm -qa kernel-core` | `rpm -qa kernel-core` | `rpm -qa kernel-default` |
| MOTD news | — | — | — |

---

## Cloud-init Phase A — ใส่ตอนสร้าง VM

ใช้เหมือนกันทุก OS:

```yaml
#cloud-config
disable_root: false

chpasswd:
  expire: false
  users:
    - name: root
      password: "CHANGE_ME_TEMP_PASSWORD"
      type: text

runcmd:
  - passwd -u root || true
  - chage -d -1 root || true
  - mkdir -p /etc/ssh/sshd_config.d
  - printf 'PermitRootLogin yes\nPasswordAuthentication yes\nPubkeyAuthentication yes\nKbdInteractiveAuthentication no\nUsePAM yes\n' > /etc/ssh/sshd_config.d/00-image-build.conf
  - systemctl restart ssh || systemctl restart sshd || true
```

---

## Mirror Configuration — เปลี่ยนเป็น mirror ไทย

> **หลักการ:** cloud-init ใน Ubuntu cloud image จะ rewrite `/etc/apt/sources.list.d/ubuntu.sources` ทุกครั้งที่ VM เกิดใหม่ → ต้องฝัง cloud-init config ให้ VM ใหม่ใช้ mirror ไทยอัตโนมัติ
>
> **Mirror policy:** Ubuntu 26.04 ใช้ `mirrors.openlandscape.cloud/ubuntu/` (first priority) — Ubuntu 24.04 ใช้ `mirror1.ku.ac.th/ubuntu/`
>
> **Source of truth:** mirror ปัจจุบันดูที่ `docs/references/mirrors.md`

### ขั้นตอน (ทำใน golden image VM ก่อน capture)

**1. เปลี่ยน mirror ทันที (สำหรับ session ปัจจุบัน)**

[golden-image VM]

```bash
# เช็คก่อนเปลี่ยน
grep -n 'URIs' /etc/apt/sources.list.d/ubuntu.sources

# เปลี่ยน primary + security → mirror ไทย
# Ubuntu 24.04: mirror1.ku.ac.th
# Ubuntu 26.04: mirrors.openlandscape.cloud (first priority)
MIRROR="mirror1.ku.ac.th"   # เปลี่ยนเป็น mirrors.openlandscape.cloud สำหรับ 26.04
sudo sed -i \
  -e "s|http://nova.clouds.archive.ubuntu.com/ubuntu/|http://${MIRROR}/ubuntu/|g" \
  -e "s|http://security.ubuntu.com/ubuntu|http://${MIRROR}/ubuntu/|g" \
  /etc/apt/sources.list.d/ubuntu.sources

# verify
grep -n 'URIs' /etc/apt/sources.list.d/ubuntu.sources
sudo apt update
```

**2. ฝัง cloud-init config (ให้ VM ใหม่ใช้ mirror ไทยตลอดไป)**

[golden-image VM]

```bash
MIRROR="mirror1.ku.ac.th"   # เปลี่ยนเป็น mirrors.openlandscape.cloud สำหรับ 26.04
sudo tee /etc/cloud/cloud.cfg.d/99-thai-mirror.cfg > /dev/null << EOF
apt:
  primary:
    - arches: [default]
      uri: http://${MIRROR}/ubuntu/
  security:
    - arches: [default]
      uri: http://${MIRROR}/ubuntu/
EOF

cat /etc/cloud/cloud.cfg.d/99-thai-mirror.cfg   # verify
```

### OS อื่น

| OS | Mirror URL | cloud-init config ไฟล์ |
|---|---|---|
| Ubuntu 26.04 | `http://mirrors.openlandscape.cloud/ubuntu/` | ✅ `99-thai-mirror.cfg` (sed `.sources` + cloud-init) |
| Ubuntu 24.04 | `http://mirror1.ku.ac.th/ubuntu/` | ✅ `99-thai-mirror.cfg` (sed `.sources` + cloud-init) |
| Debian 13 | `http://mirror1.ku.ac.th/debian/` (primary) + `/debian-security/` (security) | `mirror+file://` → overwrite `/etc/apt/mirrors/` + `99-thai-mirror.cfg` |
| AlmaLinux 10 | `http://mirror1.ku.ac.th/almalinux/` | ไม่ต้อง cloud-init — `sed` ใน `/etc/yum.repos.d/*.repo` |
| Rocky 10 | `http://mirror1.ku.ac.th/rocky-linux/` | ไม่ต้อง cloud-init — `sed` ใน `/etc/yum.repos.d/*.repo` |
| CentOS Stream 10 | `http://mirror1.ku.ac.th/centos-stream/` (ต้อง verify) | ไม่ต้อง cloud-init — `sed` ใน `/etc/yum.repos.d/centos*.repo` |
| Oracle Linux 9 | `http://mirror1.ku.ac.th/oracle-linux/` (ต้อง verify) | ไม่ต้อง cloud-init — `sed` ใน `/etc/yum.repos.d/oraclelinux*.repo` |
| openSUSE Leap 16.0 | `http://mirror1.ku.ac.th/opensuse/` (ต้อง verify) | ไม่ต้อง cloud-init — `zypper mr` + `zypper ar` |
| Fedora 44 | ไม่มี mirror ไทย — ใช้ metalink (default) | — |

---

## Set 1 — หลังสร้าง VM เสร็จ (upgrade)

**RPM-based (Alma, Rocky, Fedora, CentOS Stream, Oracle):**
```bash
cloud-init status --wait
dnf clean all && dnf -y makecache
dnf -y upgrade --refresh                             # Alma/Rocky/CentOS/Oracle
# dnf5 -y upgrade --refresh                          # Fedora 44
```

**openSUSE Leap (zypper):**
```bash
cloud-init status --wait
zypper --non-interactive update
```

**DEB-based (Debian, Ubuntu):**
```bash
cloud-init status --wait
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
```

> หลังเสร็จ → **reboot จาก host**: `openstack server reboot <SERVER_ID>`

---

## Set 2 — หลัง reboot เสร็จ (configure)

```bash
# ── Kernel cleanup (เหลือ 2 ตัวล่าสุด) ─────────────────────
# RPM (Alma/Rocky/CentOS/Oracle):
mapfile -t KERNELS < <(rpm -qa kernel-core | sort -V)
COUNT=${#KERNELS[@]}
if (( COUNT >= 3 )); then
  TO_REMOVE=("${KERNELS[@]:0:$((COUNT-2))}")
  dnf remove -y "${TO_REMOVE[@]}"                    # Alma/Rocky/CentOS/Oracle
  # dnf5 remove -y "${TO_REMOVE[@]}"                 # Fedora
fi

# DEB:
mapfile -t KERNELS < <(dpkg-query -W -f='${Package}\n' 'linux-image-[0-9]*' | sort -V)
COUNT=${#KERNELS[@]}
if (( COUNT >= 3 )); then
  TO_REMOVE=("${KERNELS[@]:0:$((COUNT-2))}")
  DEBIAN_FRONTEND=noninteractive apt-get purge -y "${TO_REMOVE[@]}"
  apt-get autoremove -y
fi

# ── Locale + Timezone ──────────────────────────────────────
localectl set-locale LANG=en_US.UTF-8                 # ทุก OS (Fedora ข้ามได้)
locale-gen en_US.UTF-8                                # เฉพาะ Debian/Ubuntu
timedatectl set-timezone Asia/Bangkok

# ── Cloud-init OpenStack config ────────────────────────────
mkdir -p /etc/cloud/cloud.cfg.d
cat > /etc/cloud/cloud.cfg.d/99-openstack-imagebuild.cfg << 'EOF'
disable_root: false
preserve_hostname: false
manage_etc_hosts: true
datasource_list: [ConfigDrive, OpenStack, None]
EOF

# ── Disable auto-updates ───────────────────────────────────
systemctl disable --now dnf-automatic.timer 2>/dev/null || true     # RPM
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer \
  apt-daily.service apt-daily-upgrade.service \
  unattended-upgrades.service 2>/dev/null || true                    # DEB

# ── Growpart verify ────────────────────────────────────────
which growpart || echo "WARNING: growpart not found"

# ── Disable firewall ───────────────────────────────────────
systemctl disable --now firewalld.service 2>/dev/null || true       # RPM
systemctl disable --now ufw.service 2>/dev/null || true             # DEB

# ── SELinux relabel (RPM เท่านั้น) ─────────────────────────
restorecon -Rv /etc/ssh/ /etc/cloud/

# ── SSH Policy ─────────────────────────────────────────────
find /etc/ssh/sshd_config.d -maxdepth 1 -type f -name '*.conf' -delete
printf 'PermitRootLogin yes\nPasswordAuthentication yes\nPubkeyAuthentication yes\nKbdInteractiveAuthentication no\nUsePAM yes\n' \
  > /etc/ssh/sshd_config.d/00-image-build.conf
sshd -t && systemctl restart sshd                       # Alma/Rocky/Fedora
# sshd -t && systemctl restart ssh                      # Debian/Ubuntu

# ── Per-instance script (copy authorized_keys → root) ────
mkdir -p /var/lib/cloud/scripts/per-instance
cat > /var/lib/cloud/scripts/per-instance/10-root-authorized-keys.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
install -d -m 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
for f in /home/*/.ssh/authorized_keys; do
  [ -f "$f" ] || continue
  cat "$f" >> /root/.ssh/authorized_keys
  break
done
sort -u /root/.ssh/authorized_keys -o /root/.ssh/authorized_keys || true
EOF
chmod +x /var/lib/cloud/scripts/per-instance/10-root-authorized-keys.sh

# ── Enable services ────────────────────────────────────────
systemctl enable --now qemu-guest-agent 2>/dev/null || true
systemctl enable sshd                                  # Alma/Rocky/Fedora
# systemctl enable ssh                                 # Debian/Ubuntu

# ── Disable MOTD news (Debian/Ubuntu เท่านั้น) ────────────
echo 'ENABLED=0' > /etc/default/motd-news 2>/dev/null || true

# ── Validate ───────────────────────────────────────────────
echo "=== SSH Policy ===" && sshd -T | grep -Ei 'permitrootlogin|passwordauthentication|pubkeyauthentication'
echo "=== Timezone ===" && timedatectl | grep "Time zone"
echo "=== Locale ===" && localectl | grep "System Locale"
echo "=== Kernel count ===" && rpm -qa kernel-core | sort -V
echo "=== Per-instance script ===" && ls -la /var/lib/cloud/scripts/per-instance/
echo "=== 00-image-build.conf ===" && cat /etc/ssh/sshd_config.d/00-image-build.conf
echo "=== datasource config ===" && cat /etc/cloud/cloud.cfg.d/99-openstack-imagebuild.cfg
echo "=== Cloud-init status ===" && cloud-init status
```

---

## Set 3 — Phase 2 OS Cleanup ก่อน capture

> ใช้เป็น final cleanup เท่านั้น. สำหรับ app images ต้องทำ Phase 1 app cleanup และ pre-capture gate ก่อน แล้วค่อยรัน Set 3/Phase 2.

```bash
# Step 1: Cloud-init clean
cloud-init clean --logs --seed
rm -rf /var/lib/cloud/instances/* /var/lib/cloud/instance /var/lib/cloud/sem/*

# Step 2: Remove netplan (if any)
rm -f /etc/netplan/50-cloud-init.yaml

# Step 3: Truncate machine-id
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id 2>/dev/null || true     # RPM
ln -sf /etc/machine-id /var/lib/dbus/machine-id 2>/dev/null || true  # DEB/Ubuntu/openSUSE

# Step 4: Remove SSH host keys
rm -f /etc/ssh/ssh_host_*

# Step 5: Clean sshd_config.d (keep 00-image-build.conf)
find /etc/ssh/sshd_config.d -maxdepth 1 -type f -name '*.conf' \
  ! -name '00-image-build.conf' -delete

# Step 6: Clean history / tmp / logs
rm -f /root/.bash_history
rm -f /home/*/.bash_history
history -c
rm -rf /tmp/* /var/tmp/*
find /var/log -type f -name '*.log' -exec truncate -s 0 {} +
truncate -s 0 /var/log/wtmp /var/log/btmp /var/log/lastlog

# Step 7: Remove repo backup (if any)
rm -rf /var/backups/image-build/repos

# Step 8: fstrim + sync
fstrim -av
sync

# Step 9: Remove build-time authorized keys LAST
rm -f /root/.ssh/authorized_keys
rm -f /home/*/.ssh/authorized_keys
```

> หลังเสร็จ → **shutdown จาก host**: `openstack server stop <SERVER_ID>` → รอ SHUTOFF → capture image

---

## Capture Image

```bash
openstack server image create --name "<OS>-guest-YYYYMMDD" <SERVER_ID>
```

---

## Build Verification

| OS | Download | Repo | Config | สถานะ |
|---|---|---|---|---|
| AlmaLinux 10 | ✅ | ✅ | ✅ | ✅ เสร็จ |
| Debian 13 | ✅ | ✅ | ✅ | ✅ เสร็จ |
| Fedora 44 | ✅ | ✅ | ✅ | ✅ เสร็จ |
| Rocky 10 | ✅ | ✅ | ✅ | ✅ เสร็จ |
| Ubuntu 24.04 | ✅ | ✅ | ✅ | ✅ เสร็จ |
| Ubuntu 26.04 | ✅ | ✅ | ✅ | ✅ เสร็จ |
| CentOS Stream 10 | ✅ | ✅ | ✅ | ✅ เสร็จ |
| Oracle Linux 9 | ❌ | ❌ | ❌ | ❌ รอ verify mirror |
| openSUSE Leap 16.0 | ❌ | ❌ | ❌ | ❌ รอ verify mirror |

---

## Per-OS Notes

### AlmaLinux 10
- `dnf` (ไม่ใช่ `dnf5`)
- SELinux Enforcing — ต้อง `restorecon`
- `/var/lib/dbus/machine-id` ไม่มี — ข้าม error ได้

### Rocky 10
- `dnf` (ไม่ใช่ `dnf5`)
- SELinux Enforcing — ต้อง `restorecon`
- `/var/lib/dbus/machine-id` ไม่มี — ข้าม error ได้

### Fedora 44
- `dnf5` (`yum` เป็น symlink ไป `dnf5`)
- SELinux Enforcing — ต้อง `restorecon`
- `/var/lib/dbus/machine-id` ไม่มี — ข้าม error ได้
- Locale ตั้งมาแล้วใน base image — ข้าม `localectl set-locale`
- Mirror: ไม่มี mirror ไทย — ใช้ metalink (default)

### Debian 13
- `apt`, SSH ชื่อ `ssh` (ไม่ใช่ `sshd`)
- ใช้ AppArmor (ไม่ต้อง `restorecon`)
- `/var/lib/dbus/machine-id` มี — ต้อง `ln -sf` ไม่ใช่แค่ลบ
- ต้อง `locale-gen en_US.UTF-8` ก่อน `localectl set-locale`

### Ubuntu 24.04
- `apt`, SSH ชื่อ `ssh` (ไม่ใช่ `sshd`)
- ใช้ AppArmor (ไม่ต้อง `restorecon`)
- `/var/lib/dbus/machine-id` มี — ต้อง `ln -sf`
- ต้อง `locale-gen en_US.UTF-8`
- Mirror: `mirror1.ku.ac.th/ubuntu/`

### Ubuntu 26.04
- Codename: `resolute`
- Pipeline เหมือน Ubuntu 24.04 ทุกอย่าง
- `apt`, SSH ชื่อ `ssh`
- ใช้ AppArmor (ไม่ต้อง `restorecon`)
- `/var/lib/dbus/machine-id` มี — ต้อง `ln -sf`
- Mirror: `mirrors.openlandscape.cloud/ubuntu/` (first priority)

### CentOS Stream 10
- `dnf` (ไม่ใช่ `dnf5`)
- SELinux Enforcing — ต้อง `restorecon`
- `/var/lib/dbus/machine-id` ไม่มี — ข้าม error ได้
- default user: `cloud-user`

### Oracle Linux 9
- `dnf` (ไม่ใช่ `dnf5`)
- SELinux Enforcing — ต้อง `restorecon`
- `/var/lib/dbus/machine-id` ไม่มี — ข้าม error ได้
- default user: `opc`
- kernel: UEK หรือ RHCK → `rpm -qa kernel-uek*` หรือ `kernel-core`

### openSUSE Leap 16.0
- `zypper` (ไม่ใช่ dnf/apt)
- SSH ชื่อ `sshd`
- ใช้ AppArmor (ไม่ต้อง `restorecon`)
- `/var/lib/dbus/machine-id` มี — ต้อง `ln -sf`
- Kernel cleanup ใช้ `rpm -qa kernel-default`
- cloud-init ไม่แตะ repo config — `zypper mr` ครั้งเดียวพอ
