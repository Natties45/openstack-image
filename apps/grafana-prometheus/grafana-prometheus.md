# Grafana+Prometheus Image — Ubuntu 26.04 [ผ่านตรวจ]

> Image สำเร็จรูป: สร้าง VM → Grafana + Prometheus + Alertmanager พร้อมใช้ → ลูกค้าเพิ่ม VM/URL/port ที่ต้องการ monitor เองได้แบบ self-service
> **Customer Service Model:** 2B (Fully Auto — พร้อมใช้ทันทีหลัง boot, generated password, pre-provisioned dashboard)

---

## เป้าหมาย

```text
ลูกค้าสร้าง VM จาก image
→ systemd เรียก grafana-prometheus-bootstrap.sh ตอน first boot
→ สุ่ม Grafana admin password ต่อ VM
→ start Grafana + Prometheus + Alertmanager + node_exporter + blackbox_exporter + Nginx
→ เขียน /root/README-grafana-prometheus-image.txt
→ ลูกค้าเปิด http://<VM-IP>/ ใช้งาน Grafana ได้ทันที
→ ลูกค้าเพิ่ม target เองด้วย monitoring-add-* commands
```

| รายการ | ค่า |
|---|---|
| Base OS | Ubuntu 26.04 |
| Runtime | Docker CE + Docker Compose plugin |
| UI | Grafana OSS 11.6.5 |
| Metrics | Prometheus 3.13.1 LTS |
| Alerting | Alertmanager 0.33.1 |
| Exporters | Node Exporter 1.12.0, Blackbox Exporter master-distroless |
| Proxy | Nginx stable-alpine |
| Customer Service Model | 2B (Fully Auto) |
| Optional | cAdvisor profile สำหรับ Docker metrics |
| Minimum flavor | 2 vCPU / 2GB RAM / 15GB disk |

### Container Images (pinned tag + digest)

| Container | Image | Tag | Digest |
|---|---|---|---|
| Grafana | `grafana/grafana-oss` | `11.6.5` | `sha256:d552f949693c54d17c6f867ff6aeb128b021e54e923895dcf9cd6aa8176c0d74` |
| Prometheus | `prom/prometheus` | `v3.13.1` | ⚠️ verify digest before build |
| Alertmanager | `prom/alertmanager` | `v0.33.1` | `sha256:9e082985f56f4c8c9f724e18f2288c6708f472e56a5286b8863d080434ea065d` |
| Node Exporter | `prom/node-exporter` | `v1.12.0` | `sha256:9b0ade5e607f9dbedb0a8e11151b6011ae5bd79304c261804cfdd2cadf200a80` |
| Blackbox Exporter | `prom/blackbox-exporter` | `master-distroless` | ⚠️ verify digest before build |
| Nginx | `nginx` | `stable-alpine` | ⚠️ verify digest before build |

> **Digest verification:** ก่อน build ให้ `docker pull` แต่ละ image ที่ยังไม่มี digest แล้ว `docker images --digests` เพื่อนำ digest มาใส่ใน `docker-compose.yml`

---

## Customer URLs

| Service | URL | Login |
|---|---|---|
| Grafana | `http://<VM-IP>/` | `sudo monitoring-info` |
| Prometheus | `http://127.0.0.1:9090` on VM only | local admin/debug |
| Alertmanager | `http://127.0.0.1:9093` on VM only | local admin/debug |

Security group / firewall:
- Public/customer: TCP `80`
- Admin SSH: TCP `22`
- Target node metrics: target VMs allow TCP `9100` from monitoring VM
- Target HTTP/TCP checks: monitoring VM must reach target URL/IP/port

---

## Self-Service Commands

| Command | Purpose |
|---|---|
| `sudo monitoring-info` | แสดง Grafana URL, username, generated password, quick commands |
| `sudo monitoring-status` | เช็ค container, health endpoint, target summary, disk |
| `sudo monitoring-list-targets` | ดู target files ที่กำลัง monitor |
| `sudo monitoring-add-http https://example.com website` | เพิ่ม HTTP/HTTPS uptime target |
| `sudo monitoring-add-node 10.0.0.12:9100 web-01` | เพิ่ม Linux VM metrics target ที่มี node_exporter |
| `sudo monitoring-add-tcp 10.0.0.20:5432 postgres-01` | เพิ่ม TCP port target |
| `sudo monitoring-add-ping 10.0.0.30 router-01` | เพิ่ม ICMP reachability target |
| `sudo monitoring-remove-target my-site` | ลบเป้าหมายการเฝ้าระวังออก |
| `sudo monitoring-setup-webhook https://hooks.slack.com/...` | ตั้งค่า LINE/Slack/Discord webhook สำหรับแจ้งเตือน |
| `sudo monitoring-update` | อัปเดตระบบพร้อม Rollback เมื่ออัปเดตไม่ผ่าน |
| `sudo monitoring-logs [container]` | ดู logs ล่าสุดของ containers (50 บรรทัด) |
| `sudo monitoring-restart [container]` | restart containers ตัวใดตัวหนึ่งหรือทั้งหมด |
| `sudo monitoring-reset-grafana-password` | reset Grafana admin password โดยไม่ลบ data |

ไม่มี snapshot-prep command สำหรับลูกค้า เพราะ image นี้เป็น self-service สำหรับใช้งาน VM โดยตรง ไม่ใช่ admin golden-image lifecycle.

---

## ก่อนเริ่ม — Pre-flight Verification

| เช็ค | ได้จาก | ถ้ายังไม่พร้อม |
|---|---|---|
| Guest image Ubuntu 26.04 สร้างเสร็จแล้ว | `_guest-images.md` → Ubuntu 26.04 | ต้องสร้าง guest image ก่อน |
| VM สร้างจาก guest image ที่ผ่าน Set 1-3 ครบ | standalone build | สร้าง VM จาก guest image |
| Build guide พร้อม `[พร้อม build]` | header tag บน | ต้องสร้าง source files ก่อน |
| SSH credentials | `tmp/grafana-prometheus-build.env` (gitignored) | — |

เมื่อ SSH เข้า VM แล้ว verify:

```bash
lsb_release -a | grep Release
grep URIs /etc/apt/sources.list.d/ubuntu.sources
curl -sI https://download.docker.com | head -1
df -h /
free -h
```

ต้องได้:
- Ubuntu 26.04 หรือ codename ที่ตรงกับ guest image
- DNS ออก internet ได้
- disk free มากกว่า 8GB
- RAM อย่างน้อย 2GB

---

## โครงสร้างไฟล์บน VM

```text
/opt/monitoring/docker-compose.yml
/opt/monitoring/.env                                      (first boot สร้างจริง)
/opt/monitoring/nginx/default.conf
/opt/monitoring/nginx/default.conf.template               (HTTPS template — golden rule #3)
/opt/monitoring/prometheus/prometheus.yml
/opt/monitoring/prometheus/rules/alerts.yml
/opt/monitoring/prometheus/targets/{nodes,http,tcp,ping,cadvisor}.yml
/opt/monitoring/blackbox/blackbox.yml
/opt/monitoring/alertmanager/alertmanager.yml
/opt/monitoring/grafana/provisioning/datasources/prometheus.yml
/opt/monitoring/grafana/provisioning/dashboards/default.yml
/opt/monitoring/grafana/dashboards/self-service-overview.json
/usr/local/sbin/grafana-prometheus-bootstrap.sh
/usr/local/sbin/monitoring-*
/usr/local/bin/monitoring-*                               (symlink → /usr/local/sbin/ — golden rule #6)
/usr/local/sbin/monitoring-logs                           (view container logs)
/usr/local/sbin/monitoring-restart                        (restart monitoring containers)
/etc/systemd/system/grafana-prometheus-bootstrap.service
/root/README-grafana-prometheus-image.txt                 (first boot เขียน generated password)
/etc/update-motd.d/99-grafana-prometheus-image
```

ไฟล์/สถานะที่ต้องไม่มีใน Golden Image:

```text
/opt/monitoring/.env
/root/README-grafana-prometheus-image.txt ที่มี generated password จริง
/var/log/grafana-prometheus-bootstrap.log
/var/lib/grafana-prometheus-firstboot.done
running containers
Docker volumes grafana_data, prometheus_data, alertmanager_data
runtime credentials
```

---

## ขั้นตอน Build

### 1. ติดตั้ง base packages

[golden-image VM]

```bash
apt update && apt install -y ca-certificates curl gnupg openssl jq vim htop net-tools
```

### 2. ติดตั้ง Docker CE + plugins

[golden-image VM]

```bash
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# อัปโหลดไฟล์จาก repository ไปยัง VM: source/docker.sources → /etc/apt/sources.list.d/docker.sources
# (หมายเหตุ: สคริปต์อัตโนมัติจะประเมินและตั้งค่า Suites/Architectures ให้ตรงกับ OS ของ VM)

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
```

### 2.5 Configure Docker log rotation

[golden-image VM]

```bash
mkdir -p /etc/docker
# อัปโหลดไฟล์จาก repository ไปยัง VM: source/daemon.json → /etc/docker/daemon.json
systemctl restart docker
```

### 3. สร้าง directories

[golden-image VM]

```bash
mkdir -p /opt/monitoring/{nginx,prometheus/rules,prometheus/targets,blackbox,alertmanager,grafana/provisioning/datasources,grafana/provisioning/dashboards,grafana/dashboards}
chmod 755 /opt/monitoring
```

### 4. วาง source files

> Source files อยู่ใน `apps/grafana-prometheus/` สำหรับตรวจสอบและ copy ได้โดยตรง
> ถ้าต้อง copy-paste บน VM ให้ใช้เนื้อหาไฟล์จาก source folder นี้วาง path ตามโครงสร้างด้านบน

ไฟล์ source ที่ต้องวาง:
- `docker-compose.yml` → `/opt/monitoring/docker-compose.yml`
- `nginx/default.conf` → `/opt/monitoring/nginx/default.conf`
- `nginx/default.conf.template` → `/opt/monitoring/nginx/default.conf.template`
- `prometheus/prometheus.yml` → `/opt/monitoring/prometheus/prometheus.yml`
- `prometheus/rules/alerts.yml` → `/opt/monitoring/prometheus/rules/alerts.yml`
- `prometheus/targets/*.yml` → `/opt/monitoring/prometheus/targets/`
- `blackbox/blackbox.yml` → `/opt/monitoring/blackbox/blackbox.yml`
- `alertmanager/alertmanager.yml` → `/opt/monitoring/alertmanager/alertmanager.yml`
- `grafana/provisioning/**` → `/opt/monitoring/grafana/provisioning/`
- `grafana/dashboards/*.json` → `/opt/monitoring/grafana/dashboards/`
- `grafana-prometheus-bootstrap.sh` → `/usr/local/sbin/grafana-prometheus-bootstrap.sh`
- `scripts/monitoring-*` → `/usr/local/sbin/`
- `grafana-prometheus-bootstrap.service` → `/etc/systemd/system/grafana-prometheus-bootstrap.service`
- `99-grafana-prometheus-image` → `/etc/update-motd.d/99-grafana-prometheus-image`

ตั้ง permission:

```bash
chmod +x /usr/local/sbin/grafana-prometheus-bootstrap.sh
chmod +x /usr/local/sbin/monitoring-*
chmod +x /etc/update-motd.d/99-grafana-prometheus-image
chmod 644 /opt/monitoring/alertmanager/alertmanager.yml
sed -i 's/\r$//' /usr/local/sbin/grafana-prometheus-bootstrap.sh /usr/local/sbin/monitoring-* /etc/update-motd.d/99-grafana-prometheus-image
# สร้าง symlink จาก /usr/local/sbin/monitoring-* → /usr/local/bin/ (golden rule #6)
for cmd in /usr/local/sbin/monitoring-*; do
  ln -sf "$cmd" "/usr/local/bin/$(basename "$cmd")"
done
```

### 5. Enable bootstrap service

[golden-image VM]

```bash
systemctl daemon-reload
systemctl enable grafana-prometheus-bootstrap.service
```

### 6. Validate static configs ก่อน pull

[golden-image VM]

```bash
docker compose -f /opt/monitoring/docker-compose.yml config >/tmp/grafana-prometheus-compose.yml
docker run --rm --entrypoint promtool -v /opt/monitoring/prometheus:/etc/prometheus:ro prom/prometheus:latest check config /etc/prometheus/prometheus.yml
docker run --rm --entrypoint promtool -v /opt/monitoring/prometheus/rules:/rules:ro prom/prometheus:latest check rules /rules/alerts.yml
```

### 7. Pre-pull images

[golden-image VM]

```bash
docker compose -f /opt/monitoring/docker-compose.yml pull
```

ถ้าต้องการ pre-pull optional cAdvisor:

```bash
docker compose -f /opt/monitoring/docker-compose.yml --profile cadvisor pull
```

### 8. Test first boot bootstrap บน build VM

[golden-image VM]

```bash
/usr/local/sbin/grafana-prometheus-bootstrap.sh
docker compose -f /opt/monitoring/docker-compose.yml --env-file /opt/monitoring/.env ps
curl -fsS http://127.0.0.1/ >/dev/null && echo grafana-ok
curl -fsS http://127.0.0.1:9090/-/healthy >/dev/null && echo prometheus-ok
curl -fsS http://127.0.0.1:9093/-/healthy >/dev/null && echo alertmanager-ok
sudo monitoring-status
```

### 9. Phase 1 — App cleanup runtime state ก่อน capture

[golden-image VM]

> ขั้นตอนนี้สำหรับ build golden image เท่านั้น ไม่ใช่ command ที่ลูกค้าต้องใช้. AI ต้อง verify ทุกขั้นผ่าน MCP SSH; หลัง Phase 1 ยัง SSH เข้าได้.

```bash
docker compose -f /opt/monitoring/docker-compose.yml --env-file /opt/monitoring/.env down -v
rm -f /opt/monitoring/.env
rm -f /root/README-grafana-prometheus-image.txt
rm -f /var/log/grafana-prometheus-bootstrap.log
rm -f /var/lib/grafana-prometheus-firstboot.done
docker volume rm grafana_data prometheus_data alertmanager_data 2>/dev/null || true
docker system prune -f
systemctl daemon-reload
```

ห้ามใช้ `apt autoremove` หรือ `apt clean` เพราะต้องเก็บ package cache ตาม policy domain.

### 10. Pre-Capture Gate — AI verify after Phase 1

[golden-image VM]

```bash
test ! -f /opt/monitoring/.env
test ! -f /root/README-grafana-prometheus-image.txt
test ! -f /var/lib/grafana-prometheus-firstboot.done
docker ps --format '{{.Names}}'
docker volume ls
systemctl is-enabled grafana-prometheus-bootstrap.service
```

ต้องได้:
- ไม่มี running containers
- ไม่มี generated `.env`
- ไม่มี generated password file
- bootstrap service enabled

AI ต้องถาม user ก่อน Phase 2 เพราะ Phase 2 จะลบ SSH access และ poweroff.

### 11. Phase 2 — OS cleanup + poweroff (final)

[golden-image VM]

```bash
cloud-init clean --logs --seed
rm -rf /var/lib/cloud/instances/* /var/lib/cloud/instance /var/lib/cloud/sem/*
rm -f /etc/netplan/50-cloud-init.yaml 2>/dev/null || true
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id 2>/dev/null || true
ln -sf /etc/machine-id /var/lib/dbus/machine-id 2>/dev/null || true
rm -f /root/.bash_history /home/*/.bash_history
rm -rf /tmp/* /var/tmp/*
find /var/log -type f -name '*.log' -exec truncate -s 0 {} +
truncate -s 0 /var/log/wtmp /var/log/btmp /var/log/lastlog 2>/dev/null || true
rm -f /etc/ssh/ssh_host_*
find /etc/ssh/sshd_config.d -maxdepth 1 -type f -name '*.conf' ! -name '00-image-build.conf' -delete 2>/dev/null || true
fstrim -av || true
sync
rm -f /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys
poweroff
```

> **AI verify — ใช้ 1-shot verify script:** `docs/references/verify-phase2-template.sh` — upload → cleanup → verify → authorized_keys → poweroff
> ```bash
> # AI execution pattern (ไม่ใช่ manual step):
> # upload --localPath "docs/references/verify-phase2-template.sh" --remotePath "/tmp/verify-phase2.sh"
> # cleanup commands (ข้างบน)
> # execute-command "bash /tmp/verify-phase2.sh"
> # Expected: VERIFY:PASS หรือ VERIFY:FAIL <error_tags>
> ```


> **AI verify — ใช้ 1-shot verify script (ประหยัด token ~80%):**
> ```bash
> # upload --localPath "docs/references/verify-phase1-template.sh" --remotePath "/tmp/verify-phase1.sh"
> # execute-command "bash /tmp/verify-phase1.sh grafana-prometheus"
> # Expected: VERIFY:PASS หรือ VERIFY:FAIL <error_tags>
> ```


> **AI verify — 1-shot verify script:** ใช้ `docs/references/verify-phase1-template.sh` — upload + run ครั้งเดียว แทน 10 คำสั่งแยก
> ```bash
> # AI execution pattern (ไม่ใช่ manual step):
> # upload --localPath "docs/references/verify-phase1-template.sh" --remotePath "/tmp/verify-phase1.sh"
> # cleanup commands (ข้างบน)
> # execute-command "bash /tmp/verify-phase1.sh grafana-prometheus"
> ```


---

## วิธีใช้งานหลังลูกค้าสร้าง VM

```bash
sudo monitoring-info
sudo monitoring-status
sudo monitoring-add-http https://example.com website
sudo monitoring-add-node 10.0.0.12:9100 web-01
sudo monitoring-add-tcp 10.0.0.20:5432 db-01
sudo monitoring-list-targets
```

ถ้าลืม Grafana password:

```bash
sudo monitoring-reset-grafana-password
sudo monitoring-info
```

ถ้าลูกค้า snapshot VM ที่ใช้งานแล้วไปขึ้นเครื่องใหม่ password และ state เดิมจะติดไปตาม snapshot. ถ้าต้องการ password ใหม่ให้รัน reset script ข้างต้น.

---

## Troubleshooting

| อาการ | เช็ค | วิธีแก้ |
|---|---|---|
| เข้า Grafana ไม่ได้ | `sudo monitoring-status` | ดู Nginx/Grafana container logs |
| target ขึ้น DOWN | `sudo monitoring-list-targets` และ Prometheus Targets UI | ตรวจ IP/URL/port/firewall |
| node metrics ไม่มา | target VM มี node_exporter ไหม | เปิด TCP 9100 จาก monitoring VM ไป target |
| reset password ไม่ได้ | `docker ps`, `docker logs grafana` | ตรวจ Grafana container running |
| `/root/README-grafana-prometheus-image.txt` หายหรือไม่มี password | `grep '^  Password: ' /root/README-grafana-prometheus-image.txt` และ `systemctl status grafana-prometheus-bootstrap.service` | restart bootstrap service เพื่อ repair README จาก `/opt/monitoring/.env` โดยไม่ reset password |
| disk ใกล้เต็ม | `df -h`, Prometheus data volume | ลด retention หรือเพิ่ม disk |

---

## ส่งต่อ Cloud

Cloud ต้อง verify:
- Docker Compose config valid
- Prometheus config/rules valid
- first boot generate password จริง
- reboot แล้ว password ไม่เปลี่ยน
- `monitoring-reset-grafana-password` เปลี่ยน password จริงโดยไม่ลบ dashboard/targets/metrics
- public expose เฉพาะ TCP 80
- Prometheus/Alertmanager bind localhost เท่านั้น

Deploy/post-test references:
- Standalone Deployment: ใช้ขั้นตอนการทำงานเดียวกันกับขั้นตอน Build (ข้อ 1 ถึง 8) โดยไม่ต้องรันขั้นตอนการทำความสะอาดระบบ (Phase 1/2)
- Post-check: `apps/grafana-prometheus/docs/grafana-prometheus-post-check.md`

Latest verified result:
- 2026-06-16 post-test PASS for full non-reboot scope: bootstrap, runtime README/password, containers, health, exposure, helper commands, target helpers, password reset, datasource/dashboard, and Prometheus targets.
- cAdvisor target `down` is expected when the optional profile is not enabled.
- Golden-image cleanup PASS: runtime `.env`, README, marker, bootstrap log, containers, and monitoring volumes removed; bootstrap service remains enabled; package cache kept.
- Reboot persistence gate was not run in this verification.

---

## Record Build Manifest

หลัง pre-capture gate ผ่าน ให้สร้าง/อัปเดต `apps/grafana-prometheus/docs/grafana-prometheus-build-manifest.md` ด้วยข้อมูล version ที่ verify จาก golden-image VM เท่านั้น:

```bash
lsb_release -ds
docker version
docker compose version
docker buildx version
dpkg-query -W docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
docker images --digests --format '{{.Repository}}:{{.Tag}} {{.Digest}}'
```

เก็บเฉพาะ Base OS, Docker stack package versions แบบ minimal, Docker/Compose/Buildx versions, container image tag + digest และ build notes สั้นๆ. ห้ามเก็บ image name, Glance ID, server ID, floating IP, VM IP, hostname, OpenStack context หรือ credentials.

### Container Image Versions (Customer Service Model 2B)

| Image | Tag | Digest | Notes |
|---|---|---|---|
| `grafana/grafana-oss` | `11.6.5` | verify from VM | Pinned tag + digest |
| `prom/prometheus` | `v3.13.1` | verify from VM | LTS release |
| `prom/alertmanager` | `v0.33.1` | verify from VM | Pinned tag + digest |
| `prom/node-exporter` | `v1.12.0` | verify from VM | Pinned tag + digest |
| `prom/blackbox-exporter` | `master-distroless` | verify from VM | Distroless variant |
| `nginx` | `stable-alpine` | verify from VM | Pinned tag |

OpenStack capture/Glance/server ID/image ID อยู่นอกขอบเขต guide นี้ ให้ user/admin จัดการเอง และห้ามบันทึกค่าจริงลง repo.
