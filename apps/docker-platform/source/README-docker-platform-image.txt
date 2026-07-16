Docker Platform Image
=====================

This VM includes Docker CE, Docker Buildx, Docker Compose plugin, Portainer CE,
and Nginx Proxy Manager.

First steps:
  1. Open OpenStack security group ports 22, 80, 443, 81, and 9443.
  2. SSH into the VM.
  3. Read credentials:
       cat /root/docker-platform-credentials.txt
  4. Open Portainer:
       https://<VM-IP>:9443
  5. Open Nginx Proxy Manager:
       http://<VM-IP>:81

Roles:
  - Portainer manages containers, stacks, networks, and volumes.
  - Nginx Proxy Manager manages domains, reverse proxy rules, and Let's Encrypt certificates.

Security notes:
  - Change the Nginx Proxy Manager password immediately after first login.
  - Portainer mounts /var/run/docker.sock and can control this Docker host.
  - Docker group access is root-equivalent. Add users only when you trust them.
  - Published container ports are reachable from outside unless restricted by binding, OpenStack security groups, or DOCKER-USER rules.

Common commands:
  systemctl status docker
  systemctl status docker-platform-bootstrap.service
  docker compose -f /opt/docker-platform/docker-compose.yml ps
  docker compose -f /opt/docker-platform/docker-compose.yml logs -f

Update platform containers:
  docker compose -f /opt/docker-platform/docker-compose.yml --env-file /opt/docker-platform/.env pull
  docker compose -f /opt/docker-platform/docker-compose.yml --env-file /opt/docker-platform/.env up -d

Example templates are stored under:
  /opt/docker-platform/examples/
