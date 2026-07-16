# Odoo Image — Post-Check Checklist

> Checklist กลางสำหรับตรวจ VM ที่สร้างจาก Odoo image ครั้งแรก
> ห้ามใส่ password, temp IP, หรือ runtime credentials ในไฟล์นี้

---

## Scope

ใช้เช็คว่า image ที่ capture แล้ว boot เป็น VM ใหม่ได้จริงหรือไม่

| รายการ | สถานะ | หมายเหตุ |
|---|---|---|
| Build guide พร้อม | ⏳ pending | `apps/odoo/odoo.md` |
| Build VM ทำจริง | ⏳ pending | standalone build |
| Cleanup ก่อน capture | ⏳ pending | ต้องไม่มี runtime secret ก่อน snapshot |
| Capture เป็น Glance image | ⏳ pending | Glance ID — |
| Boot VM จาก image | ⏳ pending | VM test boot แล้ว SSH ได้ |
| Post-test VM จาก image | ⏳ pending | ตรวจหลัง build จริง |

---

## Runtime Data Policy

ไฟล์ต่อไปนี้เป็น runtime/temp data เท่านั้น:

| Path | เกิดเมื่อไหร่ | Policy |
|---|---|---|
| `/opt/odoo/.env` | bootstrap ตอน boot VM | ต้องลบก่อน capture, หลัง boot VM ใหม่ต้องถูกสร้างใหม่ |
| `/root/odoo-credentials.txt` | bootstrap ตอน boot VM | ต้องลบก่อน capture, ห้าม dump content ลง repo |
| `/var/log/odoo-bootstrap.log` | bootstrap ตอน test/build | ลบก่อน capture ได้ |
| Docker volumes `odoo_*` | test bootstrap | ต้องลบก่อน capture |

---

## Post-Check — รันบน VM ที่สร้างจาก image

[odoo-test-vm]

### 1. Bootstrap service

```bash
systemctl is-enabled odoo-bootstrap.service
systemctl status odoo-bootstrap.service --no-pager
```

ต้องได้: service `enabled` และไม่ failed

### 2. Containers running

```bash
cd /opt/odoo
docker compose ps
```

ต้องได้: `db` healthy, `odoo` running, `nginx` running

### 3. HTTP responding

```bash
curl -sI http://localhost/web/login | head -5
```

ต้องได้: HTTP `200` หรือ redirect ที่ตามแล้วเข้า Odoo login ได้

### 4. Runtime files created after boot

```bash
ls -l /opt/odoo/.env /root/odoo-credentials.txt /opt/odoo/config/odoo.conf
```

ต้องได้: มีทั้ง 3 ไฟล์หลัง boot VM ใหม่

ห้าม: เปิดหรือ dump content ของ credentials ลงเอกสาร

### 5. Database fixed name

```bash
cd /opt/odoo
docker compose exec -T db psql -U odoo -d odoo_prod -c '\conninfo'
```

ต้องได้: connect database `odoo_prod` ได้

### 6. Websocket/gevent route

```bash
curl -i -H 'Connection: Upgrade' -H 'Upgrade: websocket' http://127.0.0.1/websocket | head -20
```

ต้องดูร่วมกับ browser/logs: ไม่มี blank page, ไม่มี `bus.bus unavailable`

### 7. Backup

```bash
/usr/local/sbin/odoo-backup.sh
ls -lh /opt/odoo/backups/
```

ต้องได้: SQL gzip + filestore tar gzip

---

## วิธีใช้ซ้ำ

1. สร้าง VM ใหม่จาก Glance image
2. SSH เข้า `[odoo-test-vm]`
3. รันคำสั่งในหัวข้อ Post-Check ทีละข้อ
4. อัปเดตตาราง Scope เป็น pass/fail หลังทดสอบจริง
5. ถ้า fail ให้บันทึก incident ใน `problem/generic/` โดยไม่ใส่ secret
