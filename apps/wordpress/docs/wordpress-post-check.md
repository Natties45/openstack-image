# WordPress Customer Image — Post-Check Checklist

> Run on a fresh VM created from the captured WordPress image. Do not write passwords, IPs, server IDs, image IDs, or credentials into this repo.

---

## Scope

This post-check verifies the customer flow chosen for WordPress:

```text
boot VM -> bootstrap stack offline -> show WordPress setup wizard -> complete wizard -> dashboard -> publish one test post -> public post visible
```

The WordPress admin account used for testing is temporary and created during the browser wizard by the tester. Do not record its password.

---

## Runtime data policy

| Path | Expected on fresh post-test VM | Policy |
|---|---|---|
| `/opt/wordpress/.env` | Exists after first boot | Runtime DB secrets; do not print content into logs/docs. |
| `/root/wordpress-credentials.txt` | Exists after first boot | DB credentials only; do not dump content into repo. |
| `/var/log/wordpress-bootstrap.log` | Exists after first boot | May be inspected for non-secret status lines. |
| Docker volumes | Exist after first boot | Runtime WordPress and DB data. |

Before capture these files/volumes must be absent; after post-test boot they are expected to exist.

---

## SSH post-check

### 1. Bootstrap service

```bash
systemctl is-enabled wordpress-bootstrap.service
systemctl is-active wordpress-bootstrap.service
systemctl status wordpress-bootstrap.service --no-pager
```

Pass: enabled and active/exited, not failed.

### 2. Helper scripts and customer docs

```bash
test -f /root/README-wordpress-image.txt
test -x /etc/update-motd.d/99-wordpress-image
for h in wp-cli wordpress-status wordpress-logs wordpress-restart wordpress-upgrade wordpress-rollback; do which "$h"; done
wp-cli --info
grep -nE '[ก-๙]' /root/README-wordpress-image.txt /etc/update-motd.d/99-wordpress-image && echo "ERROR: non-English customer docs" || echo "OK: English-only customer docs"
```

Pass: README/MOTD exist, six helpers are available, `wp-cli --info` works, no Thai text in customer-facing docs.

### 3. Troubleshooting tools baked into runtime containers

```bash
cd /opt/wordpress
for svc in db wordpress nginx; do
  echo "=== $svc ==="
  docker compose exec -T "$svc" sh -lc 'command -v bash && command -v vi && command -v nano'
done
```

Pass: each runtime container returns paths for `bash`, `vi`, and `nano`.

### 4. Containers and nginx health

```bash
cd /opt/wordpress
wordpress-status
docker compose --profile http ps --format json
docker inspect "$(docker compose --profile http ps -q nginx)" --format '{{.State.Health.Status}}'
```

Pass: `db` healthy, `wordpress` running, `nginx` running/healthy.

### 5. Runtime secrets generated at boot and alphanumeric-only

```bash
test -f /opt/wordpress/.env
test -f /root/wordpress-credentials.txt
awk -F= '
  $1=="MARIADB_ROOT_PASSWORD" || $1=="MARIADB_PASSWORD" {
    found[$1]=1
    if ($2 !~ /^[A-Za-z0-9]+$/) bad=1
  }
  END {
    if (!found["MARIADB_ROOT_PASSWORD"] || !found["MARIADB_PASSWORD"]) exit 2
    if (bad) exit 1
  }
' /opt/wordpress/.env \
  && echo "OK: generated DB passwords exist and are alphanumeric-only" \
  || { echo "ERROR: generated DB password validation failed"; exit 1; }
```

Pass: files exist and validation succeeds without printing password values.

### 6. Offline first boot evidence

```bash
grep -Ei 'pulling images|docker compose pull| compose pull' /var/log/wordpress-bootstrap.log && echo "ERROR: first boot attempted pull" || echo "OK: no pull during bootstrap"
docker images | grep -E 'wordpress-local-(mariadb|fpm|nginx|cli)'
```

Pass: no pull line in bootstrap log; required local derivative images are present.

### 7. HTTP setup page

```bash
curl -sI http://localhost | head -5
curl -sL http://localhost | grep -Ei 'WordPress|language|install|setup' | head
```

Pass: HTTP returns 200/302 and body shows WordPress setup/install content, not a DB connection error.

---

## Browser acceptance flow

Use a browser against the VM access URL. Do not store the temporary admin password in the repo.

### 8. Complete setup wizard

1. Open `http://<VM-IP>`.
2. Select language if prompted.
3. Fill site title, temporary admin username, temporary admin password, and temporary email.
4. Submit the install wizard.
5. Log in with the temporary admin.

Pass: WordPress dashboard loads (`/wp-admin/`).

### 9. Publish one test post

1. Go to **Posts → Add New**.
2. Create a post titled `Image Post-Check Test`.
3. Add a short body such as `WordPress image post-check content`.
4. Publish the post.
5. Open/view the public post URL.

Pass: public post URL returns 200 and displays the title/content.

### 10. Public post check via SSH

```bash
curl -sL http://localhost | grep -F 'Image Post-Check Test' || true
```

If the front page does not show latest posts due theme/settings, use the browser public post URL and verify HTTP 200/content instead. Do not paste the VM IP into repo docs.

### 11. URL change recovery and admin password reset

If the customer can still access `/wp-admin/`, they should prefer **Settings → General** and update:

- **WordPress Address (URL)**
- **Site Address (URL)**

If admin access is broken after an IP/domain change, recover from shell:

```bash
cd /opt/wordpress
wp-cli option update siteurl http://<NEW-IP-OR-DOMAIN>
wp-cli option update home http://<NEW-IP-OR-DOMAIN>
wordpress-restart
```

If the admin password must be reset:

```bash
cd /opt/wordpress
wp-cli user list --role=administrator
wp-cli user update <admin-username> --user_pass='NewStrongPassword123!'
```

Pass: at least one documented recovery path is confirmed workable for operators; no password value is copied into the repo.

---

## Cleanup mode policy — ask before cleanup

Before cleanup, ask admin/customer to choose exactly one mode:

| Mode | Behavior |
|---|---|
| `no-cleanup` | Leave containers, volumes, `.env`, credentials file, logs, temporary admin, and test post for inspection. |
| `cleanup-test-targets` | Remove only test targets created by this checklist: test post and temporary test admin if safe; keep stack, customer docs, `.env`, DB, logs. |

Reboot test is optional and must be asked separately. If approved, run it as the final step only.

### Cleanup-test-targets helper commands

Run only after admin/customer chooses `cleanup-test-targets`.

```bash
cd /opt/wordpress
# Requires WordPress to be installed and wp-cli helper available. Deletes only exact-title checklist posts.
POST_IDS=$(wp-cli post list --post_type=post --format=ids --s='Image Post-Check Test' 2>/dev/null || true)
for id in $POST_IDS; do
  title=$(wp-cli post get "$id" --field=post_title 2>/dev/null || true)
  if [ "$title" = "Image Post-Check Test" ]; then
    wp-cli post delete "$id" --force
  fi
done
wordpress-restart
```

If a temporary test admin was created solely for this test and no longer needed, delete it only after confirming another administrator account remains. Example with an explicit username (do not use a wildcard):

```bash
cd /opt/wordpress
TEST_ADMIN_USER='<temporary-admin-username>'
ADMIN_COUNT=$(wp-cli user list --role=administrator --field=ID | wc -l)
if [ "$ADMIN_COUNT" -ge 2 ] && wp-cli user get "$TEST_ADMIN_USER" --field=ID >/dev/null 2>&1; then
  wp-cli user delete "$TEST_ADMIN_USER" --reassign=1
else
  echo "Skip admin cleanup: another administrator was not confirmed or user was not found"
fi
unset TEST_ADMIN_USER ADMIN_COUNT
```

---

## Success criteria

| # | Criteria | Status |
|---|---|---|
| 1 | Bootstrap service enabled and not failed | [ ] |
| 2 | `db`, `wordpress`, `nginx` containers include `bash`, `vi`, and `nano` | [ ] |
| 3 | DB/WordPress/Nginx containers running and nginx healthy | [ ] |
| 4 | `.env` and credentials generated after boot; no secret content copied to repo | [ ] |
| 5 | Generated DB passwords are alphanumeric-only | [ ] |
| 6 | Bootstrap log proves no mandatory pull on customer boot | [ ] |
| 7 | README/MOTD are English-only, six helpers exist, and `wp-cli --info` works | [ ] |
| 8 | WordPress setup wizard appears | [ ] |
| 9 | Browser wizard completes and dashboard loads | [ ] |
| 10 | One test post publishes and public URL displays content | [ ] |
| 11 | Cleanup mode was explicitly chosen before any cleanup | [ ] |
