=== Nextcloud Docker Image — Ubuntu 26.04 ===

Access:  http://<YOUR-VM-IP>
Setup:   Login with admin credentials below

Credentials:
  Admin URL:  http://<YOUR-VM-IP>
  Admin user: admin
  Password:   /root/nextcloud-credentials.txt

Database credentials: /root/nextcloud-credentials.txt
Redis credentials: /root/nextcloud-credentials.txt

-------------------------------------------------------------------------------
First Time Setup
-------------------------------------------------------------------------------

  1. Open http://<YOUR-VM-IP> in your browser
  2. Login with:
       User:     admin
       Password: see /root/nextcloud-credentials.txt
       (password was generated securely at first boot — change it anytime via
        nc-occ user:resetpassword admin if you prefer a memorable one)

  3. (Optional) Add your domain name:
       nc-occ config:system:set trusted_domains 20 --value=nextcloud.example.com
       nc-occ config:system:set overwrite.cli.url --value=https://nextcloud.example.com

       Then if you want HTTPS, see "Enable HTTPS" section below.

  4. (Optional) Configure SMTP email:
       In Nextcloud web UI: Settings → Personal → Email
       Or use Mail SMTP plugin with your external SMTP server.

-------------------------------------------------------------------------------
Directory:
  /opt/nextcloud/                     Compose/config/control files
    docker-compose.yml                Service definitions
    .env                              Runtime env, generated on first boot, secret
    nginx/default.conf                HTTP Nginx config
    nginx/default-https.conf          HTTPS template
    certs/                            Place TLS certs here

Data:
  /var/lib/nextcloud/app              Nextcloud app + user files
  /var/lib/nextcloud/db               PostgreSQL data
  /var/lib/nextcloud/redis            Redis data

Metadata:
  /etc/nextcloud-image/image.conf     Image layout/mode info, no secret

Logs:
  /var/log/nextcloud-bootstrap.log
  journalctl -u nextcloud-bootstrap -n 80 --no-pager

Common Commands:
  cd /opt/nextcloud
  docker compose ps                   Check status
  docker compose logs -f              View logs
  docker compose --profile http restart              Restart all services
  docker compose --profile http restart nextcloud    Restart Nextcloud only

Helper Commands (shortcuts):
  nc-occ <command>                   Run occ (e.g. nc-occ user:list)
  nc-status                          Check container status
  nc-logs <service>                  View logs (e.g. nc-logs nextcloud)
  nc-restart                          Restart all services
  nc-upgrade                          Upgrade Nextcloud (saves previous version)
  nc-rollback                         Rollback to previous version

Restart the whole stack:
  docker compose --profile http restart              # restart all
  docker compose --profile http restart nginx        # restart nginx only

Enable HTTPS:
  1. Point DNS → VM floating IP
  2. Place certs: /opt/nextcloud/certs/fullchain.pem + privkey.pem
  3. chmod 644 /opt/nextcloud/certs/fullchain.pem
  4. chmod 600 /opt/nextcloud/certs/privkey.pem
  5. docker compose --profile https up -d

Backup:
   DB:   docker compose exec db pg_dump -U nextcloud nextcloud > nc-backup.sql
   Data: tar czf nc-data-backup.tar.gz -C /var/lib nextcloud
   Config: tar czf nc-config-backup.tar.gz -C /opt nextcloud

Restore:
   DB:   docker compose exec -T db psql -U nextcloud nextcloud < nc-backup.sql
   Data: tar xzf nc-data-backup.tar.gz -C /var/lib

Move data to attached volume later:
  1. cd /opt/nextcloud && docker compose --profile http down
  2. rsync -aHAX --numeric-ids /var/lib/nextcloud/ /mnt/nextcloud-new/
  3. mount the new volume at /var/lib/nextcloud
  4. cd /opt/nextcloud && docker compose --profile http up -d

SMTP:
  Use Nextcloud Mail SMTP plugin → configure external SMTP server

Upgrade Nextcloud:
   docker compose exec -u33 nextcloud ./occ maintenance:mode --on
   docker compose pull nextcloud
   docker compose up -d
   docker compose exec -u33 nextcloud ./occ maintenance:mode --off
