Ollama + Open WebUI Image
=========================

This VM includes Ollama (local LLM runner) and Open WebUI (chatbot web interface)
running via Docker Compose.

First steps:
  1. Open OpenStack security group port 3000 (and 22 for SSH).
  2. SSH into the VM.
  3. Read credentials:
       cat /root/ollama-openwebui-credentials.txt
  4. Open your browser to:
       http://<VM-IP>:3000
  5. Create your first account — this becomes the admin account.

Pre-pulled models:
  - gemma3:4b   (~3 GB RAM, best quality per size)
  - llama3.2:1b (~1.2 GB RAM, lightweight fallback)

Roles:
  - Ollama runs LLM models locally on CPU (no GPU needed).
  - Open WebUI provides a chat interface, RAG, and multi-user web UI.

Default behavior:
  - OLLAMA_KEEP_ALIVE=5m — models unload from RAM after 5 minutes of inactivity.
  - Ollama binds to localhost only (127.0.0.1:11434). Open WebUI connects internally via Docker network.
  - ENABLE_SIGNUP=true — anyone with access to port 3000 can register.

Pull additional models:
  docker exec -it ollama ollama pull <model-name>

List installed models:
  docker exec ollama ollama list

Check service status:
  systemctl status docker
  systemctl status ollama-openwebui-bootstrap.service
  docker compose -f /opt/ollama-openwebui/docker-compose.yml ps

View logs:
  docker compose -f /opt/ollama-openwebui/docker-compose.yml logs -f

Update containers:
  docker compose -f /opt/ollama-openwebui/docker-compose.yml --env-file /opt/ollama-openwebui/.env pull
  docker compose -f /opt/ollama-openwebui/docker-compose.yml --env-file /opt/ollama-openwebui/.env up -d

Update models:
  docker exec -it ollama ollama pull <model-name>

Sizing recommendation:
  - 2 vCPU / 8 GB RAM / 30 GB disk for 1B-3B models
  - 4 vCPU / 16 GB RAM / 50 GB disk for 4B-7B models

License note:
  - Ollama: MIT (free for all uses).
  - Open WebUI: custom license. Keep "Open WebUI" branding if you have more than 50 users.

Model recommendations for more models:
  Browse: https://ollama.com/library

Security notes:
  - Open WebUI signup is enabled by default. Disable after creating admin if single-user.
  - Port 3000 is exposed on all interfaces. Restrict via OpenStack security group.
  - Keep the .env file private (chmod 600).
