# n8n Post-Test Checklist

> Post-test checklist สำหรับ VM ใหม่ที่ boot จาก n8n golden image
> ปฏิบัติตาม customer-app-playbook §8

---

## Checklist

| # | Check | Pass Criteria | Error Tag |
|---|---|---|---|
| 1 | Bootstrap service | `systemctl is-active n8n-bootstrap.service` = active (exited), `is-enabled` = enabled | `service` |
| 2 | Containers up | `docker compose ps` → postgres, n8n, nginx containers `Up` | `containers` |
| 3 | .env generated | `/opt/n8n/.env` exists; password alphanumeric-only (no `+/=`) | `dotenv` |
| 4 | WEBHOOK_URL dynamic | `WEBHOOK_URL` in `.env` uses port 80 (no `:5678`), contains a reachable VM IP; prefers public IP when both public and private are attached | `webhook` |
| 5 | MOTD + README | `/etc/update-motd.d/99-n8n-image` executable; `/root/README-n8n-image.txt` exists | `docs` |
| 6 | Pre-pull images | `docker images` → `n8nio/n8n:2.29.8`, `postgres:16`, `nginx:stable` all present | `images` |
| 7 | Runtime files by-design | `.env`, `/root/n8n-credentials.txt`, bootstrap log regenerated post-boot | `runtime` |
| 8 | n8n login page (port 80) | `curl -sI http://localhost:80/` → 200 or 302 | `login` |
| 9 | n8n login page (5678 localhost) | `curl -sI http://127.0.0.1:5678/` → 200 or 302 | `login-5678` |
| 10 | n8n NOT exposed on 5678 externally | `curl -sI --connect-timeout 3 http://<VM_IP>:5678/` fails (connection refused/timeout) | `port-bind` |
| 11 | Browser login | Playwright: navigate to `http://<IP>/` → create owner account → reach dashboard | `browser` |
| 12 | Webhook endpoint | `curl -s -o /dev/null -w '%{http_code}' http://localhost:80/webhook-test` → 200 | `webhook` |
| 13 | credentials.txt | `/root/n8n-credentials.txt` contains password, encryption key, AND access URL (port 80) | `creds` |
| 14 | nginx running | `docker ps` → nginx container `Up`; `curl -sI http://localhost:80/` → 200/302 | `nginx` |
| 15 | nginx configs present | `/opt/n8n/nginx/n8n-http.conf`, `n8n-https.conf`, `n8n.conf` all exist | `nginx-conf` |
| 16 | nginx /rest/push WebSocket block | All 3 nginx configs contain `location ~ ^/rest/push` with `Upgrade` + `Connection "Upgrade"` headers | `ws-push` |
| 17 | HTTPS helpers present | `n8n-https-enable`, `n8n-cert-status`, `n8n-https-disable` exist and executable | `https-helpers` |
| 18 | n8n-cert-status works | `n8n-cert-status` runs, shows "HTTP ONLY (no certs)" on fresh VM | `cert-status` |
| 19 | HTTPS enable (no certs) | `n8n-https-enable` exits with error "certificates not found" when no certs | `https-no-cert` |
| 20 | Browser workflow execution | Playwright: create simple manual-trigger workflow → click "Execute Workflow" → execution succeeds without "Lost connection to server" error; browser console shows `/rest/push` WebSocket connects (status 101) | `ws-exec` |

---

## HTTPS Mode Tests (optional — only if certs placed)

| # | Check | Pass Criteria | Error Tag |
|---|---|---|---|
| H1 | Place test certs | Self-signed cert at `/opt/n8n/certs/fullchain.pem` + `privkey.pem` | `certs` |
| H2 | n8n-https-enable | Runs, prompts for domain, updates .env, restarts stack | `https-enable` |
| H3 | Port 80 redirects | `curl -sI http://localhost:80/` → 301 redirect to https | `https-redirect` |
| H4 | Port 443 serves | `curl -skI https://localhost:443/` → 200 or 302 | `https-serve` |
| H5 | n8n-cert-status | Shows "HTTPS ENABLED" + cert details (subject, issuer, dates) | `cert-https` |
| H6 | n8n-https-disable | Runs, reverts to HTTP, cert files preserved at /opt/n8n/certs/ | `https-disable` |
| H7 | Certs preserved | After disable: `/opt/n8n/certs/fullchain.pem` + `privkey.pem` still exist | `certs-preserved` |

---

## Pipeline Scope

| Phase | Applies? | Detail |
|-------|----------|--------|
| Pre-capture gate (Phase 1) | ✅ | ก่อน snapshot ต้อง verify Phase 1 cleanup ตาม `n8n.md` §7-8 |
| Phase 2 cleanup | ✅ | หลังถาม admin — OS cleanup + poweroff |
| Post-test on fresh VM | ✅ | 20 items above + optional HTTPS tests |
| Reboot test | Optional | ถาม admin ก่อน — final gate เท่านั้น |

---

## Failure Routing

| Fail Tag | Route | Action |
|----------|-------|--------|
| `service` | Wakka | Fix systemd unit / bootstrap.sh |
| `containers` | Wakka | Fix docker-compose.yml / bootstrap.sh |
| `dotenv` | Wakka | Fix bootstrap.sh env gen |
| `webhook` | Wakka / Auron | Fix dynamic IP discovery / WEBHOOK_URL port (bootstrap should prefer public IP) |
| `docs` | Yuna | Fix MOTD/README path or content |
| `images` | Wakka | Fix image tags or pull commands in build |
| `runtime` | Wakka | Fix Phase 1 cleanup excludes |
| `login` | Wakka | Fix nginx config / n8n port mapping |
| `login-5678` | Wakka | Fix n8n localhost bind |
| `port-bind` | Auron | Fix docker-compose port binding (must be 127.0.0.1:5678) |
| `browser` | Naki | Report UI issue → Wakka fix source |
| `creds` | Wakka | Fix credentials.txt template (port 80 URL) |
| `nginx` | Auron | Fix nginx always-on config / compose |
| `nginx-conf` | Auron | Fix nginx config files (http/https/active) |
| `https-helpers` | Auron | Fix helper scripts (enable/status/disable) |
| `cert-status` | Auron | Fix n8n-cert-status script |
| `https-no-cert` | Auron | Fix n8n-https-enable error handling |
| `ws-push` | Auron | Fix nginx configs — add /rest/push WebSocket Upgrade block |
| `ws-exec` | Naki / Auron | Report UI workflow exec issue → Auron fix nginx /rest/push block |
| `https-redirect` | Auron | Fix nginx https config redirect |
| `https-serve` | Auron | Fix nginx https config SSL |
| `https-disable` | Auron | Fix n8n-https-disable script |
| `certs-preserved` | Auron | Fix n8n-https-disable (must not delete certs) |

---

## Cleanup/No-Cleanup Policy

| Mode | Behavior |
|------|----------|
| `no-cleanup` | ทิ้ง containers, volumes, `.env`, credentials, logs, test markers — admin inspect ต่อ |
| `cleanup-test-targets` | ลบเฉพาะ test certs (if placed), reload app |

---

## Expected Exceptions

- **Reboot test**: ไม่รวมใน default — ถาม admin ก่อนทุกครั้ง
- **Queue Mode**: ไม่ได้เปิดใน default stack — ไม่ fail ถ้าไม่มี Redis worker
- **Port 5678 external**: ต้อง fail — 5678 bound to 127.0.0.1 only
- **HTTPS mode**: ไม่ start โดย default — ต้องวาง cert + run `n8n-https-enable` ก่อน
- **Cert files on golden image**: `/opt/n8n/certs/` ว่าง — ไม่มี cert ใน golden image