# OpenStack Image Builder — Workspace Instructions

โปรเจคสร้าง OpenStack golden VM images แบบสำเร็จรูป (QCOW2 → Glance)
พร้อม application stacks: WordPress, Nextcloud, Grafana, n8n, Ollama, และอื่นๆ

## โครงสร้างโปรเจค

```
openstack-image/
├── apps/                    # App image definitions (1 folder per app)
│   ├── wordpress/
│   ├── nextcloud/
│   ├── grafana-prometheus/
│   └── ...
├── scripts/                 # Build & verification scripts
├── inventory/               # Build metadata & image manifests
├── docs/                    # Project documentation
│   ├── ARCHITECTURE.md
│   ├── AI-PIPELINE.md
│   └── references/
├── problem/                 # Troubleshooting knowledge base
├── Makefile
├── README.md
├── CONTRIBUTING.md
└── .gitignore
```

## หลักการ

- **ไม่มี agents/ ในโปรเจค** — agents ใช้จาก `~/.zcode/agents/` (FF7 squad)
- **ไม่มี skills/ ในโปรเจค** — skills อยู่ใน Sphere repo (`~/.zcode/skills/`)
- **ทุกอย่างเรียกใช้ผ่าน skill** — ใช้ `build-openstack-image` skill สำหรับ build pipeline
- **1 App = 1 Folder** — แต่ละ app มี build guide, docker-compose, bootstrap, tests ใน folder ของตัวเอง
- **Header tag system** — `[พร้อม build]`, `[ผ่านตรวจ]`, `[built: standalone]`, `[build ล้มเหลว]`, `[รอ rebuild]`

## Skill ที่เกี่ยวข้อง

| Skill | ใช้เมื่อ |
|-------|---------|
| **build-openstack-image** | Build, rebuild, fix, verify app image |
| **app-for-customer** | Customer-facing app hardening & golden rules |
| **ai-project-ops** | Audit project structure, deploy, rebuild project |
| **super-searcher** | Technical research & best practices |

## ข้อห้าม

- ห้ามบันทึก secret/IP/ID/credential ลง repo
- ห้าม `docker image prune -a` (ต้องเก็บ pre-pull images)
- ห้ามสร้าง per-app skill file ใหม่
