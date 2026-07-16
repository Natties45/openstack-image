# AnythingLLM Build Manifest

> Non-secret golden image build history. Do not record runtime/OpenStack context.

---

## Latest Build

| Field | Value |
|---|---|
| App | anythingllm |
| Status | built: standalone |
| Build date | 2026-07-08 |
| Base OS | Ubuntu 26.04 |
| Source guide | `apps/anythingllm/anythingllm.md` |

## Host Packages

Keep this section minimal. Record only packages needed to reproduce the Docker stack.

| Package | Version |
|---|---|
| docker-ce | 5:29.6.1-1~ubuntu.26.04~resolute |
| docker-ce-cli | 5:29.6.1-1~ubuntu.26.04~resolute |
| containerd.io | 2.2.5-1~ubuntu.26.04~resolute |
| docker-buildx-plugin | 0.35.0-1~ubuntu.26.04~resolute |
| docker-compose-plugin | 5.3.1-1~ubuntu.26.04~resolute |

## Runtime Tools

| Tool | Version |
|---|---|
| Docker Engine | 29.6.1 |
| Docker Compose | v5.3.1 |
| Docker Buildx | 0.35.0 |

## Container Images

| Image | Digest |
|---|---|
| mintplexlabs/anythingllm:1.14.0 | sha256: pending |
| nginx:1.27 | sha256: pending |

## Build Notes

- Fixed permission issue: Docker volume `anythingllm_data` owned by root but container user `anythingllm` (uid=1000) could not write.
- Solution: added `user: "1000:1000"` to `anythingllm` service in `docker-compose.yml` and pre-set volume permissions via `chown -R 1000:1000 /data`.
- Nginx proxy configured with `client_max_body_size 100M;` for large file uploads.
- WebSocket headers (`Upgrade`, `Connection "upgrade"`) added for streaming chat.
- Bootstrap script creates `.env` with random JWT_SECRET on first boot.
- Reset password helper script includes `set -e` and `trap` to restore `.env` on interrupt.
- **Single‑user mode:** AnythingLLM 1.14.0 ไม่ต้อง login/setup wizard — UI ใช้งานได้ทันทีหลัง VM boot
- All acceptance criteria passed before golden image capture.

## Changelog

| Date | Change |
|---|---|
| 2026-07-08 | Initial build manifest created |
| 2026-07-08 | Fixed permission issue with container user 1000:1000 |

## Do Not Record

- Image name
- Glance ID
- Server ID
- Floating IP or VM IP
- Hostname
- OpenStack project/user/auth context
- Passwords, tokens, private keys, or runtime credentials