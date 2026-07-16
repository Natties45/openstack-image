# WordPress Image — Ubuntu 26.04  [built: standalone]

> Customer Service image: first boot auto-starts DB + WordPress + Nginx; customer completes the WordPress browser wizard manually. Model = **2A auto DB/stack only**.

---

## Design decisions from review

| Decision | Choice | Reason |
|---|---|---|
| App runtime | `wordpress:7.0.0-php8.3-fpm` | Review recommends semver functional tag instead of floating `php8.3-fpm`; PHP 8.3 remains conservative official target. PINNED SEMVER TAG — verify digest during build and record in manifest. |
| DB | `mariadb:11.4.8@sha256:bc474f00629f0123c10f9e1bca193a45d18af15a274cf0656acda64f1086c3b6` | WordPress official flow needs MySQL/MariaDB; review flagged `mariadb:lts` as floating, so the image now pins the MariaDB 11.4 LTS patch tag plus manifest-list digest. |
| Proxy | `nginx:1.30.3` | FPM variant must run behind a reverse proxy; replaces stale `nginx:1.27` with explicit stable semver. PINNED SEMVER TAG — verify digest during build and record in manifest. |
| Admin setup | Browser wizard | User decision Q2=2A; customer creates WordPress admin account, image only generates DB secrets. |
| First boot | Offline-safe | Customer playbook requires no mandatory pull on customer boot; local derivative images are built during image creation only. |
| Secrets | First-boot generated alphanumeric-only | Customer playbook §5; avoids `+/=` breakage in env/URI/config contexts. |
| Trusted domains | Not applicable pre-install | WordPress does not have Nextcloud-style trusted_domains before wizard; customers set site URL in wizard/settings. Bootstrap still avoids hardcoded NIC/IP and records detected IPs in credentials file. |

---

## Files installed in the image

```text
/opt/wordpress/docker-compose.yml
/opt/wordpress/source/images/db/Dockerfile
/opt/wordpress/source/images/wordpress/Dockerfile
/opt/wordpress/source/images/nginx/Dockerfile
/opt/wordpress/source/images/wp-cli/Dockerfile
/opt/wordpress/nginx/default.conf
/opt/wordpress/nginx/default-https.conf
/opt/wordpress/php/wordpress.ini
/opt/wordpress/certs/
/usr/local/sbin/wordpress-bootstrap.sh
/etc/systemd/system/wordpress-bootstrap.service
/etc/profile.d/99-bash-completion.sh
/root/README-wordpress-image.txt
/etc/update-motd.d/99-wordpress-image
/usr/local/bin/wp-cli
/usr/local/bin/wordpress-status
/usr/local/bin/wordpress-logs
/usr/local/bin/wordpress-restart
/usr/local/bin/wordpress-upgrade
/usr/local/bin/wordpress-rollback
```

Runtime files that must be absent before capture but regenerated on customer boot:

```text
/opt/wordpress/.env
/root/wordpress-credentials.txt
/var/log/wordpress-bootstrap.log
Docker volumes
```

---

## Build guide

Run on the Ubuntu 26.04 golden-image VM.

### 1. Install base packages and Docker

```bash
apt update
apt install -y ca-certificates curl gnupg openssl jq vim nano bash-completion htop net-tools

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" > /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
```

Configure Docker log rotation and terminal bash-completion:
```bash
# Upload and apply docker config
mkdir -p /etc/docker
# (Optional) config daemon.json manually or via helper
systemctl restart docker

# Upload 99-bash-completion.sh from source
# Upload to /etc/profile.d/99-bash-completion.sh and run:
chmod +x /etc/profile.d/99-bash-completion.sh
```

### 2. Create directories

```bash
mkdir -p /opt/wordpress/{nginx,php,certs,images/db,images/nginx,images/wordpress,images/wp-cli}
chmod 700 /opt/wordpress/certs
```

### 3. Deploy source and configuration files

Upload the following files from the repository to their target paths on the VM:

| Local Repository Path | Target Path on VM |
|---|---|
| `source/docker-compose.yml` | `/opt/wordpress/docker-compose.yml` |
| `source/images/db/Dockerfile` | `/opt/wordpress/images/db/Dockerfile` |
| `source/images/wordpress/Dockerfile` | `/opt/wordpress/images/wordpress/Dockerfile` |
| `source/images/nginx/Dockerfile` | `/opt/wordpress/images/nginx/Dockerfile` |
| `source/images/wp-cli/Dockerfile` | `/opt/wordpress/images/wp-cli/Dockerfile` |
| `source/nginx/default.conf` | `/opt/wordpress/nginx/default.conf` |
| `source/nginx/default-https.conf` | `/opt/wordpress/nginx/default-https.conf` |
| `source/php/wordpress.ini` | `/opt/wordpress/php/wordpress.ini` |

### 4. Deploy bootstrap scripts and systemd service

Upload the bootstrap script and service:

| Local Repository Path | Target Path on VM |
|---|---|
| `source/wordpress-bootstrap.sh` | `/usr/local/sbin/wordpress-bootstrap.sh` |
| `source/wordpress-bootstrap.service` | `/etc/systemd/system/wordpress-bootstrap.service` |
| `source/README-wordpress-image.txt` | `/root/README-wordpress-image.txt` |
| `source/99-wordpress-image` | `/etc/update-motd.d/99-wordpress-image` |

Set permissions and reload systemd:
```bash
chmod +x /usr/local/sbin/wordpress-bootstrap.sh
chmod +x /etc/update-motd.d/99-wordpress-image

systemctl daemon-reload
systemctl enable wordpress-bootstrap.service
systemctl is-enabled wordpress-bootstrap.service
```

### 5. Deploy helper scripts

Upload all helper scripts from the repository to `/usr/local/bin/`:

| Local Repository Path | Target Path on VM |
|---|---|
| `helpers/wp-cli` | `/usr/local/bin/wp-cli` |
| `helpers/wordpress-status` | `/usr/local/bin/wordpress-status` |
| `helpers/wordpress-logs` | `/usr/local/bin/wordpress-logs` |
| `helpers/wordpress-restart` | `/usr/local/bin/wordpress-restart` |
| `helpers/wordpress-upgrade` | `/usr/local/bin/wordpress-upgrade` |
| `helpers/wordpress-rollback` | `/usr/local/bin/wordpress-rollback` |

Make helpers executable:
```bash
chmod +x /usr/local/bin/{wp-cli,wordpress-status,wordpress-logs,wordpress-restart,wordpress-upgrade,wordpress-rollback}
```

### 6. Build local derivative images

To ensure the Golden Image boots offline-safe, build derivative images on the VM:

```bash
cd /opt/wordpress
TMP_PULL_PASSWORD=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32)
cat > /opt/wordpress/.env << EOV
MARIADB_DATABASE=wordpress
MARIADB_USER=wordpress
MARIADB_ROOT_PASSWORD=${TMP_PULL_PASSWORD}
MARIADB_PASSWORD=${TMP_PULL_PASSWORD}
EOV
docker compose --profile http --profile tools build --pull
rm -f /opt/wordpress/.env
unset TMP_PULL_PASSWORD
```

### 7. Test bootstrap on VM

Verify the bootstrap process works locally:
```bash
/usr/local/sbin/wordpress-bootstrap.sh
wordpress-status
wp-cli --info
curl -sI http://localhost | head -3
```

Check the bootstrap log to ensure no network pulls occurred:
```bash
grep -Ei 'pulling images|docker compose pull| compose pull' /var/log/wordpress-bootstrap.log && echo "ERROR: bootstrap attempted image pull" || echo "OK: no pull command in bootstrap log"
```

Verify tools inside containers:
```bash
for svc in db wordpress nginx; do docker compose exec -T "$svc" sh -lc 'command -v bash && command -v vi && command -v nano'; done
```

### 8. Phase 1 — App cleanup before capture

Remove runtime artifacts while keeping the cached Docker images:
```bash
cd /opt/wordpress
docker compose --profile https down --remove-orphans 2>/dev/null || true
docker compose --profile http down -v --remove-orphans
rm -f /opt/wordpress/.env /root/wordpress-credentials.txt /var/log/wordpress-bootstrap.log /opt/wordpress/.previous-image
rm -rf /opt/wordpress/.previous-images
docker volume prune -f
```

Execute verification script to pass the pre-capture gate:
```bash
# Upload and run verify-phase1-template.sh (Part 5)
```

### 9. Phase 2 — OS cleanup + poweroff (final)

Perform general OS cleanups, remove ssh key authorization, and poweroff the VM:
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

# Upload and execute verify-phase2-template.sh (Part 5)
# If PASS, remove authorized_keys and shutdown:
rm -f /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys
poweroff
```

---

## Record Build Manifest

After successful build and verification, Wakka updates/creates `docs/wordpress-build-manifest.md`. Do not record IPs, passwords, hostnames, or other customer secrets.
