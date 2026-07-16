# AnythingLLM Image — Post-Check Checklist

> Checklist สำหรับตรวจสอบ VM ที่สร้างขึ้นจาก AnythingLLM image
> ห้ามใส่ password, temp IP, หรือ credentials ใดๆ ลงในไฟล์นี้

---

## Scope

ใช้สำหรับตรวจสอบว่า Golden Image ที่แคปเจอร์และสร้างใหม่เป็น VM แล้ว ทำงานได้เสร็จสมบูรณ์ตั้งแต่การเริ่มระบบ (Bootstrap) ครั้งแรก

| รายการ | สถานะ | หมายเหตุ |
|---|---|---|
| Build guide พร้อม | ✅ done | `apps/anythingllm/anythingllm.md` |
| Build VM ทำจริง | ✅ done | standalone build |
| Cleanup ก่อน capture | ✅ done | ล้างรหัสผ่านและค่าติดตั้งทดสอบทั้งหมดแล้ว |

---

## Runtime Data Policy

ไฟล์ที่เป็นข้อมูลชั่วคราวที่จะถูกสร้างขึ้นใหม่เมื่อ VM บูตครั้งแรก (และไม่ควรติดไปกับ Golden Image):

| Path | นโยบาย |
|---|---|
| `/opt/anythingllm/.env` | ต้องลบออกก่อนทำการ Capture และต้องถูกสร้างขึ้นใหม่ตอนบูต VM ครั้งแรก |
| `/root/anythingllm-credentials.txt` | ต้องลบออกก่อนทำการ Capture และห้ามคัดลอกเนื้อหาไปเก็บไว้ใน repo |

---

## Post-Check — คำสั่งรันบน VM ที่สร้างจาก image

[anythingllm-test-vm]

### 1. ตรวจสอบการบูตระบบ (Bootstrap service)

```bash
systemctl is-enabled anythingllm-bootstrap.service
systemctl status anythingllm-bootstrap.service --no-pager
```

**ผลลัพธ์ที่ถูกต้อง:** สถานะต้องเป็น `enabled` และไม่มี error failed

### 2. ตรวจสอบสถานะการทำงานของ Containers

```bash
cd /opt/anythingllm
docker compose ps
```

**ผลลัพธ์ที่ถูกต้อง:** คอนเทนเนอร์ 2 ตัว (`anythingllm`, `anythingllm-nginx`) รันอยู่อย่างปกติ (Status: Up)

### 3. ตรวจสอบการตอบสนองผ่าน HTTP

```bash
curl -sI http://localhost | head -3
```

**ผลลัพธ์ที่ถูกต้อง:** ได้รับ HTTP response จาก proxy/app เช่น `200 OK` หรือมีการตอบสนองกลับมา

### 4. ตรวจสอบเนื้อหาหน้าเว็บ

```bash
curl -sL http://localhost | grep -i "anythingllm"
```

**ผลลัพธ์ที่ถูกต้อง:** พบคีย์เวิร์ดเกี่ยวกับ "AnythingLLM" ในหน้าเว็บแรก

### 5. ตรวจสอบไฟล์เก็บค่าความปลอดภัยหลังบูต

```bash
ls -l /opt/anythingllm/.env /root/anythingllm-credentials.txt
```

**ผลลัพธ์ที่ถูกต้อง:** ไฟล์ทั้งสองต้องมีอยู่บนระบบ และสิทธิ์ในการอ่านเขียนเป็น `600` (จำกัดเฉพาะ root)

---

## Success Criteria (เกณฑ์การผ่านการทดสอบ)

| ข้อ | เกณฑ์การทดสอบ |
|---|---|
| 1. Bootstrap service | สถานะ `enabled` และรันสำเร็จ |
| 2. Containers | คอนเทนเนอร์ทั้ง 2 ตัวทำงานปกติ |
| 3. HTTP Response | เข้าพอร์ต 80 ได้ผลลัพธ์ปกติ |
| 4. Setup page | มีหน้าเว็บ AnythingLLM ปรากฏขึ้น |
| 5. Runtime files | ไฟล์ `.env` และ `credentials.txt` ถูกสร้างขึ้นโดยอัตโนมัติ |
