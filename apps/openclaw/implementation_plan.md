# Implementation Plan: OpenClaw

## 1. Specifications
| Parameter | Value |
|---|---|
| App Name | OpenClaw |
| Target Version | `v2026.7.1` (specific release pin) |
| Deployment Stack | OpenClaw gateway + CLI + Docker Compose + systemd bootstrap |
| Customer Service Model | 2A |
| Target OS | Ubuntu 26.04 |
| Access Model | Dashboard + SSH/CLI |
| Provider Baseline | Cloud providers + local providers |
| Network Baseline | Direct gateway first |
| Image Flavor | Browser variant (baked Chromium only) |

## 2. 5 Diagrams

### 2.1 User Journey Diagram
```mermaid
sequenceDiagram
    actor Customer as 👤 Customer
    participant VM as 🖥️ OpenStack VM
    participant MOTD as 📟 MOTD / README
    participant GW as 🌐 OpenClaw Gateway
    participant UI as 🪟 Control UI
    Customer->>VM: Boot first time
    VM->>VM: bootstrap service runs once
    VM-->>Customer: show MOTD + setup path
    Customer->>GW: open dashboard
    GW-->>Customer: onboarding / auth
    Customer->>UI: choose provider + finish setup
```

### 2.2 Architecture Diagram
```mermaid
graph TD
    VM[Ubuntu 26.04 VM] --> Docker[Docker Engine + Compose]
    Docker --> GW[openclaw-gateway]
    Docker --> CLI[openclaw-cli]
    GW --> Vol1[/home/node/.openclaw/]
    GW --> Vol2[/home/node/.config/openclaw/]
    GW --> Browser[Browser-capable runtime]
    GW --> Local[Local providers: Ollama / LM Studio]
    GW --> Cloud[Cloud providers]
```

### 2.3 Data Flow Diagram
```mermaid
sequenceDiagram
    actor User as 👤 User
    participant GW as 🌐 Gateway
    participant Provider as ☁️ Cloud / Local LLM
    participant Browser as 🌍 Browser tool
    User->>GW: chat / command
    GW->>Provider: inference / tool orchestration
    GW->>Browser: browser action when needed
    GW-->>User: response
```

### 2.4 Bootstrap Flow Diagram
```mermaid
graph TD
    Boot[First VM boot] --> Sysd[systemd oneshot bootstrap]
    Sysd --> Compose[write env + run docker compose]
    Compose --> Onboard[OpenClaw onboarding]
    Onboard --> Token[generate gateway token / config]
    Token --> Health[health check]
    Health --> Motd[write README + MOTD]
    Motd --> Lock[create lock / idempotency marker]
```

### 2.5 Security Diagram
```mermaid
graph TD
    Internet --> SG[OpenStack security group / firewall]
    SG --> GW[OpenClaw Gateway]
    GW --> Auth[shared gateway token]
    GW --> Tools[exec / browser / plugins]
    Tools --> Risk[blast-radius controls + docs]
```

## 3. Design Decisions
| Decision Point | Selection | Rationale | Ref |
|---|---|---|---|
| Version pin | Specific release `v2026.7.1` | Avoid floating tag drift | Review |
| OS baseline | Ubuntu 26.04 | Repo baseline and current image family | Catalog |
| Customer model | 2A | Operator image, not shared SaaS | Playbook |
| Fronting | Direct gateway first | Keep scope simple for initial image | User choice |
| Browser | Baked Chromium only | Enough for tool/browser flow without expanding scope too far | User choice |
| Providers | Cloud + local | Covers API-backed and local LLM setups | User choice |
| Local examples | Ollama + LM Studio | Common local provider paths in docs | User choice |
| Secrets | Generated at first boot | Keep credentials out of image | Playbook |
| Access docs | README + MOTD + dashboard | Make customer handoff explicit | Playbook |

## 4. Proposed File Paths
| Action | Target Path | Purpose |
|---|---|---|
| [NEW] | `apps/openclaw/openclaw-review.md` | Research + suitability + risk baseline |
| [NEW] | `apps/openclaw/implementation_plan.md` | Approval-ready plan before build |
| [NEW] | `apps/openclaw/openclaw.md` | Final build guide (later) |
| [NEW] | `apps/openclaw/bootstrap.sh` | First-boot bootstrap (later) |
| [NEW] | `apps/openclaw/docker-compose.yml` | Service definition (later) |
| [NEW] | `apps/openclaw/README-openclaw-image.txt` | Customer handoff doc (later) |
| [NEW] | `apps/openclaw/99-openclaw-image` | MOTD (later) |
| [NEW] | `apps/openclaw/docs/openclaw-post-check.md` | Post-test checklist (later) |

## 5. Verification Checklist
- Gateway starts and reports healthy
- Dashboard reachable
- First-boot onboarding completes
- Specific release pin is documented and used
- Browser-capable variant works
- Cloud provider path documented
- Local provider paths documented for Ollama and LM Studio
- No secret is baked into the image
- Customer 2A boundaries are explicit
