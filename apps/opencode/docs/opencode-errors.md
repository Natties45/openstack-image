# OpenCode — AI Build Errors Log

> บันทึกทุกครั้งที่ AI ให้คำสั่งแล้วพังระหว่าง build/deploy/post-test

---

## Error Log

| ครั้งที่ | วันที่ | คำสั่งที่ผิด | Error | สาเหตุ | วิธีแก้ | สถานะ |
|---|---|---|---|---|---|---|
| 1 | 2026-06-21 | `systemctl start opencode.service` (ก่อนสร้าง dirs) | `status=226/NAMESPACE` — `Failed to set up mount namespacing: /home/opencode/.cache: No such file or directory` | `ReadWritePaths=/home/opencode/.local /home/opencode/.cache` แต่ directory ยังไม่ถูกสร้าง — systemd namespace mount ต้องการ path ที่มีอยู่จริงตอน ExecStart | เพิ่ม `mkdir -p /home/opencode/.local/share/opencode /home/opencode/.cache/opencode && chown opencode:opencode` ใน Phase C.1 หลัง `useradd` | ✅ แก้แล้ว |
| 2 | 2026-06-21 | `bash /usr/local/sbin/opencode-bootstrap.sh` | (1) Script พังกลางทางจาก `pipefail` + `head` SIGPIPE (2) `head -c 32 /dev/urandom \| tr -dc 'A-Za-z0-9' \| head -c 16` ได้แค่ 8 ตัว เพราะ random binary มี alphanumeric ~24% → 32 bytes ได้ ~8 chars | (1) `tr` โดน SIGPIPE จาก `head -c` ตัด pipe ใน `set -o pipefail` (2) `/dev/urandom` เป็น binary ส่วนใหญ่ไม่ใช่ alphanumeric | ใช้ `openssl rand -base64 18 \| tr -d '+/=' \| head -c 16` — ไม่มี pipefail, ได้ 16 chars แน่นอน | ✅ แก้แล้ว |
| 3 | 2026-06-21 | รีบูท VM → bootstrap ค้างที่ `systemctl enable --now opencode.service` | Deadlock: `opencode.service` มี `After=opencode-bootstrap.service` แต่ bootstrap เป็นคนเรียก `systemctl start` เอง → systemd รอให้ bootstrap จบก่อนถึงจะ start service ได้ → bootstrap ก็รอ systemctl → deadlock 5+ นาที | `After=` คร่อม dependency วงกลม — bootstrap start service แต่ service บอกต้องรอ bootstrap จบก่อน | ลบ `opencode-bootstrap.service` ออกจาก `After=` ใน `opencode.service` — bootstrap รับประกันลำดับเองอยู่แล้ว | ✅ แก้แล้ว |
| 4 | 2026-06-21 | เปิด `opencode.service` หลังเพิ่ม provider | OpenCode log `EROFS` เขียน `/home/opencode/.config/opencode/.gitignore` ไม่ได้ | systemd hardening ตั้ง `.config` เป็น read-only แต่ OpenCode ต้องเขียนไฟล์ภายใน config dir | เปลี่ยน `ReadWritePaths` ให้รวม `/home/opencode/.config` และลบ `ReadOnlyPaths` | ✅ แก้แล้ว |

---

## Pattern Notes

- **xdg-open ENOENT**: ถ้า headless server เกิด error `Executable not found in $PATH: "xdg-open"` → `/usr/local/bin/xdg-open` fake script ยังไม่ได้สร้าง หรือ permission ไม่ถูกต้อง
- **Binary not found**: `/usr/local/bin/opencode` หาย → เช็คว่า Phase C.2 รันสำเร็จ, binary เป็น ELF 64-bit
- **Service won't start**: `opencode.service` failed → `/etc/opencode/environment` ยังไม่มี → bootstrap ยังไม่รัน หรือรันแล้วแต่ fail
- **Port 4096 already in use**: มี process อื่น bind อยู่แล้ว → `ss -tlnp | grep 4096`

---

**Version:** 2026-06-21
**Maintained by:** Cloud (build agent)
