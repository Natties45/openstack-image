# Ollama + Open WebUI Image — Post-Check

> รันหลัง deploy VM หรือหลังสร้าง VM จาก image ครั้งแรก
> ขอบเขต: verify service และ self-service UX เท่านั้น ไม่รวม OpenStack capture/Glance

---

## Pipeline Scope

Post-check นี้ทดสอบ pipeline หลังจาก user/admin สร้าง VM ใหม่จาก image แล้ว ไม่ใช่ pre-capture gate ของ golden-image VM

| Pipeline | ทดสอบอะไร | ไม่ครอบคลุม |
|---|---|---|
| First boot bootstrap | systemd service start containers, wait health, เขียน credentials | OpenStack metadata/floating IP attach |
| Runtime stack | Docker Compose start 2 containers ได้จริง | production load test หรือ sizing ระยะยาว |
| Health endpoints | Open WebUI + Ollama API ตอบสนอง | external access จาก public network |
| Model readiness | pre-pulled models (gemma3:4b, llama3.2:1b) พร้อมใช้งาน | model accuracy/quality |
| Chat capability | signup → login → chat กับโมเดล CPU-only | GPU inference, RAG, multi-model |
| Console/MOTD UX | login console และ `/etc/update-motd.d` ไม่มี error | QEMU/VNC console automation |
| Reboot persistence | optional final gate: reboot แล้ว state ไม่หาย | ต้องถาม user/admin ก่อน reboot ทุกครั้ง |

ก่อนรัน post-test ต้องถาม cleanup mode:
- `no-cleanup` — ทิ้ง runtime/test users/chats ไว้ให้ admin/user ตรวจต่อ
- `cleanup-test-targets` — ลบ test user และ chat history หลัง checklist ผ่าน

---

## Post-Test Overview

| Step | Pipeline phase | ตรวจอะไร | Command หลัก | ผ่านเมื่อ | ถ้าพังให้ทำอะไร |
|---|---|---|---|---|---|
| 1 | Bootstrap | service completed | `systemctl status ollama-openwebui-bootstrap.service` | enabled, active (exited), code=0 | แก้ bootstrap service/script |
| 2 | Runtime files | .env, credentials, marker, README | `test -f ...` | มีครบทุกไฟล์ | แก้ bootstrap script |
| 3 | Container runtime | 2 containers | `docker compose ps` | ollama + open-webui both Up (healthy) | ดู container logs แก้ compose/config |
| 4 | Open WebUI HTTP | web UI endpoint | `curl -sI http://127.0.0.1:3000` | HTTP 200 | แก้ compose/service config |
| 5 | Ollama API | model list | `curl -s http://127.0.0.1:11434/api/tags` | JSON with models | แก้ ollama service/network |
| 6 | Models present | pre-pulled models | `docker exec ollama ollama list` | gemma3:4b + llama3.2:1b listed | pre-pull ใน golden image ใหม่ |
| 7 | MOTD | console message | `run-parts /etc/update-motd.d` | ไม่มี error, แสดง Ollama MOTD | แก้ MOTD source/permission/CRLF |
| 8 | Signup | สร้างบัญชีแรก | `curl POST /api/v1/auths/signup` | HTTP 200, user created, role=admin | แก้ Open WebUI config/ENABLE_SIGNUP |
| 9 | Login | login ด้วยบัญชีที่สร้าง | `curl POST /api/v1/auths/signin` | HTTP 200, token returned | แก้ auth flow |
| 10 | Chat | แชทกับโมเดล | `curl POST /api/chat/completions` | ตอบกลับเป็นข้อความ (Thai OK) | แก้ ollama model/OLLAMA_BASE_URL |
| 11 | Cleanup mode | no-cleanup/cleanup-test-targets | ถาม user/admin | ทำตาม mode ที่เลือก | แก้ post-check flow |
| 12 | Optional reboot gate | reboot persistence | ถาม user/admin ก่อน `reboot` | หลัง reboot containers/models/state อยู่ | แก้ persistence/firstboot idempotency |

---

## Failure Routing

| อาการ | นับเป็น bug ไหม | ส่งผลต่อ pipeline | Action |
|---|---|---|---|
| service disabled หรือ bootstrap exit non-zero | ใช่ | First boot pipeline | แก้ bootstrap service/script และ build guide |
| .env/credentials/marker/README ไม่เกิด | ใช่ | First boot runtime state | แก้ bootstrap script |
| image ต้อง pull ใหม่ตอน first boot | ใช่ | Golden image pre-pull | แก้ build guide และ pre-capture gate |
| container restart loop | ใช่ | Runtime stack | ดู logs แล้วแก้ compose/config |
| Ollama API ไม่ตอบ | ใช่ | Ollama service | แก้ ollama config/network |
| models หาย (volume ว่างเปล่า) | ใช่ | Golden image pre-pull | แก้ pre-pull steps และ pre-capture gate |
| Open WebUI HTTP 500 | ใช่ | Open WebUI service | ดู logs แก้ OLLAMA_BASE_URL/config |
| signup ไม่ได้ (ENABLE_SIGNUP=false) | ใช่ | Open WebUI config | แก้ compose env |
| chat timeout/no response | ใช่ ถ้า model exist | Ollama model/network | เช็ค OLLAMA_BASE_URL, model loaded |
| chat ช้ามาก (>30s) | ไม่ใช่ for CPU-only | Expected for CPU inference | เพิ่ม sizing guideline ใน README |
| `run-parts MOTD` error | ใช่ | Console/MOTD UX | แก้ MOTD CRLF/shebang/permission |
| credentials แสดง IP เก่า (marker ค้าง) | ใช่ ถ้าเป็น VM ใหม่จาก image | First boot idempotency | แก้ bootstrap ให้เช็ค IP เปลี่ยน หรือ cleanup marker ใน golden image |
| reboot แล้ว containers/models หาย | ใช่ | Persistence | แก้ compose restart policy/volume handling |
| model unload หลัง 5 นาที idle | ไม่ใช่ | Expected OLLAMA_KEEP_ALIVE behavior | อธิบายใน README |
| test user ซ้ำหลังรัน no-cleanup ซ้ำ | ไม่ใช่ | Manual inspection mode | ปล่อยไว้ หรือลบ test user ถ้าส่งมอบ |

ถ้า post-test เจอ bug จริง ให้แก้ source/guide/docs ตาม root cause ในรอบเดียวกัน และบันทึก `ollama-openwebui-errors.md` เมื่อเป็นคำสั่ง AI ที่พังจริง.

---

## Post-Check — 12 ข้อ

### 1. Bootstrap service completed

```bash
systemctl is-enabled ollama-openwebui-bootstrap.service
systemctl is-active ollama-openwebui-bootstrap.service
systemctl status ollama-openwebui-bootstrap.service --no-pager
```

ต้องได้:
- `enabled`
- `active` (exited) ที่ code=0 สำเร็จ
- ไม่มี error ใน status

### 2. Runtime files exist

```bash
test -f /opt/ollama-openwebui/.env && echo env-ok
test -f /root/ollama-openwebui-credentials.txt && echo credentials-ok
test -f /root/README-ollama-openwebui-image.txt && echo readme-ok
test -f /var/lib/ollama-openwebui-firstboot.done && echo marker-ok
```

ต้องได้:
- `env-ok`
- `credentials-ok`
- `readme-ok`
- `marker-ok`

### 3. Containers running

```bash
docker compose -f /opt/ollama-openwebui/docker-compose.yml --env-file /opt/ollama-openwebui/.env ps
```

ต้องเห็น containers:
- `ollama` — Up
- `open-webui` — Up (healthy)

### 4. Open WebUI HTTP endpoint

```bash
curl -fsSI http://127.0.0.1:3000 | head -1
```

ต้องได้:
- `HTTP/1.1 200 OK`

### 5. Ollama API responds

```bash
curl -fsS http://127.0.0.1:11434/api/tags | python3 -m json.tool | head -5
```

ต้องได้:
- JSON output พร้อม models array

### 6. Models present

```bash
docker exec ollama ollama list
```

ต้องเห็น:
- `gemma3:4b` — ~3.3 GB
- `llama3.2:1b` — ~1.3 GB

### 7. MOTD works

```bash
test -x /etc/update-motd.d/99-ollama-openwebui-image && echo motd-executable
run-parts /etc/update-motd.d >/tmp/ollama-motd-test.out 2>/dev/null
grep -q 'Ollama + Open WebUI Image' /tmp/ollama-motd-test.out && echo motd-ok
```

ต้องได้:
- `motd-executable`
- `motd-ok`
- `run-parts` ไม่มี error

### 8. Signup works

```bash
curl -fsS -X POST http://127.0.0.1:3000/api/v1/auths/signup \
  -H 'Content-Type: application/json' \
  -d '{"name":"Post Test User","email":"test@posttest.local","password":"TestPass123!"}' | python3 -c "import json,sys; d=json.load(sys.stdin); print('role:',d.get('role')); print('signup: OK')"
```

ต้องได้:
- `role: admin`
- `signup: OK`

### 9. Login works

```bash
TOKEN=$(curl -fsS -X POST http://127.0.0.1:3000/api/v1/auths/signin \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@posttest.local","password":"TestPass123!"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")
echo "login: OK"
```

ต้องได้:
- `login: OK`

### 10. Chat with model works

```bash
TOKEN=$(curl -fsS -X POST http://127.0.0.1:3000/api/v1/auths/signin \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@posttest.local","password":"TestPass123!"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")
curl -fsS -X POST http://127.0.0.1:3000/api/chat/completions \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"model":"gemma3:4b","messages":[{"role":"user","content":"Say hello in Thai in one sentence"}]}' | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'][:100])"
```

ต้องได้:
- ตอบกลับเป็นข้อความภาษาไทย

### 11. Cleanup mode

ถาม user/admin ทุกครั้งก่อนเริ่ม post-test. โหมด:
- `no-cleanup` — ทิ้ง containers, volumes, test user, chat history, .env, credentials, logs ไว้
- `cleanup-test-targets` — ลบ test user และ chat history แล้ว reload app

### 12. Optional final reboot persistence gate

ต้องถาม user/admin ก่อน และทำเป็นขั้นตอนสุดท้ายเท่านั้น.

ถ้า user/admin อนุมัติ reboot:

```bash
reboot
```

หลัง SSH กลับมา:

```bash
systemctl status ollama-openwebui-bootstrap.service --no-pager
docker compose -f /opt/ollama-openwebui/docker-compose.yml --env-file /opt/ollama-openwebui/.env ps
curl -fsSI http://127.0.0.1:3000 | head -1
docker exec ollama ollama list
```

ต้องได้:
- service still completed
- containers running
- HTTP 200
- models still present

ถ้า user/admin ไม่อนุมัติ reboot ให้บันทึกในสรุปว่าไม่ได้ทำ reboot persistence test.

---

## Success Criteria

| ข้อ | Required | Optional / Expected exception |
|---|---|---|
| Bootstrap | service enabled และ completed | — |
| Runtime files | .env, credentials, README, marker มีครบ | credentials อาจมี IP เก่าถ้า marker ค้างจาก golden build |
| Containers | ollama + open-webui both Up (healthy) | — |
| Open WebUI HTTP | HTTP 200 | — |
| Ollama API | JSON with models | — |
| Models | gemma3:4b + llama3.2:1b present | — |
| MOTD | `run-parts` ไม่มี error, แสดง Ollama MOTD | — |
| Signup | user created, role=admin | — |
| Login | token returned | — |
| Chat | model responds in Thai | response time CPU-only (>10s OK) |
| Reboot final gate | ถ้าอนุมัติ: state คงอยู่หลัง reboot | ข้ามได้ถ้าไม่อนุมัติ |

ผ่านทุกข้อ = deploy ใช้งานได้จริง

### Latest Verified Result

| Date | Scope | Result | Notes |
|---|---|---|---|
| 2026-06-21 | Full post-test except reboot final gate | PASS | `no-cleanup` mode, gemma3:4b chat response in Thai, credentials showed old IP due to golden-image marker persist (not a bug on fresh capture) |

Reboot persistence gate was explicitly skipped by user/admin.

---

## Post-Test Mode — No-Cleanup สำหรับ Manual Inspection

ใช้โหมดนี้เมื่อ post-test บน VM ที่ต้องการให้ admin/user เข้าไปตรวจต่อหลัง checklist เสร็จ

ต้องถาม user/admin ก่อนเข้าโหมดนี้ทุกครั้ง ห้าม default เอง

หลังรันข้อ 1-12 แล้วให้คงสถานะ runtime ไว้ทั้งหมด:
- ไม่ลบ test user
- ไม่ลบ `/opt/ollama-openwebui/.env`
- ไม่ลบ `/root/ollama-openwebui-credentials.txt`
- ไม่ลบ `/root/README-ollama-openwebui-image.txt`
- ไม่ลบ `/var/lib/ollama-openwebui-firstboot.done`
- ไม่ stop containers
- ไม่ลบ Docker volumes
- ไม่ลบ logs/runtime state
- ไม่ poweroff VM

ผลลัพธ์ที่ต้องการ:
- VM ยัง running
- containers ยัง running
- Open WebUI accessible ที่ `http://<VM-IP>:3000`
- test user ยัง login ได้
- admin/user ตรวจต่อได้ทันที

---

## Cleanup Test User หลัง Post-Test

Post-test สร้าง test user (`test@posttest.local`) ไว้ทดสอบ signup/login/chat — **ต้องลบก่อนส่งมอบ VM ให้ลูกค้า**

### วิธีลบผ่าน API (ไม่ต้องเข้า Web UI)

```bash
# 1. Login ด้วย test user → เอา admin token
TOKEN=$(curl -s -X POST http://127.0.0.1:3000/api/v1/auths/signin \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@posttest.local","password":"TestPass123!"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")

# 2. หา user ID
USER_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
  http://127.0.0.1:3000/api/v1/users/me | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# 3. ลบตัวเอง (ถ้าไม่ใช่ user คนสุดท้าย)
curl -s -X DELETE -H "Authorization: Bearer $TOKEN" \
  http://127.0.0.1:3000/api/v1/users/$USER_ID

# 4. Verify — login ใหม่ต้อง fail
curl -s -X POST http://127.0.0.1:3000/api/v1/auths/signin \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@posttest.local","password":"TestPass123!"}' \
  | grep -q '"token"' && echo "FAIL: user still exists" || echo "OK: user deleted"
```

### วิธีลบผ่าน Web UI (ง่ายกว่า)

1. Login ด้วย admin account
2. ไป Admin Settings → Users
3. หา `Post Test User` (test@posttest.local) → กด Delete

### หลังลบแล้ว

```bash
# (optional) ปิด signup ถ้าไม่ต้องการให้สมัครใหม่
sed -i 's/ENABLE_SIGNUP=true/ENABLE_SIGNUP=false/' /opt/ollama-openwebui/.env
docker compose -f /opt/ollama-openwebui/docker-compose.yml --env-file /opt/ollama-openwebui/.env up -d
```

