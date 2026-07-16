# Dify CE — AI Mistakes Log

> บันทึกคำสั่ง AI ที่ผิด, ปัญหาที่เจอ, และวิธีแก้ — ระหว่าง build + post-test

---

## Build Errors

| # | Date | Command | Error | Fix |
|---|---|---|---|---|
| 1 | 2026-06-21 | `docker compose up -d` | nginx crash loop: `host not found in upstream "dify-plugin-daemon:5002"` | เปลี่ยน nginx config จาก `upstream` block เป็น `resolver 127.0.0.11` + `set $var host:port; proxy_pass http://$var` — resolve ตอน request แทน startup |
| 2 | 2026-06-21 | `docker compose up -d` | plugin_daemon crash loop: `Config.ServerKey required`, `Config.DifyInnerApiKey required`, `Config.DBUsername required`, `plugin remote installing host empty`, `plugin working path empty` | เพิ่ม .env vars: `SERVER_KEY`, `DIFY_INNER_API_KEY`, `DIFY_INNER_API_URL`, `DB_USERNAME`, `PLUGIN_REMOTE_INSTALLING_HOST`, `PLUGIN_REMOTE_INSTALLING_PORT`, `PLUGIN_WORKING_PATH` |
| 3 | 2026-06-21 | `curl /health` | 404 — `/health` ถูก route ไป web frontend (ไม่มี endpoint นี้) | เพิ่ม `location = /health` ใน nginx config → proxy ไป api:5001 |
| 4 | 2026-06-21 | `cat >> /opt/dify/.env` ผ่าน plink | `$(openssl ...)` ถูก expand โดย local PowerShell; `${VAR}` heredoc ถูกตีความเป็น empty | ใช้ `sed -i 's/^KEY=$/KEY=value/'` แก้ค่าโดยตรงแทน heredoc ผ่าน plink |
| 5 | 2026-06-21 | VM ใหม่จาก image (volume ติดมา) | plugin_daemon `password authentication failed` — DB_PASSWORD ใน .env ไม่ตรงกับรหัสที่ฝังใน PostgreSQL volume (volume ถูกสร้างด้วยรหัสเก่าตอน build test) | golden image ต้อง `docker compose down -v` ตอน cleanup — ลบ volumes ทิ้งทั้งหมด ไม่เก็บ volume state ข้าม VM |
| 6 | 2026-06-21 | เข้า `/install` | Web frontend ทำ SSR แล้ว call API ที่ `127.0.0.1:5001` → `ECONNREFUSED` — web container ไม่รู้ว่า API อยู่คนละ container | เพิ่ม `CONSOLE_API_URL=http://api:5001` + `APP_API_URL=http://api:5001` ใน .env |
| 7 | 2026-06-21 | `/console/api/setup` → `ValueError: 'e3q8' is not a valid HTTPStatus` | Database migration ไม่เคยรัน — ตารางหลัก (accounts, apps, etc.) ไม่มี | เพิ่ม `MIGRATION_ENABLED=true` ใน .env → API container รัน `flask db upgrade` ตอน start |
| 8 | 2026-06-21 | `/install` หมุนค้างไม่ขึ้น form | `CONSOLE_API_URL=http://api:5001` เป็น internal Docker address — browser เรียกไม่ได้ ต้องปล่อยว่างเพื่อให้ Next.js ใช้ relative path | เปลี่ยน `CONSOLE_API_URL=` + `APP_API_URL=` (ค่าว่าง) ใน .env |
| 9 | 2026-06-21 | `/console/api/setup` → 500 Permission denied | Storage volume permission ผิด — API container รันเป็น user `dify` แต่ named volume เป็นของ root | เปลี่ยนเป็น bind mount `./storage:/app/api/storage` + `chmod -R 777 /opt/dify/storage` ใน bootstrap |
| 10 | 2026-06-21 | plugin_daemon crash | ขาด `DB_USERNAME` env var — plugin daemon ต้องการตัวแปรนี้เพื่อเชื่อม PostgreSQL | เพิ่ม `DB_USERNAME=postgres` ใน .env |
| — | 2026-06-21 | **Final Design Decision** | **ลบ plugin_daemon ออกจาก stack** — `0.6.1-local` เป็น pre-release build, endpoint ไม่ตรงกับ frontend 1.14.2 | Stack เหลือ 11 containers — core Dify ทำงานได้ แต่ frontend ยังเรียก plugin endpoints → `PluginDaemonInnerError` → error notification ใน UI |
| 11 | 2026-06-21 | ลบ plugin_daemon + rebuild | UI ยัง error: `PluginDaemonInnerError` — frontend hardcoded เรียก `/console/api/workspaces/current/plugin/tasks` | Dify API ฝัง plugin system ใน code — ลบ container ไม่พอ ต้องแก้ code ฝั่ง API หรือปิด plugin feature ผ่าน config |

---

## Post-Test Errors

| # | Date | Check | Error | Fix |
|---|---|---|---|---|
| — | — | — | — | — |

---

## Pattern Lessons

| # | Pattern | Applies To | Lesson |
|---|---|---|---|
| 1 | nginx upstream DNS race | ทุก multi-service Docker Compose ที่มี nginx | ใช้ `resolver 127.0.0.11` + `set` variables แทน `upstream` block — nginx resolve hostnames ตอน config parse ถ้าภาชนะอื่นยังไม่ start จะพัง |
| 2 | plugin daemon env discovery | Dify plugin_daemon container | ต้องอ่าน logs จริงเพื่อหา env vars ที่ขาด — Dify plugin daemon มี dependency เยอะที่ไม่มีใน `.env.example` หลัก |
| 3 | PostgreSQL volume password mismatch | ทุก app ที่มี DB + ใช้ `docker compose down` (ไม่มี `-v`) แล้วสร้าง VM ใหม่จาก image | `POSTGRES_PASSWORD` ถูกใช้เฉพาะตอน init volume ครั้งแรก — ถ้า volume ติดมาจาก build test รอบก่อน แล้ว .env bootstrap สร้างรหัสใหม่ จะ mismatch → golden image ต้อง `down -v` ลบ volumes หรือให้ bootstrap รีเซ็ตรหัส DB ให้ตรงกับ .env |
| 4 | CONSOLE_API_URL internal address | Dify web frontend (Next.js) | `CONSOLE_API_URL` ต้องเป็นค่าว่าง (relative path) ไม่ใช่ `http://api:5001` — browser เรียก internal Docker address ไม่ได้ |
