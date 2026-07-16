# Test Report: LEMP Stack

## Test Metrics Summary

| Round | Test Description | Executor | Status | Notes |
|-------|------------------|----------|--------|-------|
| R1.1 | Docker container status | Kich | ✅ PASS | 3 containers running: db (healthy), nginx, php-fpm |
| R1.2 | Bootstrap service log | Kich | ✅ PASS | systemd oneshot enabled, bootstrap completed |
| R1.3 | Credentials generated | Kich | ✅ PASS | `/root/lemp-credentials.txt` — alphanumeric passwords |
| R1.4 | Helper commands | Kich | ✅ PASS | lemp-status, lemp-logs, lemp-restart, lemp-shell, lemp-db all work |
| R1.5 | PHP extensions | Kich | ✅ PASS | pdo_mysql, mysqli, mbstring, gd, zip, intl — all installed |
| R1.6 | No pull in bootstrap | Kich | ✅ PASS | Bootstrap log: no `docker compose pull` |
| R1.7 | HTTP check | Kich | ✅ PASS | Nginx responds on port 80 |
| R1.8 | Security headers | Kich | ✅ PASS | `server_tokens off` — no nginx version; `expose_php = Off` — no X-Powered-By |
| R2.1 | Browser landing | Naki | ✅ PASS | PHP 8.3.32 phpinfo() page loads successfully |
| R2.2 | PHP extensions in browser | Naki | ✅ PASS | All 6 extensions confirmed via phpinfo() |
| R2.3 | Security headers in browser | Naki | ✅ PASS | No version leak, no X-Powered-By |
| R3.1 | VM reboot | Wakka | ✅ PASS | All containers auto-start after reboot (idempotent bootstrap) |
| R3.2 | Docker restart | Wakka | ✅ PASS | Containers recover after `systemctl restart docker` |
| R3.3 | Container kill | Wakka | ✅ PASS | `docker kill php-fpm` → container stopped (expected: `unless-stopped` doesn't restart killed containers); `lemp-restart` recovers fully |
| R3.4 | HTTP after stress | Wakka | ✅ PASS | HTTP 200 OK after all stress tests |

## Key Evidence

### Bootstrap idempotent (post-reboot)
```
2026-07-12 16:23:15 Bootstrap: .env exists — starting services
2026-07-12 16:23:25 Bootstrap: done (reusing existing config)
```

### PHP extensions confirmed
```
gd, intl, mbstring, mysqli, pdo_mysql, zip
```

### Security headers
```
Server: nginx          (no version — server_tokens off)
X-Powered-By: (absent — expose_php = Off)
```

## Notes
- `docker kill` does NOT trigger `unless-stopped` restart policy (by Docker design). Use `lemp-restart` to recover.
- MariaDB 11.4 uses `mariadb` binary, not `mysql` — `lemp-db` helper handles this automatically.
- All passwords are alphanumeric-only (no `+/=`).
- No secrets baked into image — all generated at first boot.
