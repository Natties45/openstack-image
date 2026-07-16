# WordPress Build Errors Log

This file records real build, review, and legacy-hardening incidents for the WordPress customer image. Do not store secrets, IPs, server IDs, image IDs, or runtime credentials here.

---

## Incident: Legacy Customer Service gaps found before rebuild

**Date:** 2026-07-09
**Step:** Auron-GPT customer-hardening design pass before rebuild
**Command/trigger:** Repo review against `docs/playbooks/customer-app-playbook.md` §3-§15
**Error message:** No runtime command failed; this is a documented legacy gap, not a build failure.

**Root cause:** The existing WordPress image predated the Customer Service hardening playbook. The source/guide had several legacy gaps:
- bootstrap used `openssl rand -base64`, which can generate `+`, `/`, or `=`;
- bootstrap attempted `docker compose pull` during first boot, making customer boot depend on internet access;
- customer-facing README contained Thai text;
- mandatory Customer Service helper scripts were missing;
- source tags were partly floating/stale (`wordpress:php8.3-fpm`, `nginx:1.27`);
- post-check only verified setup page availability and did not cover full customer browser flow through publishing a post.

**Fix:** Updated WordPress source and guide for the rebuild:
- first-boot DB passwords now use alphanumeric-only generation;
- bootstrap starts pre-pulled images and no longer pulls at customer boot;
- README and MOTD are English-only;
- added six helper scripts: `wp-cli`, `wordpress-status`, `wordpress-logs`, `wordpress-restart`, `wordpress-upgrade`, `wordpress-rollback`;
- pinned WordPress source to `wordpress:7.0.0-php8.3-fpm`, Nginx to `nginx:1.30.3`, and added WP-CLI `wordpress:cli-2.12.0-php8.3`; MariaDB was later tightened from `mariadb:lts` to `mariadb:11.4.8@sha256:bc474f00629f0123c10f9e1bca193a45d18af15a274cf0656acda64f1086c3b6` before rebuild;
- expanded `wordpress-post-check.md` to cover setup wizard, dashboard login, publish one test post, public post verification, and cleanup mode policy;
- added `wordpress-preview.md` and `wordpress-audit.md` rebuild packets.

**Verified:** Static source/guide consistency only. No build or browser test was run in this Auron pass. Seymour/Wakka/Kich must verify on VM:
- `grep -Ei 'pulling images|docker compose pull| compose pull' /var/log/wordpress-bootstrap.log` returns no first-boot pull attempt;
- generated DB passwords match `^[A-Za-z0-9]+$`;
- helper scripts exist and are executable;
- browser flow completes setup -> dashboard -> publish test post -> public post visible.

---

## Incident: Seymour pre-build error pass — secret-safe checks and DB pinning

**Date:** 2026-07-09
**Step:** Auron-GPT rework after Seymour findings
**Command/trigger:** Static review of WordPress source/guide/post-check before build
**Error message:** No runtime command failed; Seymour flagged pre-build risks.

**Root cause:** The post-check validated `.env` with a `grep` command that printed password lines; MariaDB used the floating `mariadb:lts` tag; README/PHP snippets had minor drift between source files and the self-contained guide; cleanup-test-targets could match posts too broadly.

**Fix:** Updated WordPress source and guide:
- replaced `mariadb:lts` with `mariadb:11.4.8@sha256:bc474f00629f0123c10f9e1bca193a45d18af15a274cf0656acda64f1086c3b6`;
- changed post-check password validation to `awk` exit-code validation that does not print secret values;
- synced README and PHP ini content between source files and `wordpress.md`;
- narrowed cleanup-test-targets to exact-title post deletion and explicit temporary-admin deletion only after another admin is confirmed.

**Verified:** Static documentation/source consistency only. No build, SSH post-check, or browser test was run in this pass.

---

## Incident: WordPress URL drift after VM IP change (post-test phase)

**Date:** 2026-07-10
**Step:** Post-test validation after the deployed VM access URL changed

**Error message:** No runtime command failed. WordPress still resolves to old IP.

**Root cause:** WordPress stores `siteurl` and `home` in the database as absolute URLs. When the VM access URL changed after deploy, these DB values were not updated. The site remained operational, but admin access and asset URLs could still point to the previous URL.

**Confirmed via wp-cli:**
```
$ cd /opt/wordpress && wp-cli option get siteurl
http://<previous-url>

$ wp-cli option get home
http://<previous-url>
```

**Fix applied during post-test:** Update the DB-backed URLs with the host helper, then restart the stack:
- `wp-cli option update siteurl http://<current-url>`
- `wp-cli option update home http://<current-url>`
- `wordpress-restart`

This restored admin access. The repo guidance was then updated so customer docs now present both recovery paths:
- if the customer can still log in, change **WordPress Address (URL)** and **Site Address (URL)** in **Settings → General**;
- if admin is inaccessible, use the `wp-cli` helper from the shell.

**Image-level follow-up:** This is treated as both:
- normal WordPress behavior (URLs live in the DB), and
- a customer recovery case that must be documented clearly.

The rebuild backlog from this incident is:
- fix the `wp-cli` helper so it always runs the real WP-CLI entrypoint with `--allow-root`;
- bake `bash`, `bash-completion`, `vi`, and `nano` into the runtime containers via local derivative images;
- document URL recovery and admin password reset in README/post-check/build guide.

**Impact:** Low. This does not require dynamic URL forcing in `wp-config.php`, but it does require a documented recovery workflow.

---

## Incident: Windows SFTP upload preserved CRLF in helper scripts

**Date:** 2026-07-10
**Step:** SSH build/install on golden VM before Phase 1 cleanup

**Command/trigger:** Upload WordPress source files from Windows workstation to Linux VM, then run `wp-cli --info` during bootstrap verification.

**Error message:**

```text
/usr/local/bin/wp-cli: /bin/bash^M: bad interpreter: No such file or directory
```

**Root cause:** The Windows-side upload path preserved CRLF line endings for executable shell helper scripts. Linux interpreted the shebang as `/bin/bash^M`.

**Fix applied during build:** Normalize executable scripts on the VM before verification:

```bash
for f in /usr/local/bin/wp-cli /usr/local/bin/wordpress-status /usr/local/bin/wordpress-logs /usr/local/bin/wordpress-restart /usr/local/bin/wordpress-upgrade /usr/local/bin/wordpress-rollback /usr/local/sbin/wordpress-bootstrap.sh /etc/update-motd.d/99-wordpress-image /etc/profile.d/99-bash-completion.sh; do
  [ -f "$f" ] && sed -i 's/\r$//' "$f" && chmod +x "$f"
done
```

**Verified:** After normalization, `wp-cli --info`, helper checks, container checks, Phase 1 cleanup, and pre-capture gate passed. VM remained powered on and reachable by SSH.

---

## Incident: Phase 2 OS cleanup was skipped when user said no poweroff

**Date:** 2026-07-10
**Step:** Final image cleanup after WordPress Phase 1 pre-capture cleanup

**Command/trigger:** User requested pre-capture cleanup and explicitly said not to shut off the VM.

**Error message:** No command failed. Operator inspection found `/root/.ssh/authorized_keys` still present after the reported cleanup.

**Root cause:** The orchestrator incorrectly interpreted "do not shutoff/poweroff" as "skip the whole Phase 2 OS cleanup block" instead of "run Phase 2 cleanup but omit only the final `poweroff` command". As a result, keypair cleanup, cloud-init cleanup, machine-id reset, SSH host key removal, temp/log cleanup, and fstrim were initially not executed.

**Fix applied:** Ran OS/image cleanup per flow while intentionally omitting `poweroff`:

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
rm -f /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys
fstrim -av || true
sync
```

**Verified:** `/root/.ssh/authorized_keys` absent, cloud-init instance state absent, `/etc/machine-id` empty, SSH host keys absent, WordPress containers/volumes remain zero, local derivative images remain present, and VM stayed powered on.

---

## Post-test note: Fresh VM passed with no-cleanup; keypair was not injected

**Date:** 2026-07-10
**Step:** Post-test validation on a fresh VM created from the WordPress image

**Command/trigger:** Admin requested full post-test after image upload and new VM creation.

**Result:** PASS. SSH login worked, cloud-init completed, machine-id and SSH host keys regenerated, WordPress bootstrap succeeded, runtime files were generated, containers became healthy, no first-boot Docker pull occurred, helper commands worked, browser setup wizard completed, dashboard login worked, and a test post was published and visible publicly.

**Cleanup mode:** `no-cleanup` selected by admin. Runtime containers, volumes, generated runtime credentials, temporary admin user, and test post were intentionally left for inspection.

**Keypair observation:** Root `authorized_keys` on the fresh VM was absent/empty while password SSH login worked. This confirms the golden image did not leak the previous keypair. If key-based login is required, verify the OpenStack server-create keypair selection and cloud-init/root SSH policy. This is a deployment/configuration note, not an image build failure.

**Verified:** Build/upload residue was absent, including temporary source upload files and previous-image helper backups. No IP address, password, key content, server ID, image ID, or runtime credential is recorded here.
