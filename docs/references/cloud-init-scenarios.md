# Cloud-init User Data — ลูกค้าสร้าง VM

> user-data ที่ลูกค้าใส่ตอนสร้าง VM จาก guest image ที่ build แล้ว

---

## กรณีที่ 1 — Password

```yaml
#cloud-config
disable_root: false

chpasswd:
  expire: true
  users:
    - name: root
      password: "CHANGE_ME_TEMP_PASSWORD"
      type: text

runcmd:
  - passwd -u root || true
  - chage -d 0 root || true
  - mkdir -p /etc/ssh/sshd_config.d
  - find /etc/ssh/sshd_config.d -maxdepth 1 -type f -name '*.conf' -delete
  - printf 'PermitRootLogin yes\nPasswordAuthentication yes\nPubkeyAuthentication yes\nKbdInteractiveAuthentication no\nUsePAM yes\n' > /etc/ssh/sshd_config.d/00-image-build.conf
  - systemctl restart ssh || systemctl restart sshd || true
```

Login: `ssh root@<IP>` → ใช้ password ชั่วคราวที่ตั้งไว้ → ระบบบังคับเปลี่ยน password ใหม่

---

## กรณีที่ 2 — Keypair

```yaml
#cloud-config
disable_root: false

chpasswd:
  expire: true
  users:
    - name: root
      password: "CHANGE_ME_TEMP_PASSWORD"
      type: text

ssh_authorized_keys:
  - ssh-rsa AAAAB3NzaC1yc2EAAA...     # ← ใส่ public key จริง

runcmd:
  - passwd -u root || true
  - chage -d 0 root || true
  - mkdir -p /etc/ssh/sshd_config.d
  - find /etc/ssh/sshd_config.d -maxdepth 1 -type f -name '*.conf' -delete
  - printf 'PermitRootLogin yes\nPasswordAuthentication no\nPubkeyAuthentication yes\nKbdInteractiveAuthentication no\nUsePAM yes\n' > /etc/ssh/sshd_config.d/00-image-build.conf
  - systemctl restart ssh || systemctl restart sshd || true
```

Login: `ssh -i <private_key> root@<IP>` → ใช้ key auth และ password ชั่วคราวสำหรับบังคับเปลี่ยน password

---

## กรณีที่ 3 — Password (ไม่บังคับเปลี่ยน)

```yaml
#cloud-config
disable_root: false

chpasswd:
  expire: false
  users:
    - name: root
      password: "YOUR_ROOT_PASSWORD"
      type: text

runcmd:
  - mkdir -p /etc/ssh/sshd_config.d
  - find /etc/ssh/sshd_config.d -maxdepth 1 -type f -name '*.conf' -delete
  - printf 'PermitRootLogin yes\nPasswordAuthentication yes\nPubkeyAuthentication yes\nKbdInteractiveAuthentication no\nUsePAM yes\n' > /etc/ssh/sshd_config.d/00-image-build.conf
  - systemctl restart ssh || systemctl restart sshd || true
```

Login: `ssh root@<IP>` → ใส่ password ที่ตั้ง → เข้าได้เลย ไม่บังคับเปลี่ยน

---

## ความต่าง

| | Password | Keypair | Password (ไม่บังคับเปลี่ยน) |
|---|---|---|---|
| `PasswordAuthentication` | `yes` | `no` | `yes` |
| `PubkeyAuthentication` | `yes` | `yes` | `yes` |
| `ssh_authorized_keys` | ไม่มี | มี | ไม่มี |
| login ด้วย | password | key เท่านั้น | password |
| บังคับเปลี่ยน password | ✅ | ✅ | ❌ |
| `expire` | `true` | `true` | `false` |

---

## ⚠️ สำคัญ: ทำไมต้อง `find ... -delete` ก่อนเขียน config

Ubuntu 26.04 base image มีไฟล์ใน `/etc/ssh/sshd_config.d/` (เช่น `50-cloud-init.conf`) ที่อาจตั้ง `PasswordAuthentication no` — sshd อ่านไฟล์ตามลำดับตัวอักษร ไฟล์ที่ชื่อทีหลัง override ไฟล์ก่อนหน้า

**ถ้าไม่ลบไฟล์เก่าก่อน:**
- `00-image-build.conf` → `PasswordAuthentication yes` ✅
- `50-cloud-init.conf` → `PasswordAuthentication no` ❌ (override!)

→ ผลลัพธ์: `PasswordAuthentication no` — SSH password login ไม่ได้

**วิธีแก้ที่ถูกต้อง:**
```yaml
runcmd:
  - find /etc/ssh/sshd_config.d -maxdepth 1 -type f -name '*.conf' -delete  # ← ลบไฟล์เก่าทั้งหมดก่อน
  - printf 'PermitRootLogin yes\nPasswordAuthentication yes\n...' > /etc/ssh/sshd_config.d/00-image-build.conf
```

**Golden image ควรลบ sshd_config.d ทั้งหมดตอน cleanup** เพื่อให้ cloud-init เริ่มจาก slate สะอาด
