Dify CE Image
=============

This VM includes Dify Community Edition (CE) — a production-grade
AI application platform with RAG, workflow, agent, and chat capabilities.

First steps:
  1. Open OpenStack security group port 80 (and 22 for SSH).
  2. SSH into the VM.
  3. Read credentials:
       cat /root/dify-credentials.txt
  4. Open your browser to:
       http://<VM-IP>/install
  5. Enter the INIT_PASSWORD from credentials to complete setup.
  6. Create your admin account.
  7. Add LLM providers: Settings → Model Providers → Add provider.

What is included:
  - Dify CE v1.14.2 (11 Docker containers)
    - API (Flask + Gunicorn)
    - Worker (Celery — dataset indexing, workflow, email)
    - Worker Beat (Celery beat scheduler)
    - Web (Next.js frontend)
    - API WebSocket (real-time collaboration)
    - PostgreSQL 15 (database)
    - Redis 6 (cache + message broker)
    - Nginx (reverse proxy on port 80)
    - Sandbox (code execution — Python/JS)
    - SSRF Proxy (Squid — security isolation)
    - Weaviate (vector database)

Key features:
  - RAG (Retrieval-Augmented Generation) with knowledge bases
  - Visual workflow builder (branching, iteration, tools)
  - Agent mode with tool calling
  - Plugin marketplace for custom providers/tools
  - App publishing with public endpoints
  - 50+ built-in LLM provider connectors
  - No GPU required — uses external LLM APIs (OpenAI, Anthropic, etc.)

System requirements:
  - Minimum: 2 vCPU / 8 GB RAM / 25 GB disk
  - Recommended: 4 vCPU / 8 GB RAM / 30 GB disk

Default configuration:
  - PostgreSQL 15 (Alpine) — default and recommended
  - Weaviate — default vector database
  - Redis for Celery broker + cache
  - Nginx reverse proxy on port 80
  - External LLM API only (no local models bundled)
  - INIT_PASSWORD required for initial setup (stored in credentials)

Check service status:
  systemctl status docker
  systemctl status dify-bootstrap.service
  docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env ps

View logs:
  docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env logs -f
  docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env logs api

Restart services:
  docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env restart

Stop services:
  docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env down

Update Dify:
  # Edit docker-compose.yml with new image tags, then:
  docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env pull
  docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env up -d

Database backup:
  docker exec dify-postgres pg_dump -U postgres dify > /root/dify-backup-$(date +%Y%m%d).sql

Troubleshooting:
  - If API not responding: check api logs
      docker compose -f /opt/dify/docker-compose.yml --env-file /opt/dify/.env logs api
  - If out of memory: reduce CELERY_WORKER_AMOUNT in .env
      sed -i 's/CELERY_WORKER_AMOUNT=2/CELERY_WORKER_AMOUNT=1/' /opt/dify/.env
  - If setup page not loading: check nginx and api logs

Known limitations:
  - Weaviate may consume high RAM with many knowledge bases — monitor memory
  - CPU-only: document indexing uses CPU; add GPU for faster embedding
  - Not for multi-tenant SaaS without commercial license

License:
  Dify Open Source License (based on Apache 2.0 with additional conditions)
  - Free for self-host in single organization
  - Multi-tenant service prohibited without written permission
  - Do not remove or modify Dify LOGO/copyright
  - Full license: https://github.com/langgenius/dify/blob/main/LICENSE

Security notes:
  - INIT_PASSWORD protects initial setup — keep it private.
  - Port 80 is exposed on all interfaces. Restrict via OpenStack security group.
  - Keep /opt/dify/.env private (chmod 600).
  - Do not change SECRET_KEY after initial setup — will invalidate all sessions.
  - Keep Dify updated — security patches are released frequently.
