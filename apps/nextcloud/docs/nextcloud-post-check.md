# Nextcloud Image — Post-Check Checklist

> Checklist กลางสำหรับตรวจ VM ที่สร้างจาก Nextcloud image ครั้งแรก
> ห้ามใส่ password, temp IP, server ID, Glance ID, หรือ runtime credentials ในไฟล์นี้

---

## Scope

ใช้เช็คว่า image ที่ capture แล้ว boot เป็น VM ใหม่ได้จริง และ Nextcloud ถูกติดตั้งเสร็จ ไม่ค้างที่ install wizard

ค่าจริงของรอบ test ให้มาจาก user หรือ `tmp/nextcloud-build.env` เท่านั้น ห้าม commit ลงเอกสารกลาง

---

## Runtime Data Policy

ไฟล์ต่อไปนี้เป็น runtime/temp data เท่านั้น:

| Path | เกิดเมื่อไหร่ | Policy |
|---|---|---|
| `/opt/nextcloud/.env` | bootstrap ตอน boot VM | ต้องลบก่อน capture, หลัง boot VM ใหม่ต้องถูกสร้างใหม่ |
| `/root/nextcloud-credentials.txt` | bootstrap ตอน boot VM | ต้องลบก่อน capture, ห้าม dump content ลง repo/chat |
| `/var/log/nextcloud-bootstrap.log` | bootstrap ตอน test/build | ลบก่อน capture ได้ |
| `/var/lib/nextcloud/*` | bootstrap ตอน container start | ต้องลบก่อน capture ถ้า image ต้องเป็น fresh first boot |
| Docker containers/volumes | bootstrap ตอน container start | ต้องลบก่อน capture ถ้า image ต้องเป็น fresh first boot |

## Multi-Interface VM Detection

bootstrap ใช้ `get_all_ips()` — ดึง **ทุก** non-loopback IPv4 address จาก `ip -4 addr show scope global` ใส่เข้า trusted_domains ทั้งหมด → user เข้าผ่าน IP ไหนก็ได้ (public / VXLAN / private)

**Append-only logic:** ถ้ามี IP ใหม่ (เช่น user ต่อ interface เพิ่มภายหลัง), bootstrap จะเพิ่ม IP ใหม่เข้า trusted_domains โดยไม่ลบของเก่า ไม่แตะ domain ที่ user เพิ่มเอง

ถ้ามีปัญหา "Access through untrusted domain":
- `cat /opt/nextcloud/.env | grep TRUSTED_DOMAINS`
- `docker compose exec -T -u www-data nextcloud php occ config:system:get trusted_domains`
- ตรวจสอบ IP ปัจจุบัน: `ip -4 addr show scope global`

**หมายเหตุ:** Docker bridge IPs (`172.x.x.x`) ถูกกรองออกอัตโนมัติโดย `scope global`

---

## Post-Check — รันบน VM ที่สร้างจาก image

[nextcloud-test-vm]

### 1. Bootstrap service

```bash
systemctl is-enabled nextcloud-bootstrap.service
systemctl status nextcloud-bootstrap.service --no-pager
```

**ต้องได้:** service `enabled` และไม่ failed

### 2. Runtime files created after boot

```bash
test -s /opt/nextcloud/.env && echo ".env exists"
test -s /root/nextcloud-credentials.txt && echo "credentials exists"
test -s /var/log/nextcloud-bootstrap.log && echo "bootstrap log exists"
test -d /var/lib/nextcloud/app && echo "app data path exists"
test -d /var/lib/nextcloud/db && echo "db data path exists"
test -d /var/lib/nextcloud/redis && echo "redis data path exists"
```

**ห้าม:** เปิดหรือ dump content ของ `/root/nextcloud-credentials.txt` ลงเอกสาร/chat

### 3. Containers running

```bash
cd /opt/nextcloud
docker compose ps
```

**ต้องได้:** containers หลักขึ้นครบ — `db`, `redis`, `nextcloud`, `nginx`

> ⚠️ **ทุก `docker compose` command ต้องระบุ `--profile http`** — เพราะ nginx service อยู่ใน `profiles: [http, default]` ถ้าสั่ง `docker compose restart/down` โดยไม่มี `--profile http` จะไม่เห็น nginx → container ค้าง → port 80 ถูกจอง → start ใหม่ล้มเหลว

### 4. Nextcloud installed

```bash
docker compose exec -T -u www-data nextcloud sh -lc 'cd /var/www/html && php occ status'
```

**ต้องได้:** `installed: true`

**ห้ามถือว่า HTTP 200 อย่างเดียวผ่าน** เพราะ install wizard ก็คืน `200 OK` ได้

### 5. HTTP login page

```bash
curl -sI http://localhost | head -20
curl -sL http://localhost | grep -i -E 'Login - Nextcloud|Nextcloud' | head
```

**ต้องได้:** root redirect ไป login หรือ login page ตอบ `200` และมีข้อความ `Login - Nextcloud`

### 6. Docker images preserved

```bash
docker images | grep -E 'nextcloud|postgres|redis|nginx'
```

**ต้องได้:** มี image หลักครบ ไม่ต้อง pull ใหม่ตอน first boot

**ต้องไม่มี:** bootstrap log ที่บอกว่า first boot รัน `docker compose pull`

### 6.1 VM login docs / MOTD

```bash
test -s /root/README-nextcloud-image.txt && echo "README exists"
test -x /etc/update-motd.d/99-nextcloud-image && echo "MOTD executable"
test -s /etc/nextcloud-image/image.conf && echo "image metadata exists"
/etc/update-motd.d/99-nextcloud-image
```

**ต้องได้:** MOTD บอก `Creds`, `Docs`, `Config`, `Data`, `Logs`, `Manage` ครบ

### 7. Logs without secret dump

```bash
docker compose -f /opt/nextcloud/docker-compose.yml logs --tail=60 nextcloud
docker compose -f /opt/nextcloud/docker-compose.yml logs --tail=40 db
docker compose -f /opt/nextcloud/docker-compose.yml logs --tail=40 redis
docker compose -f /opt/nextcloud/docker-compose.yml logs --tail=40 nginx
```

**ต้องได้:** ไม่มี install failure ซ้ำ เช่น `Installing of nextcloud failed`, DB driver ผิด, หรือ `occ: executable file not found`

---

## Success Criteria

| ข้อ | เกณฑ์ผ่าน | สถานะ |
|---|---|---|
| 1. Bootstrap service | enabled และไม่ failed | ✅ |
| 2. Runtime files | `.env`, `credentials.txt`, bootstrap log ถูกสร้างหลัง boot | ✅ |
| 3. Containers | `db`, `redis`, `nextcloud`, `nginx` running; db/redis healthy ถ้ามี healthcheck | ✅ |
| 4. Nextcloud install | `php occ status` ได้ `installed: true` | ✅ |
| 5. HTTP | login page ตอบได้ ไม่ใช่ install wizard | ✅ |
| 6. Images | Docker images หลักยังอยู่ครบ | ✅ |
| 7. VM docs | README/MOTD/image metadata อยู่ครบและบอก path สำคัญ | ✅ |
| 8. Logs | ไม่มี install failure / occ path error | ✅ |
| 9. Reboot survive | reboot → กลับมาเอง 4 containers, HTTP 302 | — (optional) |
| 10. Docker restart | `systemctl restart docker` → containers auto-recover | — (not tested) |
| 11. WebDAV file | upload/download/delete ผ่าน WebDAV | ✅ |
| 12. Data persist | ไฟล์อยู่รอด container restart + full restart | — (not tested) |
| 13. Bind mount | `/var/lib/nextcloud/app/data/` มองเห็นจาก host | ✅ |
| 14. Password special chars | `REDIS_PASSWORD` ใน `.env` ต้องไม่มี `+` `/` `=` — ใช้ `grep "^REDIS_PASSWORD=" /opt/nextcloud/.env | grep -q '[\+\/\=]' && echo FAIL || echo PASS` | ✅ |
| 15. Browser login | Playwright: login admin → reach `/apps/dashboard/` | ✅ |
| 16. trusted_domains clean | ไม่มี Docker bridge IP `172.x`; มี VM IP ใหม่ | ✅ |

ถ้าผ่านครบ = image boot ใช้งานจริงผ่าน post-test

---

## Nextcloud-Specific Post-Test Gotchas

> ดู [`docs/playbooks/customer-app-playbook.md`](../../docs/playbooks/customer-app-playbook.md) §12 — รายการทั่วไป

| Gotcha | ที่เจอจริงรอบ 2026-07-08/09 | ทางแก้ |
|---|---|---|
| Container name guess | Test script hardcode `nextcloud-app-1` → จริงคือ `nextcloud-nextcloud-1` | `docker ps --format '{{.Names}}'` ก่อน `docker exec` |
| Helper script path | ค้น `/usr/local/sbin/nc-*` ไม่เจอ | helpers อยู่ใน `/usr/local/bin/` (ดู `install_helpers()` in `nextcloud-bootstrap.sh`) |
| Runtime files post-boot confused with leftover artifacts | `.env`/`credentials.txt`/`bootstrap.log` เจอ → นับ fail แต่จริงๆ by-design | Pre-capture: ต้องไม่มี (Layer 1 cleanup). Post-boot fresh VM: ต้องมี (bootstrap regenerated). |
| `docker compose ps` ไม่เห็น nginx | ลืม `--profile http` | ใช้ `--profile http` ทุกคำสั่งที่แตะ compose |
| File deploy ผ่าน PowerShell แล้ว code เพี้ยน | inline command / hand-made base64 ทำให้ `REIDS_PASSWORD` หลุดเข้า compose ทั้งที่ source จริงถูกต้อง | deploy ไฟล์จาก local file โดยตรง, ห้าม encode base64 ด้วยมือ, หลัง deploy ให้ `grep -n "REIDS\|REDIS" docker-compose.yml` ก่อน bootstrap |

---

## Latest Post-Test Results

| Date | Server | IP | Result |
|---|---|---|---|
| 2026-07-09 | `nextcloud-posttest-ip-change` | 203.154.16.197 | ✅ Pass (12/12) |
| | | | ✅ shutoff + IP change แล้ว bootstrap เติม trusted_domains ใหม่ (`10.10.20.6`, `203.154.16.197`) ไม่มี Docker bridge IP |
| | | | ✅ Bootstrap active+enabled, 4 containers Up, `.env`/credentials/bootstrap log regenerated, passwords alphanumeric-only |
| | | | ✅ nginx healthy, `occ status` = installed:true, HTTP `/login` 200, browser login → Dashboard |
| | | | ✅ WebDAV PUT 201 → GET 200 (content match) → DELETE 204 → GET 404 |
| | | | Notes: no reboot test (admin declined), no cleanup requested becauseใช้เพื่อยืนยันว่า image ใช้งานได้จริงหลังเปลี่ยน IP |
| 2026-07-08 | golden image VM (new capture) | — | ✅ Pass (12/12) |
| | | | ✅ Bootstrap active+enabled, 4 containers Up, .env alphanumeric, trusted_domains includes new VM IP |
| | | | ✅ nginx healthy, installed: true, HTTP 302, browser login → Dashboard |
| | | | ✅ WebDAV PUT 204 → GET 200 (content match) → DELETE 204 → GET 404 |
| | | | Notes: no reboot test (admin declined); no-cleanup mode; cleanup verified pre-capture separately |
| 2026-07-07 | `nextcloud-test-v2` (snapshot) | 203.154.16.169 | ✅ Pass (13/13) |
| | | | ✅ IP change detection: 199→169 auto |
| | | | ✅ WebDAV, reboot, docker restart, helper scripts |
| 2026-06-10 | `nextcloud-test` (916f8fab) | 203.154.16.48 | ✅ Pass (12/13) |
| | | | ⚠️ `docker compose down` ต้อง `--profile http` — not a bug, fixed in docs |
| | | | ⚠️ Redis password special chars — fixed 2026-07-08 (gen_password alphanumeric-only) |

---

## Cleanup ก่อน Capture

หลังทดสอบ bootstrap บน golden-image VM แล้ว ก่อน snapshot ต้องลบ runtime state:

```bash
cd /opt/nextcloud
docker compose --profile http down -v
rm -f /opt/nextcloud/.env /root/nextcloud-credentials.txt /var/log/nextcloud-bootstrap.log
rm -rf /var/lib/nextcloud/app/* /var/lib/nextcloud/db/* /var/lib/nextcloud/redis/*
```

แล้ว verify:

```bash
systemctl is-enabled nextcloud-bootstrap.service
cd /opt/nextcloud && docker compose ps
test ! -e /opt/nextcloud/.env && echo ".env removed"
test ! -e /root/nextcloud-credentials.txt && echo "credentials removed"
find /var/lib/nextcloud -mindepth 2 -maxdepth 2 -print -quit | grep -q . || echo "runtime data removed"
```

---

## วิธีใช้ซ้ำ

1. สร้าง VM ใหม่จาก Nextcloud image
2. SSH เข้า `[nextcloud-test-vm]`
3. รันคำสั่งในหัวข้อ Post-Check ทีละข้อ
4. อัปเดต `Success Criteria` เป็น `✅ pass` หรือ `❌ fail` ใน incident/post-test note เฉพาะรอบนั้น
5. ถ้า fail ให้บันทึกใน `problem/generic/` โดยไม่ใส่ secret/temp IP
