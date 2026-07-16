## Error: Login Redirect Loop

**Step:** 4. Testing login with curl

**Command:** 
```bash
curl -s -X POST 'http://203.154.16.138/login' -H 'Content-Type: application/x-www-form-urlencoded' -d 'user=admin&password=LVcwKEqKq03pGpKM6Rg9bL+5' -D -
```

**Error message:** 
The login request returns HTTP 303 See Other with Location header pointing to `/login?direct=1&user=admin` instead of redirecting to the dashboard.

**Root cause:** 
This indicates that the authentication is failing or there's a configuration issue with Nextcloud that's causing it to redirect back to the login page. Common causes include:
1. Incorrect password being used
2. Session handling issues
3. Trusted domain configuration problems
4. CSRF token validation issues

**Fix:** 
We need to investigate the Nextcloud logs to understand why authentication is failing.

**Verified:** 
```bash
curl -s -X POST 'http://203.154.16.138/login' -H 'Content-Type: application/x-www-form-urlencoded' -d 'user=admin&password=LVcwKEqKq03pGpKM6Rg9bL+5' -D - | grep -E 'HTTP|Location'
```
Result: `HTTP/1.1 303 See Other` with `Location: /login?direct=1&user=admin`

---

## Error: Redis Connection Issue

**Step:** 5. Debugging login failure

**Command:** 
```bash
cd /opt/nextcloud && docker compose exec -T nextcloud cat /var/www/html/data/nextcloud.log | tail -20
```

**Error message:** 
Multiple entries showing:
```
session_start(): Redis connection not available at /var/www/html/lib/private/Session/Internal.php#198
session_start(): Failed to read session data: redis (path: tcp://redis:6379?auth=+QKx9vNOhd7eEVTDJGO9G+XICEkNdbdt) at /var/www/html/lib/private/Session/Internal.php#198
```

**Root cause:** 
The Nextcloud application is unable to connect to the Redis server for session storage. This is causing authentication to fail as session data cannot be properly stored or retrieved.

**Fix:** 
We need to check the Redis container status and configuration. The Redis password in the Nextcloud configuration might be incorrect or there might be a network connectivity issue between the containers.

**Verified:** 
```bash
cd /opt/nextcloud && docker compose logs redis | tail -10
```

---

## Error: REIDS_PASSWORD typo in docker-compose.yml — FIXED 2026-07-09

**Date:** 2026-07-09
**Status:** ✅ FIXED

**Root cause:**
`docker-compose.yml` line 58 มี `REDIS_HOST_PASSWORD: ${REIDS_PASSWORD}` (REIDS แทน REDIS) → env var เป็น string เปล่า → Nextcloud session handler เชื่อม Redis โดยไม่มี password → `NOAUTH Authentication required.` → /login 500 error

**Fix applied:**
- `sed -i "s/REIDS_PASSWORD/REDIS_PASSWORD/g" /opt/nextcloud/docker-compose.yml`
- `docker compose --profile http down && docker compose --profile http up -d` (restart containers ให้อ่าน env var ที่ถูกต้อง)
- Source file `apps/nextcloud/docker-compose.yml` ถูกต้องแล้ว — typo เกิดจาก base64 ที่ deploy ไป VM

**Lesson:**
- ห้าม encode base64 ด้วยมือ — ใช้ `[Convert]::ToBase64String()` จาก local file โดยตรง
- หลัง deploy compose ต้อง `grep -n "REIDS\|REDIS"` ตรวจสอบก่อน bootstrap

---

## TODO: Redis password special chars break session handler — FIXED 2026-07-08

**Date:** 2026-07-08
**Status:** ✅ FIXED

**Root cause:**
Redis password `+QKx9vNOhd7eEVTDJGO9G+XICEkNdbdt` มี `+` ซึ่งถูก URL-encode เป็น space ใน connection string `tcp://redis:6379?auth=+QKx9vNOhd7eEVTDJGO9G+XICEkNdbdt` → Redis อ่านผิด → session_start() ล้มเหลว → login POST สำเร็จ 303 แต่ session ไม่ถูกบันทึก → redirect กลับ /login

**Fix applied:**
- เปลี่ยน password generation จาก `openssl rand -base64 24` → `gen_password()` ใช้ `openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c N` — รับประกัน alphanumeric-only ไม่มี `+` `/` `=`
- ใช้กับทุก password: `REDIS_PASSWORD`, `POSTGRES_PASSWORD`, `NEXTCLOUD_ADMIN_PASSWORD`
- `memcache.local` ใช้ APCu (default Nextcloud 30+) แทน Redis — ป้องกัน Redis dependency สำหรับ local cache
- Files updated: `nextcloud-bootstrap.sh`, `nextcloud.md`, `nextcloud-post-check.md`