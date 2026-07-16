# Thai Mirrors — OS Package Repositories

> **Version:** 2026-05-29
> **ใช้กับ:** เลือก mirror ในไทย สำหรับ build image / update guest VM — ลด inter bandwidth

---

## Mirrors ที่ตรวจสอบแล้ว

| Mirror | ผู้ดูแล | สถานะ |
|---|---|---|
| `mirrors.openlandscape.cloud` | — (proxy ไป mirror.kku.ac.th) | ✅ Active |
| `mirror1.ku.ac.th` | ม.เกษตรศาสตร์ | ✅ Active |
| `mirror.kku.ac.th` | ม.ขอนแก่น | ✅ Active |
| `mirrors.bangmod.cloud` | Bangmod | ✅ Active |
| `mirror.psu.ac.th` | ม.สงขลานครินทร์ | ✅ Active |
| `mirrors.cloudforest.co.th` | CLOUDFOREST | ✅ Active |
| `mirrors.ruk-com.cloud` | Ruk-Com Cloud | ❌ Expired |

---

## เปรียบเทียบ: mirrors.openlandscape.cloud vs mirror1.ku.ac.th

### Ubuntu

| Version | Codename | openlandscape.cloud | mirror1.ku.ac.th |
|---|---|---|---|
| 14.04 | trusty | ✅ | ✅ |
| 16.04 | xenial | ✅ | ✅ |
| 20.04 | focal | ✅ | ✅ |
| 22.04 | jammy | ✅ | ✅ |
| 24.04 (LTS) | noble | ✅ | ✅ |
| 26.04 (LTS) | resolute | ✅ | ✅ |

### Debian

| Version | Codename | openlandscape.cloud | mirror1.ku.ac.th |
|---|---|---|---|
| 9 | stretch | ❌ | ❌ |
| 10 | buster | ❌ | ❌ |
| 11 | bullseye | ✅ (Debian11.11) | ✅ (Debian11.11) |
| 12 | bookworm | ✅ (Debian12.14) | ✅ (Debian12.14) |
| 13 | trixie | ✅ (Debian13.5) | ✅ (Debian13.5) |

> Debian 9-10 ไป archive แล้ว ไม่มี mirror ไหนในไทย carry — ต้องใช้ `archive.debian.org`

### Fedora

| Version | openlandscape.cloud | mirror1.ku.ac.th |
|---|---|---|
| 26 | — | — |
| 28 | — | — |
| 30 | — | — |
| 36 | — | — |
| 37 | — | — |
| 41 | — | — |
| 42 | — | — |
| 44 | — | — |

> Fedora ใช้ official Fedora MirrorManager — ไม่มี mirror ในไทยเลย (query `country=TH` ได้ 0 result)
> Mirror ใกล้สุด: SG, TW, JP, KR

### CentOS

| Version | openlandscape.cloud | mirror1.ku.ac.th |
|---|---|---|
| 6 | ✅ (centos/6.10) | ✅ (centos/6.10) |
| 7 | ✅ (centos/7.9.2009) | ✅ (centos/7.9.2009) |
| 8 | ✅ (centos/8.5.2111) | ✅ (centos/8.5.2111) |
| 9 | ✅ (centos-stream/9-stream) | ✅ (centos-stream/9-stream) |
| 10 | ✅ (centos-stream/10-stream) | ✅ (centos-stream/10-stream) |

> CentOS 9, 10 มีเฉพาะ CentOS Stream

### AlmaLinux

| Version | openlandscape.cloud | mirror1.ku.ac.th |
|---|---|---|
| 8 | ✅ (8.10) | ✅ (8.10) |
| 9 | ✅ (9.8) | ✅ (9.8) |
| 10 | ✅ (10.2) | ✅ (10.2) |

### Rocky Linux

| Version | openlandscape.cloud | mirror1.ku.ac.th |
|---|---|---|
| 8 | ✅ 8.10 (sync: **29 May 2025**) | ✅ 8.10 (sync: **21 May 2026**) |
| 9 | ✅ 9.5 (sync: **19 Nov 2024**) | ✅ 9.8 (sync: **26 May 2026**) |
| 10 | ❌ **เปล่า** (sync: 1 Jun 2025, content 404) | ✅ 10.1 (sync: **19 May 2026**) |

---

## สรุปผลต่าง

| OS | openlandscape.cloud | mirror1.ku.ac.th |
|---|---|---|
| Ubuntu (6/6) | ✅ | ✅ |
| Debian (3/5) | ✅ | ✅ |
| Fedora (0/8) | — | — |
| CentOS (5/5) | ✅ | ✅ |
| AlmaLinux (3/3) | ✅ | ✅ |
| Rocky Linux (3/3) | ⚠️ 8,9 sync เก่า / 10 เปล่า | ✅ ครบ sync ปัจจุบัน |

**mirror1.ku.ac.th ดีกว่า** — Rocky Linux ครบทุกเวอร์ชัน sync ปัจจุบัน, มี EPEL (`fedora-epel/`), ส่วน `openlandscape.cloud` Rocky Linux 10 เป็นแค่ directory เปล่า

---

## Recommended Mirror URLs

ตารางนี้คือ source of truth ปัจจุบันสำหรับ image build:

| OS | Mirror หลัก | หมายเหตุ |
|---|---|---|
| Ubuntu 26.04 | `http://mirrors.openlandscape.cloud/ubuntu/` | ใช้ `openlandscape.cloud` เป็นหลัก (policy: first priority) |
| Ubuntu 24.04 | `http://mirror1.ku.ac.th/ubuntu/` | ใช้กับ `99-thai-mirror.cfg` ด้วย |
| Debian 13 | `http://mirror1.ku.ac.th/debian/` + `http://mirror1.ku.ac.th/debian-security/` | ต้องมี security repo |
| AlmaLinux 10 | `http://mirror1.ku.ac.th/almalinux/` | verify repo format ก่อน sed |
| Rocky 10 | `http://mirror1.ku.ac.th/rocky-linux/` | `openlandscape.cloud` ไม่มี Rocky 10 content |
| CentOS Stream 10 | `http://mirror1.ku.ac.th/centos-stream/10-stream/` | BaseOS ✅, AppStream ✅, CRB ✅ — **extras-common ❌ (404)** |
| Fedora 44 | `https://mirror.sg.gs/fedora/` หรือ metalink | ไม่มี mirror ไทย — `mirror.sg.gs/fedora/releases/44/` = 404 (ยังไม่ sync) |

คำสั่ง `sed` ในไฟล์นี้เป็น template เท่านั้น ก่อนใช้จริงต้อง `grep` repo format บน `[golden-image VM]` แล้วเทียบ pattern ก่อนเสมอ

```ini
# Ubuntu 26.04 / Ubuntu 24.04 / Debian 13 / AlmaLinux 10 / Rocky Linux 10 / CentOS
http://mirrors.openlandscape.cloud/ubuntu/          ← Ubuntu 26.04 (หลัก)
http://mirror1.ku.ac.th/ubuntu/                     ← Ubuntu 24.04 (fallback)
http://mirror1.ku.ac.th/debian/
http://mirror1.ku.ac.th/debian-security/      ← สำหรับ Debian 13 (openlandscape ไม่มี)
http://mirror1.ku.ac.th/almalinux/
http://mirror1.ku.ac.th/rocky-linux/
http://mirror1.ku.ac.th/centos/
http://mirror1.ku.ac.th/centos-stream/
```

> **Note:** Debian security — `openlandscape.cloud` = ❌ ไม่มี `/debian-security` (404), `mirror1.ku.ac.th` = ✅ มี

### Fedora: ต้องใช้ mirror นอกประเทศ

```ini
# ตัวเลือก regional mirror (SG)
https://mirror.sg.gs/fedora/
# หรือให้ Fedora MirrorManager เลือกให้อัตโนมัติ (metalink)
```

---

## Cloud-init & Ubuntu Cloud Image

> **สำคัญ:** Ubuntu cloud image (24.04, 26.04) บน OpenStack — cloud-init จะ rewrite `/etc/apt/sources.list.d/ubuntu.sources` ทุกครั้งที่ VM เกิดใหม่ โดยดึง mirror URL จาก OpenStack metadata (`nova.clouds.archive.ubuntu.com`) → `sed` ใน golden image อย่างเดียวไม่พอ

**วิธีแก้:** ฝัง cloud-init config ใน golden image:

```bash
sudo tee /etc/cloud/cloud.cfg.d/99-thai-mirror.cfg > /dev/null << 'EOF'
apt:
  primary:
    - arches: [default]
      uri: http://mirrors.openlandscape.cloud/ubuntu/
  security:
    - arches: [default]
      uri: http://mirrors.openlandscape.cloud/ubuntu/
EOF
```

> **Note:** Ubuntu 26.04 ใช้ `openlandscape.cloud` เป็นหลัก per policy — Ubuntu 24.04 ใช้ `mirror1.ku.ac.th`

ดูขั้นตอนเต็มใน `build/guest-images.md` → Mirror Configuration

---

## RPM-based OS — Mirror Change Commands

> **หลักการ:** RPM-based OS (Rocky, Alma, Fedora) — cloud-init ไม่ rewrite repo config แบบ Ubuntu → `sed` ใน golden image ครั้งเดียวอยู่ถาวร ไม่ต้องฝัง cloud-init config

### Rocky 10

```bash
sudo sed -i \
  -e 's/^mirrorlist=/#mirrorlist=/' \
  -e 's|^#baseurl=http://dl.rockylinux.org/\$contentdir|baseurl=http://mirror1.ku.ac.th/rocky-linux|' \
  /etc/yum.repos.d/rocky*.repo
sudo dnf makecache
```

### AlmaLinux 10

```bash
# Step 1 — comment mirrorlist
sudo sed -i 's|^mirrorlist=https://mirrors.almalinux.org|#mirrorlist=https://mirrors.almalinux.org|' \
  /etc/yum.repos.d/almalinux*.repo

# Step 2 — uncomment + redirect baseurl
sudo sed -i 's|^# baseurl=https://repo.almalinux.org/almalinux/|baseurl=http://mirror1.ku.ac.th/almalinux/|' \
  /etc/yum.repos.d/almalinux*.repo
sudo dnf makecache
```

### Debian 13 (`mirror+file://`)

```bash
# Primary mirror
echo 'http://mirror1.ku.ac.th/debian' | sudo tee /etc/apt/mirrors/debian.list

# Security mirror
echo 'http://mirror1.ku.ac.th/debian-security' | sudo tee /etc/apt/mirrors/debian-security.list

# Disable PDiffs
echo 'Acquire::PDiffs "false";' | sudo tee /etc/apt/apt.conf.d/99-no-pdiffs
sudo apt update
```

> **`openlandscape.cloud` ไม่มี debian-security (404)** — ใช้ `mirror1.ku.ac.th` แทน

### Fedora

ไม่มี mirror ไทย — ใช้ regional (SG) หรือ metalink auto

---

## วิธีใช้ซ้ำ

1. เปิดไฟล์นี้เช็ค OS + version ว่ามีใน mirror ไทยไหม
2. ถ้าเป็น Ubuntu 26.04 → ใช้ `mirrors.openlandscape.cloud` (policy: first priority)
3. ถ้าเป็น Ubuntu 24.04 → ใช้ `mirror1.ku.ac.th`
4. ถ้า Rocky 10 ใน `openlandscape.cloud` → ใช้ `mirror1.ku.ac.th` แทน
5. ถ้า Fedora → ใช้ official mirror หรือ regional mirror (SG)
6. ถ้าเป็น Debian 9-10 → ใช้ `archive.debian.org`
