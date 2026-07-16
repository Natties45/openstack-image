# Dependency Map — File Dependencies

> When you change File A, which files must you update? This document maps those dependencies.

---

## 📊 Dependency Matrix

| If You Change | Then Update | Why | Priority |
|---|---|---|---|
| `apps/_guest-images.md` (guest image status) | `docs/README.md` | Update status table | HIGH |
| | `AGENTS.md` (mirror matrix section) | If new OS or mirror discovered | MEDIUM |
| `apps/_app-catalog.md` (app status) | `docs/README.md` | Update status table | HIGH |
| | `docs/references/stack-components.md` | If new app category implies reusable stack pattern | MEDIUM |
| `apps/{app}/docs/{app}-review.md` | `apps/_app-catalog.md` | Mark as "has review" if new | MEDIUM |
| `docs/references/mirrors.md` (mirror config) | `AGENTS.md` (mirror matrix section) | Update with new mirror info | HIGH |
| | `apps/_guest-images.md` (if mirror changed) | Update guest image build steps | MEDIUM |
| `docs/references/cloud-init-scenarios.md` | `AGENTS.md` (cloud-init behavior section) | If new behavior discovered | MEDIUM |
| `apps/{app}/docs/{app}-post-check.md` | `docs/AI-PIPELINE.md` | If checklist introduces generic post-test policy | MEDIUM |
| | `docs/DEPENDENCIES.md` | If new dependency chain is discovered | MEDIUM |
| Cleanup flow / pre-capture phases | `docs/AI-PIPELINE.md` | Source of truth for Phase 1 + Phase 2 | HIGH |
| | `apps/{app}/{app}.md` | Per-app build guides must expose cleanup phases | HIGH |
| SSH MCP config / image-build MCP profile | `../sphere/mcp/catalog/index.json` | Machine-readable MCP source of truth | HIGH |
| | `../sphere/mcp/catalog/ssh.md` | Human-readable SSH MCP policy | HIGH |
| `apps/{app}/docs/manual.html` (user manual) | `apps/_app-catalog.md` | If manual indicates new app status | LOW |
| | `apps/{app}/docs/{app}-errors.md` | If build issue changes manual content | LOW |
| **Folder structure changes** | | | |
| Rename folder or create new domain | `docs/ARCHITECTURE.md` | Update folder tree | HIGH |
| | `docs/README.md` | Update quick links | HIGH |
| | `.gitignore` | If new temp file types | MEDIUM |

---

## 🔄 Reverse Dependency (What uses this file?)

| File | Used By | Purpose |
|---|---|---|
| `docs/README.md` | **Entry point** — links to all other docs | Domain overview |
| `docs/AI-PIPELINE.md` | Build automation | Pipeline framework |
| `docs/references/mirrors.md` | `AGENTS.md` + `apps/_guest-images.md` | Mirror selection per OS |
| `docs/references/cloud-init-scenarios.md` | `apps/_guest-images.md` + app guides | Cloud-init templates |
| `apps/_guest-images.md` | Build automation | Guest image pipeline |
| `apps/_app-catalog.md` | `docs/README.md` + AI | App status overview |
| `apps/{app}/{app}.md` | Engineer + Scribe | Per-app build guide |
| `apps/{app}/docs/{app}-review.md` | Researcher + Architect | Feature selection |
| `apps/{app}/docs/{app}-errors.md` | Engineer + Scribe | Error learning log |
| `apps/{app}/docs/{app}-build-manifest.md` | Engineer + Scribe | Build version history |
| `apps/{app}/docs/{app}-post-check.md` | Engineer + Scribe | Post-test checklist |
| `Makefile` | User | Quick automation targets |
| `CONTRIBUTING.md` | User + developer | Workflow guide |

---

## 🎯 Update Workflow

### Scenario 1: สร้าง App Image ใหม่

```text
1. Create apps/{newapp}/ folder
   ↓
2. Write apps/{newapp}/{newapp}.md (build guide)
   ↓
3. Write apps/{newapp}/{newapp}-review.md (community research)
   ↓
4. Write apps/{newapp}/{newapp}-errors.md (placeholder)
   ↓
5. Update apps/_app-catalog.md (add row with app + status)
   ↓
6. Update docs/README.md (update status table + quick links)
```

**Affected files:** 6 files

### Scenario 2: Build App Image เสร็จ

```text
1. Update apps/{app}/{app}.md (header tag: [พร้อม build] → [built: standalone])
   ↓
2. Create/Update apps/{app}/docs/{app}-build-manifest.md
   ↓
3. Update apps/_app-catalog.md (status update)
   ↓
4. Update docs/README.md (if status table needs update)
   ↓
5. Update apps/{app}/docs/{app}-errors.md (if errors occurred)
   ↓
6. Delete temp env file: tmp/{app}-build.env
```

**Affected files:** 5-6 files

---

## 🚨 Common Mistakes to Avoid

| Mistake | Impact | Fix |
|---|---|---|
| Update `apps/_app-catalog.md` but forget `docs/README.md` | Status table out of sync | Always update both |
| Change mirror but forget to update `AGENTS.md` | Mirror matrix outdated | Update dependency immediately |
| Commit `tmp/*.env` to git | Secret leakage | Add to `.gitignore` + regenerate secrets |
| Update `apps/{app}/` but forget to update `apps/_app-catalog.md` | Status out of sync | Check catalog after every build |

---

## 📌 Checklist Before Commit

```bash
# Before you git commit, ask yourself:

1. Did I update docs/README.md if I changed _catalog or _guest-images?     [ ] ✅
2. Did I update AGENTS.md if I changed mirror or cloud-init?              [ ] ✅
3. Did I update apps/_app-catalog.md if I created/updated app?            [ ] ✅
4. Did I check for .gitignore violations (tmp/)?                           [ ] ✅
5. Did I delete temp env files (tmp/{app}-build.env)?                      [ ] ✅
6. Did I verify all internal links work? (no broken paths)                [ ] ✅

If any [ ] is empty → fix before commit!
```

---

**Version:** 2026-07-16
**Purpose:** Help AI + users track which files must be updated together
**Use:** Before every commit, consult this document
