# Image Inventory

> Metadata ของ image ที่ build แล้ว

---

## โครงสร้าง

```text
inventory/
├── README.md           ← ไฟล์นี้
├── build.env           ← Build environment template
└── images/             ← Image metadata (non-secret only)
    ├── .gitkeep
    └── guest-images.env  ← Guest image metadata ถ้าต้องใช้แบบ generic
```

## หลักการ

- **Domain-level** — เก็บ image metadata แบบ generic ใช้ซ้ำได้ทุกที่ (base OS, cloud-init)
- **Standalone build** — build image ที่ไหนก็ได้ แต่ record ใต้ `inventory/` ต้องเป็น generic และใช้ซ้ำได้
- **App build versions** — เก็บที่ `apps/{app}/{app}-build-manifest.md` ไม่ใช่ inventory เพราะเป็นประวัติ golden image build ล่าสุดต่อ app
- ไม่เก็บ image binary ใน repo (เดี๋ยว repo บวม) — เก็บแค่ metadata หรือลิงก์
- Temp env สำหรับ build ให้อยู่ใต้ `tmp/` ได้เฉพาะระหว่างทำงาน ต้อง gitignored และลบทิ้งหลัง build
- ห้ามเก็บ password, token, private key, temp VM IP, server ID, Floating IP, Glance ID, image name เฉพาะรอบ build หรือ credential จริงใน repo

## วิธีเพิ่ม image ใหม่

1. Build image ตาม `apps/{app}/{app}.md` หรือ `apps/_guest-images.md`
2. ถ้าเป็น app image ให้อัปเดต `apps/{app}/{app}-build-manifest.md` แบบ non-secret

## Image ปัจจุบัน

| Image | OS | Size | ใช้กับ | หมายเหตุ |
|---|---|---|---|---|
| — | — | — | — | ยังไม่มี image metadata |

## Nextcloud rebuild target

| เรื่อง | ค่า |
|---|---|
| Status | ⚠️ รอ rebuild/capture ใหม่ |
| OS | Ubuntu 26.04 |
| Install flow | Auto-install, admin user `admin`, password สุ่มต่อ VM |
| Data layout | Bind mount `/var/lib/nextcloud/{app,db,redis}` |
| First boot | ไม่พึ่ง internet, ใช้ Docker images ที่ pre-pull ใน golden image |
| HTTPS | วาง cert เองที่ `/opt/nextcloud/certs/` แล้วเปิด profile `https` |

ยังไม่มี app build manifest จริง ให้ใช้ `apps/nextcloud/nextcloud-build-manifest.md` สำหรับ version history และห้ามเติม Glance ID, image name, server ID, IP หรือ OpenStack context ลง repo
