# AnythingLLM — AI Mistakes Log

> Log คำสั่ง AI ที่ผิดระหว่าง build พร้อมวิธีแก้ — ใช้สำหรับ pipeline debug

---

## Build Attempts

| Date | Agent | What went wrong | How fixed |
|---|---|---|---|
| 2026-07-08 | Wakka-GPT | SSH command ใช้ single quotes กับ variable expansion ไม่ถูกต้องใน PowerShell: `$(dpkg --print-architecture)` และ `$(. /etc/os-release && echo \"\${UBUNTU_CODENAME:-\$VERSION_CODENAME}\")` แตกใน Windows PowerShell; output: `dpkg: The term 'dpkg' is not recognized as a name of a cmdlet, function, script file, or executable program.` | แยก command ออกเป็นหลายบรรทัด: 1) ใช้ `dpkg --print-architecture` แยก, 2) อ่าน /etc/os-release ด้วย `cat`, 3) ใช้ echo แทน variable expansion inline. |

---

## Common Pitfalls

- (ถ้ามี)
