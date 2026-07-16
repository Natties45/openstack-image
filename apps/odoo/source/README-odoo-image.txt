Odoo 18 Image — Quick Start
===========================

This VM starts Odoo automatically on first boot.

Open:
  http://<VM-IP>/

Credentials:
  /root/odoo-credentials.txt

Important paths:
  /opt/odoo/docker-compose.yml
  /opt/odoo/.env
  /opt/odoo/config/odoo.conf
  /opt/odoo/addons/
  /opt/odoo/certs/fullchain.pem
  /opt/odoo/certs/privkey.pem
  /opt/odoo/backups/

HTTPS:
  1. Put certificate files here:
     /opt/odoo/certs/fullchain.pem
     /opt/odoo/certs/privkey.pem
  2. Run:
     cd /opt/odoo
     docker compose stop nginx
     docker compose --profile https up -d nginx-https

Manage:
  cd /opt/odoo
  docker compose ps
  docker compose logs -f
  docker compose restart

Backup:
  /usr/local/sbin/odoo-backup.sh

Worker tuning after resize:
  /usr/local/sbin/odoo-tune-workers.sh
  cd /opt/odoo && docker compose restart odoo

Notes:
  - Database name is fixed: odoo_prod
  - Demo data is disabled
  - Database listing is disabled
  - Change the Odoo admin password after first login
