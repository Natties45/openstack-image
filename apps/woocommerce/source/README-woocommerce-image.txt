=== WooCommerce Docker Image — Ubuntu 26.04 ===

Access:
  Store:  http://<VM-IP>
  Admin:  http://<VM-IP>/wp-admin/

Credentials:
  Generated on first boot: /root/woocommerce-credentials.txt
  Change WordPress admin password and email after first login.

Directory:
  /opt/woocommerce/                    Main directory
    docker-compose.yml                 Service definitions
    nginx/default.conf                 Nginx config (editable)
    nginx/default-https.conf           HTTPS template
    php/woocommerce.ini                PHP settings (editable)
    certs/                             Place TLS certs here

Common Commands:
  cd /opt/woocommerce
  docker compose ps                    Check status
  docker compose logs -f               View logs
  docker compose restart               Restart all services
  docker compose restart wordpress     Restart after editing php/woocommerce.ini
  docker compose restart nginx         Restart after editing nginx/default.conf

WP-CLI:
  docker compose --profile tools run --rm cli plugin list
  docker compose --profile tools run --rm cli wc system_status list

Cron/Queue:
  systemctl status woocommerce-cron.timer --no-pager
  /usr/local/sbin/woocommerce-cron.sh

Enable HTTPS:
  1. Point DNS to VM floating IP
  2. Place certs: /opt/woocommerce/certs/fullchain.pem + privkey.pem
  3. chmod 644 fullchain.pem && chmod 600 privkey.pem
  4. Stop HTTP:   docker compose stop nginx
  5. Start HTTPS: docker compose --profile https up -d
  6. Update WordPress Address and Site Address in wp-admin if domain changes

WooCommerce Notes:
  - Complete WooCommerce setup wizard before accepting orders.
  - Configure HTTPS before enabling real payments.
  - Configure SMTP for order emails.
  - HPOS is default for new WooCommerce installs, but old extensions may be incompatible.

Backup:
  DB:    docker compose exec db mysqldump -u root -p"$(grep MYSQL_ROOT_PASSWORD .env | cut -d= -f2)" wordpress > woocommerce-db.sql
  Files: docker run --rm -v woocommerce_wp_data:/data -v "$PWD":/backup alpine tar czf /backup/woocommerce-wp-data.tar.gz -C /data .
