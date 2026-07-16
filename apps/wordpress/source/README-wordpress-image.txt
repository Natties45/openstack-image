=== WordPress Customer Image — Ubuntu 26.04 ===

Access:
  http://<VM-IP>

First setup:
  Open the URL in a browser and complete the WordPress 5-minute install wizard.
  You create the WordPress site title, admin username, admin password, and email during the wizard.

Credentials:
  Database credentials: /root/wordpress-credentials.txt
  WordPress admin: created by you during the browser setup wizard

Important paths:
  /opt/wordpress/                     Main stack directory
  /opt/wordpress/docker-compose.yml    Docker Compose services
  /opt/wordpress/nginx/default.conf    HTTP Nginx config
  /opt/wordpress/nginx/default-https.conf HTTPS Nginx config
  /opt/wordpress/php/wordpress.ini     PHP upload/runtime settings
  /opt/wordpress/certs/                TLS certificate directory

Helper commands:
  wordpress-status      Show container status
  wordpress-logs        Show recent stack logs
  wordpress-restart     Restart the HTTP stack
  wordpress-upgrade     Rebuild local container images from bundled Dockerfiles and restart
  wordpress-rollback    Restore previous compose/Dockerfile backup created by upgrade helper
  wp-cli <args>         Run WP-CLI against this WordPress instance after setup

If your IP or domain changes later:
  Preferred: if you can still log in, open WordPress Admin -> Settings -> General
             and update both WordPress Address (URL) and Site Address (URL).
  Recovery:  wp-cli option update siteurl http://<NEW-IP-OR-DOMAIN>
             wp-cli option update home http://<NEW-IP-OR-DOMAIN>
             wordpress-restart

Reset an admin password:
  wp-cli user list --role=administrator
  wp-cli user update <admin-username> --user_pass='NewStrongPassword123!'

Troubleshooting shells:
  The db, wordpress, and nginx containers include bash, vi, and nano for manual troubleshooting.
  Bash completion is enabled on the host shell for easier helper-command tab completion.

Offline first boot:
  The image is built with local derivative container images prepared during image creation.
  The first customer boot does not run docker compose pull.
  Do not run docker image prune -a unless you intentionally want to require internet access for future starts.

Enable HTTPS:
  1. Point your DNS name to this VM.
  2. Copy cert files to /opt/wordpress/certs/fullchain.pem and /opt/wordpress/certs/privkey.pem.
  3. Run: chmod 644 /opt/wordpress/certs/fullchain.pem && chmod 600 /opt/wordpress/certs/privkey.pem
  4. Run: cd /opt/wordpress && docker compose --profile http stop nginx
  5. Run: cd /opt/wordpress && docker compose --profile https up -d nginx-https
  6. In WordPress Settings, update Site Address and WordPress Address to your HTTPS domain if needed.

Backup examples:
  cd /opt/wordpress
  docker compose exec db sh -c 'exec mysqldump -u root -p"$MARIADB_ROOT_PASSWORD" wordpress' > db-backup.sql
  docker run --rm -v wordpress_wp_data:/data -v "$PWD":/backup alpine tar czf /backup/wp-files.tar.gz -C /data .

Warnings:
  Do not run docker compose down -v on a live customer VM unless you intend to delete WordPress data.
  SMTP/email delivery is not configured by this image. Configure an SMTP plugin/provider after setup if password reset email is required.
  XML-RPC is blocked by the default Nginx config. Edit Nginx config only if your plugin or mobile workflow requires XML-RPC.
  WordPress normally stores site URLs in the database. If you change IP/domain later, update the URLs in Settings or with wp-cli.
