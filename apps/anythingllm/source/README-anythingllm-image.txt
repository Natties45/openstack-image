=== AnythingLLM Docker Image — Ubuntu 26.04 ===

**Single‑user mode:** ไม่ต้อง login/setup wizard — ใช้ได้ทันทีหลัง VM boot

Access:      http://<VM-IP>
Setup:       Open in browser → เริ่มใช้งานได้ทันที (ไม่มี authentication)

Credentials:
  JWT Secret:  /root/anythingllm-credentials.txt (ใช้ภายใน container)
  **ไม่ต้องตั้ง password admin — UI เปิดใช้งานได้โดยไม่ต้อง login**

Directory Structure:
  /opt/anythingllm/               Main directory
    docker-compose.yml            Service definitions
    nginx.conf                    Nginx proxy configuration (editable)

Common Commands:
  cd /opt/anythingllm
  docker compose ps               Check service status
  docker compose logs -f          View log stream
  docker compose restart          Restart all services
  docker compose restart nginx    Restart after editing nginx.conf

Troubleshooting:
  If you forget your admin password, you can run the password reset helper script:
  anythingllm-reset-password

  This script will temporarily disable authentication, allowing you to log in 
  and reset your password via the web UI.

Data & Backups:
  Persistent data (documents, workspaces, database) is stored in the Docker volume
  named 'anythingllm_data'.
