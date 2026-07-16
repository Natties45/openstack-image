# Contributing Guide — OpenStack Image Project

> How to work with this project: creating images, updating guides, troubleshooting, and best practices.

---

## 📖 Before You Start

Read these in order:
1. `docs/README.md` — Domain overview
2. `AGENTS.md` — If you're an AI agent
3. `AGENTS.md` — Image-specific rules
4. `docs/AI-PIPELINE.md` — Build pipeline framework
5. `docs/DEPENDENCIES.md` — File dependency map

---

## 🚀 Creating a New App Image

### Step 1: Research & Plan
1. Read `apps/_app-catalog.md` — check if app already exists
2. Search community (Reddit, StackOverflow, GitHub, Hacker News)
3. Document findings in `apps/{app}/{app}-review.md`
4. Propose features and get user approval

### Step 2: Create Folder Structure
```bash
mkdir -p apps/{app}
touch apps/{app}/{app}.md
touch apps/{app}/{app}-review.md
touch apps/{app}/{app}-errors.md
touch apps/{app}/{app}-post-check.md
```

### Step 3: Write Build Guide
- File: `apps/{app}/{app}.md`
- ✅ Self-contained (copy-paste commands work)
- ✅ Use `cat > file << 'EOF'` for creating files
- ✅ Include comments explaining each step
- ✅ Header tag: `[พร้อม build]` when ready

Example structure:
```markdown
# Build Guide: {App}

> Status: [พร้อม build]

## Prerequisites
- OS: Ubuntu 26.04
- Disk: 10GB free
- Memory: 2GB minimum

## Step 1: Install Base Packages
# 1.1 Update system
apt update && apt upgrade -y

# 1.2 Install base packages
apt install -y curl git jq vim

## Step 2: Install Docker
# Follow official Docker install process...
```

### Step 4: Create Community Research
- File: `apps/{app}/{app}-review.md`
- ✅ Quote what real users say (cite sources)
- ✅ Divide by experience level (Beginner / Intermediate / Advanced)
- ✅ Summarize feature recommendations
- ❌ NOT your personal opinion or AI test scenario

Example:
```markdown
# Community Research: {App}

## Beginner Questions
- How to install? → From official docs: [URL]
- Common issue: Docker pull timeout → Solution: [URL]

## Intermediate Features
- Multi-language support → Recommended by community
- Backup strategy → Best practice: [URL]

## Advanced Customization
- Custom plugins → Community consensus: [URL]
```

### Step 5: Update Catalog
Update `apps/_app-catalog.md`:
```markdown
| {App} | {Description} | `apps/{app}/` | ✅ พร้อม build |
```

### Step 6: Update Main README
Update `docs/README.md`:
1. Add row to status table
2. Update quick links

---

## 🏗️ Building an Image

### Pre-flight (Do NOT skip!)

```bash
# 1. Verify app folder exists
ls -d apps/{app}/
test -f apps/{app}/{app}.md

# 2. Read the build guide
cat apps/{app}/{app}.md

# 3. Check dependencies
cat docs/AI-PIPELINE.md          # Framework
cat AGENTS.md               # Rules

# 4. Verify guest image is ready
grep "{OS}" apps/_guest-images.md | grep "✅"
```

### During Build

```bash
# 1. Create temp env (gitignored)
cat > tmp/{app}-build.env << 'EOF'
IMAGE_BUILD_HOST=—
IMAGE_BUILD_USER=root
IMAGE_BUILD_PASSWORD=—
IMAGE_BUILD_SSH_PORT=22
IMAGE_BUILD_SERVER_ID=—
IMAGE_BUILD_IMAGE_NAME=ubuntu-26.04-{app}-YYYYMMDD
EOF

# 2. Follow build guide: apps/{app}/{app}.md
# 3. Copy templates from scripts/templates/ as needed
# 4. SSH to VM and run commands
# 5. Record any errors in apps/{app}/{app}-errors.md
```

### Post-Build Verification

✅ **Pre-Capture Gate** (MUST pass before snapshot):
```bash
# 1. Bootstrap service enabled?
systemctl is-enabled {app}-bootstrap.service

# 2. Containers stopped?
docker compose ps

# 3. Images preserved?
docker images | grep {app}

# 4. No secrets?
test ! -e /opt/{app}/.env

# 5. No runtime volumes?
docker volume ls | grep {app}

# 6. Cleanup done?
test ! -e /var/log/{app}-bootstrap.log
```

### Post-Build Updates

```bash
# 1. Update header tag
# File: apps/{app}/{app}.md
# Change: [พร้อม build] → [built: standalone]

# 2. Update catalog
# File: apps/_app-catalog.md
# Change: "พร้อม build" → "built standalone"

# 3. Record build manifest
# File: apps/{app}/{app}-build-manifest.md
# Add: build date, Ubuntu version, Docker stack package versions, tool versions, container image tag+digest
# Do NOT record image name, Glance ID, server ID, IP, hostname, OpenStack context, or credentials

# 4. DELETE temp env
rm tmp/{app}-build.env

# 5. (Optional) Record errors
# File: apps/{app}/{app}-errors.md
# IF any failures occurred
```

---

## 🐛 Troubleshooting & Error Logging

### When Build Fails

1. **Document the error** in `apps/{app}/{app}-errors.md`
   ```markdown
   ## Error: [Error Title]
   
   **Command:** `command that failed`
   **Error message:** [full error]
   **Root cause:** [why it failed]
   **Fix:** [how to fix]
   **Verified:** `command to verify fix works`
   ```

2. **Is it a generic pattern?** → Create `problem/generic/{issue}.md`
   - Example: `problem/generic/docker-pull-timeout-proxy.md`
   - Use `problem/_template.md` as guide

---

## 📝 Updating Documentation

### When to Update What

| File Changed | Update These |
|---|---|
| `apps/{app}/{app}.md` | `apps/_app-catalog.md` (header tag) |
| `apps/_app-catalog.md` | `docs/README.md` (status table) |
| `docs/references/mirrors.md` | `AGENTS.md` (mirror matrix) |
| Create new OS in guest images | `apps/_guest-images.md` + `docs/README.md` |
| Create new issue pattern | `problem/generic/{issue}.md` |
| Create folder or rename | `docs/ARCHITECTURE.md` + `docs/README.md` |

### Verify Links

Before committing, check:
```bash
# 1. All links in docs/ are valid
grep -r "docs/" docs/ | grep "\.md" | head -10

# 2. All links to apps/ are valid
ls -d apps/*/

# 3. All references to mirrors.md
grep -r "mirrors.md" docs/
```

---

## ✅ Pre-Commit Checklist

Before running `git commit`:

```bash
# 1. Documentation complete?
[ ] apps/_app-catalog.md updated?
[ ] apps/{app}/ files complete?
[ ] docs/README.md updated?
[ ] docs/DEPENDENCIES.md cross-checked?

# 2. No secrets leaked?
[ ] tmp/*.env deleted? (check with: ls tmp/)
[ ] No .env files committed? (check: git status)
[ ] No passwords in files? (grep -r "password=" .)

# 3. Links verified?
[ ] All internal links work?
[ ] No broken paths?

# 4. Formatting good?
[ ] Markdown valid? (check: `code` and *emphasis* syntax)
[ ] Comments clear and helpful?

# 5. Dependencies updated?
[ ] If changed A, also updated B? (check: docs/DEPENDENCIES.md)

# 6. Clean build?
[ ] No build/ temp files? (check: make cleanup-temp)
[ ] Git status clean? (check: git status)
```

---

## 🔄 Git Workflow

### Create Feature Branch
```bash
git checkout -b feature/new-app-odoo
git checkout -b fix/mirror-404-rocky10
```

### Commit Message Format
```
[feature/fix/docs] Brief description (50 chars max)

Longer explanation if needed. Reference:
- Closes: #issue (if applicable)
- Depends: docs/README.md, apps/_app-catalog.md
- Updated: [list of files changed]

Example commit message:
[feature] Add Odoo app image with PostgreSQL

- Created apps/odoo/ with docker-compose.yml
- Added odoo.md (build guide) [พร้อม build]
- Added odoo-review.md (community research)
- Updated apps/_app-catalog.md
- Updated docs/README.md (status table)

Updated files:
  M  apps/_app-catalog.md
  A  apps/odoo/odoo.md
  A  apps/odoo/odoo-review.md
  M  docs/README.md
```

### Push & Review
```bash
git push origin feature/new-app-odoo
# Create PR / review checklist
```

---

## 🎯 Quick Makefile Commands

```bash
# List available apps
make list-apps

# Validate environment before build
make validate-env ENV=tmp/app-build.env

# Check build readiness
make build-app APP=wordpress ENV=tmp/wordpress-build.env

# Show documentation index
make docs

# Clean up temp files
make cleanup-temp

# Show this help
make help
```

---

## 💡 Tips & Best Practices

### ✅ DO
- ✅ Test build guide before committing
- ✅ Use `cat > file << 'EOF'` for file creation (self-contained)
- ✅ Comment every section (what + why)
- ✅ Keep images lightweight (cleanup before capture)
- ✅ Pre-pull Docker images (reduce inter bandwidth on first boot)
- ✅ Document errors immediately (learn from failures)
- ✅ Use Thai mirror when building (faster)
- ✅ Verify systemd service is enabled before capture (critical!)

### ❌ DON'T
- ❌ Commit secrets (passwords, tokens, API keys, .env)
- ❌ Commit temp IP, server ID, floating IP, Glance UUID
- ❌ Use `docker system prune -a` (removes pre-pulled images!)
- ❌ Leave containers running before capture
- ❌ Leave test bootstrap logs before capture
- ❌ Capture with systemd service disabled
- ❌ Copy-paste sed patterns across OS (verify first!)
- ❌ Test scenario in {app}-review.md (community research only!)
- ❌ Break internal links when restructuring

---

## 🚨 Emergency / Cleanup

### Remove Accidentally Committed Secret
```bash
# If you accidentally committed a .env file:
git rm --cached tmp/wordpress-build.env
git commit -m "Remove accidentally committed .env"
# Then regenerate credentials!
```

### Revert Last Commit
```bash
git reset --soft HEAD~1
# Edit files
git add .
git commit -m "Fixed version"
```

### Clean All Temp Files
```bash
make clean
# Or manual:
rm -rf tmp/ tmp/ scripts/temp/
```

---

## 📞 Questions?

1. Check `docs/README.md` — Start here
2. Check `docs/DEPENDENCIES.md` — File relationships
3. Check `docs/ARCHITECTURE.md` — Folder structure
4. Check `problem/generic/` — Common issues
5. Read `docs/AI-PIPELINE.md` — Build framework

---

**Version:** 2026-06-12  
**Updated:** When project restructured to `/docs` + `/scripts/templates/`
