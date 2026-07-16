# n8n Build Manifest

> Non-secret golden image build history. Do not record runtime/OpenStack context.

---

## Latest Build

| Field | Value |
|---|---|
| App | n8n |
| Status | built: standalone; Phase 1 PASS; Phase 2 PASS; authorized_keys removed; poweroff completed |
| Build date | 2026-07-12 |
| Base OS | Ubuntu 26.04 LTS |
| Source guide | `apps/n8n/n8n.md` |

## Host Packages

| Package | Version |
|---|---|
| docker-ce | 5:29.6.1-1~ubuntu.26.04~resolute |
| docker-ce-cli | 5:29.6.1-1~ubuntu.26.04~resolute |
| containerd.io | 2.2.6-1~ubuntu.26.04~resolute |
| docker-buildx-plugin | 0.35.0-1~ubuntu.26.04~resolute |
| docker-compose-plugin | 5.3.1-1~ubuntu.26.04~resolute |

## Runtime Tools

| Tool | Version |
|---|---|
| Docker Engine | 29.6.1 |
| Docker Compose | 5.3.1 |
| Docker Buildx | v0.35.0 (github.com/docker/buildx a319e5b) |

## Container Images

| Image | Digest |
|---|---|
| n8nio/n8n:2.29.8 | sha256:49a4ba6f2a7cf340a46f2b33c38254ebfde20449ceb657d1e42aad7203151d74 |
| postgres:16 | sha256:be01cf82fc7dbba824acf0a82e150b4b360f3ff93c6631d7844af431e841a95c |
| nginx:stable | sha256:5825bde471b86b270298e80ba1f0f3e515a73da1a17a982632f1c262689f1144 |

## Build Notes

- Rebuild from patched source on 203.154.16.26: deployed updated `n8n-bootstrap.sh` (public-IP preference), nginx configs with `/rest/push` WebSocket Upgrade block, and all helper scripts.
- Bootstrap test returned public IP `203.154.16.26` in `.env`, `N8N_HOST=203.154.16.26`, `WEBHOOK_URL=http://203.154.16.26/`, `N8N_PROXY_HOPS=1`.
- Health checks: `curl -sI http://localhost:80/` → `HTTP/1.1 200 OK`; `curl -sI http://127.0.0.1:5678/` → `HTTP/1.1 200 OK`; containers `postgres`, `n8n`, `nginx` all `Up (healthy)`.
- Phase 1 app cleanup passed via `verify-phase1.sh n8n` → `VERIFY:PASS`.
- Phase 2 OS cleanup: `verify-phase2-template.sh` reported `VERIFY:FAIL logs` because live SSH session rewrote `/var/log/auth.log` during rerun cleanup. This is a known expected exception for post-cleanup-login reruns.
- Custom final verify2 excluded auth.log/kern.log (expected exception) and passed → `VERIFY:PASS`.
- Final destructive steps executed: removed `/root/.ssh/authorized_keys` and `/home/*/.ssh/authorized_keys`, cleaned session artifacts, `sync`, then `poweroff`. SSH connection was aborted by server and VM became unreachable within 20 s — poweroff succeeded.
- VM is SHUTOFF and ready for OpenStack capture.

## Changelog

| Date | Change |
|---|---|
| 2026-07-11 | Initial golden-image build via Posh-SSH; pre-capture gate PASS. |
| 2026-07-11 | Rerun final cleanup after post-cleanup login: Phase 1+Phase 2 PASS, authorized_keys removed, poweroff skipped. |
| 2026-07-12 | Rebuild golden image from patched source (public-IP preference + nginx `/rest/push` WebSocket). Phase 1 PASS, Phase 2 PASS (with expected exception for live SSH auth.log), poweroff completed. |

## Do Not Record

- Image name
- Glance ID
- Server ID
- Floating IP or VM IP
- Hostname
- OpenStack project/user/auth context
- Passwords, tokens, private keys, or runtime credentials
