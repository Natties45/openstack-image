==================================================
Welcome to your n8n Automation Server!
==================================================

Thank you for deploying the n8n Golden Image.

By default, n8n is running behind nginx on port 80.
You can access it by visiting:
  http://<YOUR_SERVER_IP>/

If the VM has a public/routable IP attached, the bootstrap will prefer it
for WEBHOOK_URL and N8N_HOST. If only a private IP is available, it falls
back to that private IP.

n8n is also reachable directly on localhost:
  http://127.0.0.1:5678/  (localhost only, not exposed externally)

---------------------------------------------------
1. CREDENTIALS & SECURITY (CRITICAL)
---------------------------------------------------
Your n8n environment variables, database password,
and encryption key have been randomly generated
and saved in:

    /root/n8n-credentials.txt

WARNING: Please backup your N8N_ENCRYPTION_KEY!
If you lose this key, you will permanently lose
access to any credentials you save in n8n.

---------------------------------------------------
2. INGRESS ARCHITECTURE
---------------------------------------------------
This image uses an always-on nginx reverse proxy:

  Port 80  — always on, serves HTTP (or redirects to 443)
  Port 443 — on when HTTPS is enabled (certs present + .env protocol=https)
  Port 5678 — localhost only (127.0.0.1), not exposed externally

N8N_PROXY_HOPS=1 in all modes — nginx is always in front of n8n.

When no SSL certs are present (or HTTPS disabled):
  - nginx serves HTTP on port 80, proxies to n8n:5678
  - http://<IP>/ works directly

When HTTPS enabled (certs present + .env protocol=https):
  - Port 80 redirects to 443
  - Port 443 serves HTTPS, proxies to n8n:5678
  - Cert files: /opt/n8n/certs/fullchain.pem + privkey.pem

Reboot behavior (preserves user intent):
  - If .env says http  → HTTP config (even if certs are still present)
  - If .env says https + certs present → HTTPS config
  - If .env says https + certs missing → falls back to HTTP + fixes .env

---------------------------------------------------
3. HOW TO ENABLE HTTPS
---------------------------------------------------
n8n must run on HTTPS with a valid domain for secure webhooks.

Automated method (recommended):
  1. Point your domain (e.g., n8n.yourdomain.com) to this server's IP.
  2. Place your SSL certificates here:
     - Certificate: /opt/n8n/certs/fullchain.pem  (chmod 644)
     - Private Key: /opt/n8n/certs/privkey.pem    (chmod 600)
  3. Run the helper:
       n8n-https-enable
     This will:
       - Update .env (N8N_HOST, N8N_PROTOCOL, WEBHOOK_URL, etc.)
       - Activate HTTPS nginx config (port 80 → 443 redirect)
       - Restart the stack

Manual method (advanced):
  1. Place certs as above.
  2. Edit /opt/n8n/.env:
     N8N_HOST=n8n.yourdomain.com
     N8N_PROTOCOL=https
     WEBHOOK_URL=https://n8n.yourdomain.com/
     N8N_SECURE_COOKIE=true
     N8N_PROXY_HOPS=1
  3. Activate HTTPS config:
     cp /opt/n8n/nginx/n8n-https.conf /opt/n8n/nginx/n8n.conf
  4. Restart:
     cd /opt/n8n && docker compose down && docker compose up -d

Check cert status:
  n8n-cert-status

---------------------------------------------------
4. HOW TO DISABLE HTTPS
---------------------------------------------------
To revert to HTTP mode (certs are PRESERVED, not deleted):

  n8n-https-disable

This will:
  - Update .env (N8N_PROTOCOL=http, WEBHOOK_URL=http://<IP>/, etc.)
  - Activate HTTP nginx config (port 80 serves directly)
  - Restart the stack
  - Keep cert files at /opt/n8n/certs/

To re-enable HTTPS later: n8n-https-enable

---------------------------------------------------
5. SERVICE MANAGEMENT
---------------------------------------------------
All configuration is stored in: /opt/n8n

To check status:
  n8n-status

To check logs:
  n8n-logs

To restart n8n:
  n8n-restart

---------------------------------------------------
6. HELPER COMMANDS
---------------------------------------------------
The following helper scripts are available system-wide:

  n8n-status         Show container status
  n8n-logs           Tail n8n logs (last 50 lines)
  n8n-restart        Restart the n8n stack
  n8n-upgrade        Save current version, pull newer image, restart
  n8n-rollback       Restore previous version from .previous-image
  n8n-exec           Run n8n CLI commands inside the container
                     Example: n8n-exec export:workflow --all

  n8n-https-enable   Enable HTTPS (requires certs, prompts for domain)
  n8n-cert-status    Show SSL certificate status + current mode
  n8n-https-disable  Disable HTTPS, revert to HTTP (certs preserved)

---------------------------------------------------
7. NOTES
---------------------------------------------------
- The bootstrap service (n8n-bootstrap.service) runs on every boot.
  It reads N8N_PROTOCOL from .env and selects the right nginx config:
  - http  → HTTP config (even if certs are present — preserves user intent)
  - https + certs present → HTTPS config
  - https + certs missing → falls back to HTTP + fixes .env
  In HTTP mode, WEBHOOK_URL and N8N_HOST are updated to the new IP
  automatically. In HTTPS mode, the domain in .env is preserved.
- N8N_PROXY_HOPS=1 in all modes (nginx always in front of n8n).
- N8N_ENCRYPTION_KEY is generated once on first boot. Do NOT change it
  after creating credentials in n8n — stored credentials will become
  undecryptable.
- Do NOT run 'docker compose down -v' on this server — it will delete
  the PostgreSQL and n8n data volumes.
- Port 5678 is bound to 127.0.0.1 only. External access is through
  nginx on port 80 (HTTP) or 443 (HTTPS).

==================================================