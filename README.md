# OpenStack Image Builder

> Golden image builder — สร้าง OpenStack app images พร้อมใช้ (WordPress, Nextcloud, Odoo, Grafana, etc.)

## วิธีใช้

1. **เปิด project ด้วย ZCode** → ใช้ skill `app-for-customer` สำหรับ build pipeline
2. **พิมพ์ "สร้าง X image"** เช่น "สร้าง wordpress image" → skill จะ dispatch workflow อัตโนมัติ
3. **AI จัดการ pipeline อัตโนมัติ** — วิจัย → ออกแบบ → ตรวจ → build → ทดสอบ → ปิด docs
4. **ถามเฉพาะ decision points** — cleanup mode, reboot test, secret leak

## Pipeline

| # | บทบาท | หน้าที่ |
|---|-------|--------|
| 0 | **Orchestrator** | อ่าน state, route, dispatch, rework |
| 1 | **Researcher** | วิจัย community, เขียน review.md |
| 2 | **Architect** | ออกแบบ stack, เขียน build guide + source |
| 3 | **Reviewer** | ตรวจ code/guide ก่อน build — ผ่าน/ตีกลับ |
| 4 | **Engineer** | SSH build ตาม guide, บันทึก errors, สร้าง manifest |
| 5 | **Tester** | Pre-capture gate + post-test checklist |
| 6 | **Tester (Browser)** | Browser test via Playwright (ถ้ามี web UI) |
| 7 | **Scribe** | Sync docs, ปิด loop, ลบ temp |

## โครงสร้างโปรเจค

```
openstack-image/
├── apps/              # Per-app source + guide + review + errors + manifest
├── docs/              # AI-PIPELINE.md, ARCHITECTURE.md, references
├── inventory/         # Build env config
├── scripts/           # Build & verification scripts
├── AGENTS.md          # Workspace instructions
├── Makefile           # Automation targets
└── README.md          # คุณอยู่ที่นี่
```

## ไฟล์สำคัญ

| ไฟล์ | ใช้ทำอะไร |
|------|----------|
| `AGENTS.md` | Workspace instructions |
| `docs/AI-PIPELINE.md` | Build pipeline framework |
| `apps/_app-catalog.md` | สถานะ app ปัจจุบัน |

## Skill ที่เกี่ยวข้อง

| Skill | ใช้เมื่อ |
|-------|---------|
| **app-for-customer** | Build pipeline สำหรับ VM images |
| **ai-project-ops** | Audit project structure, deploy, rebuild |

## นโยบายความปลอดภัย

- ห้ามบันทึก temp IP, server ID, floating IP, Glance ID ลง docs กลาง
- ห้ามเก็บ password, token, private key, credentials ใน repo
- Temp env อยู่ใน `tmp/{app}-build.env` (gitignored, ลบหลังจบ)
