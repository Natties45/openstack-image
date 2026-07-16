# Ollama + Open WebUI — Build Manifest
> Built: 2026-06-21 | Status: PASS — pre-capture gate passed

---

## Build Summary

| Field | Value |
|---|---|
| **App** | Ollama + Open WebUI |
| **Build Date** | 2026-06-21 |
| **Status** | Pre-capture gate: ALL PASSED |
| **Base OS** | Ubuntu 26.04 LTS |
| **Docker** | 29.6.0 |
| **Docker Compose** | 5.1.4 |

## Docker Stack Packages

| Package | Version |
|---|---|
| docker-ce | 5:29.6.0-1~ubuntu.26.04~resolute |
| docker-ce-cli | 5:29.6.0-1~ubuntu.26.04~resolute |
| containerd.io | 2.2.5-1~ubuntu.26.04~resolute |
| docker-buildx-plugin | 0.34.1-1~ubuntu.26.04~resolute |
| docker-compose-plugin | 5.1.4-1~ubuntu.26.04~resolute |

## Container Images

| Image | Tag | Digest |
|---|---|---|
| ollama/ollama | latest | sha256:bfc9c6d53cc6989aa5131a6fde6b162b2802d4d337657f3253b5f69579bddeee |
| ghcr.io/open-webui/open-webui | main | sha256:7f1b0a1a50cfbac23da3b16f96bc968fd757b26dc9e54e93813d61768ea9184e |

## Runtime Tools

| Tool | Version |
|---|---|
| Ollama | 0.30.10 |

## Pre-Pulled Models

| Model | Size | Status |
|---|---|---|
| gemma3:4b | ~3.3 GB | Pulled |
| llama3.2:1b | ~1.3 GB | Pulled |

## Build Notes

- CPU-only deployment, Ollama binds 127.0.0.1:11434, Open WebUI on port 3000
- `OLLAMA_KEEP_ALIVE=5m` enabled for RAM management
- Bootstrap tested: containers start, health checks pass, credentials written
- Pre-capture gate: all checks passed (containers stopped, volumes present with models, runtime files absent)
- Models stored in named volume `ollama_models` — preserved after capture
