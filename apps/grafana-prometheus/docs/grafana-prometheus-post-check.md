# Grafana+Prometheus Image — Post-Check

> รันหลัง deploy VM หรือหลังสร้าง VM จาก image ครั้งแรก
> ขอบเขต: verify service และ self-service UX เท่านั้น ไม่รวม OpenStack capture/Glance

---

## Pipeline Scope

Post-check นี้ทดสอบ pipeline หลังจาก user/admin สร้าง VM ใหม่จาก image แล้ว ไม่ใช่ pre-capture gate ของ golden-image VM

| Pipeline | ทดสอบอะไร | ไม่ครอบคลุม |
|---|---|---|
| First boot bootstrap | systemd service สร้าง `.env`, generated password, marker และ start stack | OpenStack metadata/floating IP attach |
| Runtime stack | Docker Compose start 6 containers หลักได้จริง | production load test หรือ sizing ระยะยาว |
| Health endpoints | Grafana, Prometheus, Alertmanager healthy บน localhost | external alert delivery เช่น email/LINE/Slack |
| Exposure/security | public เฉพาะ Nginx TCP 80; Prometheus/Alertmanager localhost only | security group provisioning ฝั่ง OpenStack |
| Console/MOTD UX | login console และ `/etc/update-motd.d` ไม่มี error | QEMU/VNC console automation |
| Self-service UX | `monitoring-info`, `monitoring-status`, `monitoring-add-*`, reset password | custom dashboard/customer target design |
| Grafana UX | login จริง, datasource, dashboard provisioning | visual dashboard correctness ทุก panel |
| Observability data | Prometheus เห็น targets หลักและ helper targets | optional cAdvisor profile ถ้าไม่ได้เปิด |
| Reboot persistence | optional final gate: reboot แล้ว state ไม่หาย | ต้องถาม user/admin ก่อน reboot ทุกครั้ง |

ก่อนรัน post-test ต้องถาม cleanup mode:
- `no-cleanup` — ทิ้ง runtime/test targets ไว้ให้ admin/user ตรวจต่อ
- `cleanup-test-targets` — ลบ target ทดสอบหลัง checklist ผ่าน แล้ว reload Prometheus

---

## Post-Test Overview

| Step | Pipeline phase | ตรวจอะไร | Command หลัก | ผ่านเมื่อ | ถ้าพังให้ทำอะไร |
|---|---|---|---|---|---|
| 1 | Console/MOTD UX | MOTD run-parts | `run-parts /etc/update-motd.d` | ไม่มี error และเห็น Grafana MOTD | แก้ MOTD source/line ending/permission |
| 2 | First boot bootstrap | bootstrap service | `systemctl status grafana-prometheus-bootstrap.service` | enabled และ completed สำเร็จ | แก้ bootstrap service/script หรือ build guide |
| 3 | Runtime state | `.env`, README, marker | `test -f ...` + `grep Password` | runtime files มีครบและ README มี password | แก้ first boot script/source |
| 4 | Container runtime | 6 containers หลัก | `docker compose ... ps` | containers หลัก running | ดู container logs แล้วแก้ compose/config/source |
| 5 | Health check | local endpoints | `curl 127.0.0.1` ports 80/9090/9093 | Grafana/Prometheus/Alertmanager OK | แก้ service config หรือ readiness logic |
| 6 | Exposure/security | public vs localhost bind | `ss -lntp` | public เฉพาะ TCP 80, 9090/9093 localhost | แก้ compose ports/proxy config ทันที |
| 7 | Self-service UX | info command | `monitoring-info` | เห็น URL, admin username, generated password, quick commands | แก้ helper script/README generation |
| 8 | Grafana UX | login จริงด้วย password runtime | Grafana API `/api/user` | password จาก `monitoring-info` ใช้ได้จริง | แก้ password generation/reset/bootstrap |
| 9 | Grafana UX | provisioning | Grafana API datasource/dashboard | Prometheus datasource และ dashboard มีจริง | แก้ provisioning source |
| 10 | Self-service UX | status/list/add target helpers | `monitoring-status`, `monitoring-add-*` | Prometheus reload สำเร็จและ target แสดงใน list | แก้ helper script/YAML generation/reload logic |
| 11 | Persistence | reset password | `monitoring-reset-grafana-password` | password ใหม่ login ได้, password เก่า fail, targets ไม่หาย | แก้ reset script/source ทันที |
| 12 | Observability data | Prometheus active targets | `/api/v1/targets` | core targets up; helper targets scrape ได้ | แยก expected optional down ก่อนแก้ source |
| 13 | Cleanup mode | no-cleanup/cleanup-test-targets | ถาม user/admin | ทำตาม mode ที่เลือกเท่านั้น | แก้ post-check flow ถ้าทำผิด mode |
| 14 | Optional final reboot gate | reboot persistence | ถาม user/admin ก่อน `reboot` | หลัง reboot state/password/targets ยังอยู่ | แก้ persistence/firstboot idempotency |

---

## Failure Routing

| อาการ | นับเป็น bug ไหม | ส่งผลต่อ pipeline | Action |
|---|---|---|---|
| service disabled หรือ bootstrap exit non-zero | ใช่ | First boot pipeline | แก้ bootstrap service/script และ build guide |
| `.env`/README/marker ไม่เกิด หรือ README ไม่มี `Password:` | ใช่ | First boot runtime state | แก้ bootstrap script |
| image ต้อง pull ใหม่ตอน first boot | ใช่ | Golden image pre-pull/pre-capture | แก้ build guide และ pre-capture gate |
| container restart loop | ใช่ | Runtime stack | ดู logs แล้วแก้ compose/config/source |
| `9090` หรือ `9093` bind public | ใช่ | Exposure/security | แก้ compose ports ทันที |
| `monitoring-add-*` reload fail | ใช่ | Self-service UX | แก้ helper script และ post-check expected output |
| reset password แล้ว targets/dashboards หาย | ใช่ | Persistence | แก้ reset script ทันที |
| password จาก `monitoring-info` login Grafana ไม่ได้ | ใช่ | Grafana UX / first boot password | แก้ bootstrap/password generation |
| reset แล้ว password ใหม่ login ไม่ได้ หรือ password เก่ายัง login ได้ | ใช่ | Reset password UX | แก้ reset script และ verify command |
| datasource/dashboard ไม่ provision | ใช่ | Grafana provisioning | แก้ provisioning YAML/dashboard source |
| `run-parts /etc/update-motd.d` error | ใช่ | Console/MOTD UX | แก้ MOTD source, permission, shebang/CRLF แล้วเพิ่ม post-check |
| reboot แล้ว password/targets/state หาย | ใช่ | Persistence/reboot final gate | แก้ firstboot idempotency และ volume/state handling |
| `cadvisor` target `down` โดยไม่ได้เปิด profile | ไม่ใช่ | Expected optional exception | ไม่ต้องแก้ source; cAdvisor เป็น optional profile |
| target test ซ้ำหลังรัน no-cleanup ซ้ำ | ไม่ใช่ ถ้าตั้งใจ no-cleanup | Manual inspection mode | ปล่อยไว้ หรือ cleanup เฉพาะ test targets ถ้าจะส่งมอบ |
| password แสดงใน log post-test | ใช่ ถ้า AI/log เก็บ secret | Secret handling | redact output และห้ามบันทึก password ลง repo |

ถ้า post-test เจอ bug จริง ให้แก้ source/guide/docs ตาม root cause ในรอบเดียวกัน และบันทึก `{app}-errors.md` เมื่อเป็นคำสั่ง AI ที่พังจริง.

---

## Post-Check — 14 ข้อ

### 1. Console / MOTD UX works

```bash
test -x /etc/update-motd.d/99-grafana-prometheus-image && echo motd-executable
file /etc/update-motd.d/99-grafana-prometheus-image
head -1 /etc/update-motd.d/99-grafana-prometheus-image | od -An -tx1
run-parts --test /etc/update-motd.d | grep 99-grafana-prometheus-image
run-parts /etc/update-motd.d >/tmp/grafana-motd-test.out
grep -q 'Grafana + Prometheus Monitoring System' /tmp/grafana-motd-test.out && echo motd-ok
```

ต้องได้:
- `motd-executable`
- `motd-ok`
- `run-parts` ไม่มี error
- shebang ไม่มี byte `0d` ก่อน `0a` จาก CRLF

ถ้าพังแบบ `failed to exec ... No such file or directory` ทั้งที่ file มีอยู่ ให้สงสัย CRLF ใน shebang แล้วแก้ source/guide ด้วย `sed -i 's/\r$//'`.

### 2. Bootstrap service completed

```bash
systemctl is-enabled grafana-prometheus-bootstrap.service
systemctl is-active grafana-prometheus-bootstrap.service
systemctl status grafana-prometheus-bootstrap.service --no-pager
```

ต้องได้:
- `enabled`
- `active` หรือ `inactive` แบบ oneshot ที่ completed สำเร็จ
- ไม่มี error ใน status ล่าสุด

### 3. Runtime files exist

```bash
test -f /opt/monitoring/.env && echo env-ok
test -f /root/README-grafana-prometheus-image.txt && echo info-ok
grep -q '^  Password: ' /root/README-grafana-prometheus-image.txt && echo info-password-ok
test "$(stat -c '%a' /root/README-grafana-prometheus-image.txt)" = "600" && echo info-permission-ok
test -f /var/lib/grafana-prometheus-firstboot.done && echo marker-ok
```

ต้องได้:
- `env-ok`
- `info-ok`
- `info-password-ok`
- `info-permission-ok`
- `marker-ok`

ถ้า marker มีแล้วแต่ README หายหรือไม่มี `Password:` ให้สงสัย bootstrap idempotency: service รอบถัดไปต้อง repair README จาก `/opt/monitoring/.env` โดยไม่ reset password และไม่ลบ Docker volumes.

### 4. Containers running

```bash
docker compose -f /opt/monitoring/docker-compose.yml --env-file /opt/monitoring/.env ps
```

ต้องเห็น containers หลัก:
- `grafana`
- `prometheus`
- `alertmanager`
- `node-exporter`
- `blackbox-exporter`
- `monitoring-nginx`

### 5. HTTP endpoints healthy

```bash
curl -fsS http://127.0.0.1/ >/dev/null && echo grafana-ok
curl -fsS http://127.0.0.1:9090/-/healthy && echo prometheus-ok
curl -fsS http://127.0.0.1:9093/-/healthy && echo alertmanager-ok
```

ต้องได้:
- `grafana-ok`
- `Prometheus Server is Healthy.`
- `OK`

### 6. Public service exposure is limited

```bash
ss -lntp | grep -E ':80|:9090|:9093' || true
```

ต้องได้:
- TCP `80` bind public สำหรับ Nginx
- TCP `9090` bind `127.0.0.1` เท่านั้น
- TCP `9093` bind `127.0.0.1` เท่านั้น

### 7. Self-service info works

```bash
sudo monitoring-info | head -30
```

ต้องเห็น:
- Grafana URL
- Username `admin`
- generated password
- quick commands

ถ้า AI เก็บ output ลง log ให้ redact บรรทัด password เสมอ.

### 8. Grafana login works with generated password

```bash
grafana_password=$(awk -F': ' '/Password:/ {print $2; exit}' /root/README-grafana-prometheus-image.txt)
test -n "$grafana_password" && echo password-present
curl -fsS -u "admin:${grafana_password}" http://127.0.0.1/api/user | jq -r '.login'
```

ต้องได้:
- `password-present`
- `admin`

ห้าม echo password จริงลง output ที่จะบันทึกใน repo หรือ chat log.

### 9. Grafana datasource and dashboard are provisioned

```bash
grafana_password=$(awk -F': ' '/Password:/ {print $2; exit}' /root/README-grafana-prometheus-image.txt)
curl -fsS -u "admin:${grafana_password}" http://127.0.0.1/api/datasources | jq -r '.[] | [.name, .uid, .type, (.isDefault|tostring)] | @tsv'
curl -fsS -u "admin:${grafana_password}" 'http://127.0.0.1/api/search?query=&type=dash-db' | jq -r '.[].title'
```

ต้องเห็น:
- datasource `Prometheus` uid `prometheus` type `prometheus`
- datasource `Alertmanager` uid `alertmanager` type `alertmanager`
- dashboard อย่างน้อยหนึ่งรายการ เช่น self-service overview

### 10. Status command works

```bash
sudo monitoring-status
```

ต้องเห็น:
- container table
- Grafana via Nginx: OK
- Prometheus: OK
- Alertmanager: OK
- target summary
- disk summary

### 11. Target helpers work

```bash
sudo monitoring-add-http http://127.0.0.1/ local-grafana-test
sudo monitoring-add-tcp 127.0.0.1:80 local-nginx-test
sudo monitoring-add-ping 127.0.0.1 local-ping-test
sudo monitoring-list-targets
```

ต้องได้:
- Prometheus reload สำเร็จ
- targets ใหม่แสดงใน list
- ไม่มี YAML syntax error จาก reload

### 12. Reset Grafana password works and old password stops working

```bash
old_password=$(awk -F': ' '/Password:/ {print $2; exit}' /root/README-grafana-prometheus-image.txt)
before_targets=$(grep -R "local-grafana-test\|local-nginx-test\|local-ping-test" /opt/monitoring/prometheus/targets | wc -l)
sudo monitoring-reset-grafana-password
new_password=$(awk -F': ' '/Password:/ {print $2; exit}' /root/README-grafana-prometheus-image.txt)
after_targets=$(grep -R "local-grafana-test\|local-nginx-test\|local-ping-test" /opt/monitoring/prometheus/targets | wc -l)
test -n "$new_password" && test "$old_password" != "$new_password" && echo password-changed
test "$before_targets" = "$after_targets" && echo targets-preserved
curl -fsS -u "admin:${new_password}" http://127.0.0.1/api/user | jq -r '.login'
if curl -fsS -u "admin:${old_password}" http://127.0.0.1/api/user >/dev/null; then
  echo old-password-still-valid
  exit 1
fi
echo old-password-rejected
```

ต้องได้:
- `password-changed`
- `targets-preserved`
- `admin` จาก API login ด้วย password ใหม่
- `old-password-rejected`
- dashboards/targets ไม่หาย

ห้าม echo password จริงลง output ที่จะบันทึกใน repo หรือ chat log.

### 13. Prometheus sees targets

```bash
curl -fsS http://127.0.0.1:9090/api/v1/targets | jq -r '.data.activeTargets[] | [.labels.job, .labels.instance, .health] | @tsv'
```

ต้องเห็น:
- `prometheus` target `up`
- `node` target `up`
- `blackbox_http` self-check target อย่างน้อยหนึ่งรายการ
- target ที่เพิ่มในข้อ 11 เริ่มแสดงหลังรอ scrape interval

Expected exception:
- `cadvisor` target อาจ `down` ถ้าไม่ได้เปิด optional cAdvisor profile

### 14. Optional final reboot persistence gate

ขั้นตอนนี้ต้องถาม user/admin ก่อนเสมอ และต้องทำเป็นขั้นตอนสุดท้ายเท่านั้น.

ถ้า user/admin อนุมัติ reboot:

```bash
before_password_hash=$(sha256sum /root/README-grafana-prometheus-image.txt | awk '{print $1}')
before_targets=$(grep -R "local-grafana-test\|local-nginx-test\|local-ping-test" /opt/monitoring/prometheus/targets | wc -l)
reboot
```

หลัง SSH กลับมา:

```bash
systemctl status grafana-prometheus-bootstrap.service --no-pager
docker compose -f /opt/monitoring/docker-compose.yml --env-file /opt/monitoring/.env ps
curl -fsS http://127.0.0.1/ >/dev/null && echo grafana-ok
curl -fsS http://127.0.0.1:9090/-/healthy && echo prometheus-ok
curl -fsS http://127.0.0.1:9093/-/healthy && echo alertmanager-ok
after_password_hash=$(sha256sum /root/README-grafana-prometheus-image.txt | awk '{print $1}')
after_targets=$(grep -R "local-grafana-test\|local-nginx-test\|local-ping-test" /opt/monitoring/prometheus/targets | wc -l)
test "$before_password_hash" = "$after_password_hash" && echo password-state-preserved
test "$before_targets" = "$after_targets" && echo targets-preserved-after-reboot
```

ต้องได้:
- service ยัง completed สำเร็จ
- containers กลับมา running
- health OK ทั้ง 3 endpoint
- password state ไม่ regenerate ใหม่
- targets ที่เพิ่มไว้ยังอยู่

ถ้า user/admin ไม่อนุมัติ reboot ให้บันทึกในสรุปว่าไม่ได้ทำ reboot persistence test.

---

## Success Criteria

| ข้อ | Required | Optional / Expected exception |
|---|---|---|
| Bootstrap | service enabled และ completed | — |
| Console/MOTD | `run-parts /etc/update-motd.d` ไม่มี error และมี Grafana MOTD | — |
| Runtime files | `.env`, README, marker มีครบ | — |
| Containers | 6 containers หลัก running | cAdvisor ไม่ต้อง running ถ้าไม่เปิด profile |
| HTTP | Grafana/Prometheus/Alertmanager healthy | — |
| Exposure | public เฉพาะ port 80; 9090/9093 localhost | — |
| Grafana UX | generated password login ได้, datasource/dashboard มีจริง | — |
| Self-service | `monitoring-info`, `monitoring-status`, add target, reset password ใช้ได้ | duplicate test targets ไม่ fail ถ้ารัน no-cleanup ซ้ำ |
| Persistence | reset password ใหม่ login ได้, password เก่า fail, targets/dashboards/metrics ไม่หาย | password ใหม่เป็น runtime secret ห้ามบันทึกลง repo |
| Prometheus targets | core targets active และ health ถูกต้อง | `cadvisor` down ได้ถ้า optional profile ไม่เปิด |
| Reboot final gate | ถ้า user/admin อนุมัติ reboot: state/password/targets ต้องอยู่หลัง reboot | ข้ามได้ถ้า user/admin ไม่อนุมัติ |

ผ่านทุกข้อ = deploy ใช้งานได้จริง

### Latest Verified Result

| Date | Scope | Result | Notes |
|---|---|---|---|
| 2026-06-16 | Full post-test except reboot final gate | PASS | `no-cleanup` mode, target helpers PASS, password reset PASS, old password rejected, targets preserved, cAdvisor `down` treated as expected optional exception |
| 2026-06-16 | Golden-image cleanup after post-test | PASS | runtime `.env`, README, marker, bootstrap log, containers, and monitoring volumes removed; bootstrap service still enabled; package cache kept |

Reboot persistence gate was explicitly skipped by user/admin. Do not mark reboot persistence as tested for this run.

---

## Post-Test Mode — ไม่ Cleanup สำหรับ Manual Inspection

ใช้โหมดนี้เมื่อ post-test บน VM ที่ต้องการให้ admin/user เข้าไปตรวจต่อหลัง checklist เสร็จ

ต้องถาม user/admin ก่อนเข้าโหมดนี้ทุกครั้ง ห้าม default เอง

หลังรันข้อ 1-14 แล้วให้คงสถานะ runtime ไว้ทั้งหมด:
- ไม่ลบ target ทดสอบที่เพิ่มด้วย `monitoring-add-*`
- ไม่ลบ `/opt/monitoring/.env`
- ไม่ลบ `/root/README-grafana-prometheus-image.txt`
- ไม่ลบ `/var/lib/grafana-prometheus-firstboot.done`
- ไม่ stop containers
- ไม่ลบ Docker volumes
- ไม่ลบ logs/runtime state
- ไม่ poweroff VM

ผลลัพธ์ที่ต้องการ:
- VM ยัง running
- containers ยัง running
- Grafana password ล่าสุดดูได้จาก `sudo monitoring-info`
- test targets ยังอยู่ให้ตรวจใน Grafana/Prometheus ต่อได้
- admin/user เข้า `http://<VM-IP>/` และ SSH ไปตรวจต่อได้ทันที

ข้อควรรู้:
- reset password ในข้อ 12 เปลี่ยน password จริงของ VM นี้
- ถ้ารัน post-test ซ้ำใน no-cleanup mode target test อาจซ้ำได้ ถือว่า expected สำหรับ manual inspection
- ถ้าต้องส่งมอบ VM ต่อ ให้ cleanup เฉพาะ target ทดสอบก่อนส่งมอบ

ถ้าเป็น VM ที่จะส่งมอบให้ลูกค้าทันที ให้ใช้ section cleanup ด้านล่างเพื่อลบ target ทดสอบก่อนส่งมอบ

---

## Cleanup หลัง post-test ถ้าต้องการลบ target ทดสอบ

Post-check เพิ่ม target ทดสอบเข้าไฟล์จริง ถ้าต้องการลบก่อนส่งลูกค้า:

```bash
sed -i '/local-grafana-test/,+3d' /opt/monitoring/prometheus/targets/http.yml
sed -i '/local-nginx-test/,+3d' /opt/monitoring/prometheus/targets/tcp.yml
sed -i '/local-ping-test/,+3d' /opt/monitoring/prometheus/targets/ping.yml
sudo monitoring-reload
```

ถ้าเป็น post-test บน VM ที่จะส่งให้ลูกค้าจริง ให้ลบ target ทดสอบก่อนส่งมอบ.
