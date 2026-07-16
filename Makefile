.PHONY: help build-app validate-env list-apps cleanup-temp docs clean

help:
	@echo "╔═══════════════════════════════════════════════════════════════╗"
	@echo "║     OpenStack Image Build — Automation Targets                ║"
	@echo "╚═══════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Usage:"
	@echo "  make build-app APP=<app_name> ENV=<path_to_env>"
	@echo "  make validate-env ENV=<path_to_env>"
	@echo "  make list-apps"
	@echo "  make cleanup-temp"
	@echo "  make docs"
	@echo "  make help"
	@echo ""
	@echo "Examples:"
	@echo "  make build-app APP=wordpress ENV=tmp/wordpress-build.env"
	@echo "  make validate-env ENV=tmp/app-build.env"
	@echo "  make list-apps"
	@echo "  make cleanup-temp"
	@echo ""

# Build an app image (with validation)
build-app:
	@if [ -z "$(APP)" ]; then \
		echo "❌ Error: APP is required"; \
		echo "Usage: make build-app APP=<app_name> ENV=<path_to_env>"; \
		exit 1; \
	fi
	@if [ -z "$(ENV)" ]; then \
		echo "❌ Error: ENV is required"; \
		echo "Usage: make build-app APP=<app_name> ENV=<path_to_env>"; \
		exit 1; \
	fi
	@echo "🔍 Validating environment..."
	@if [ -f "$(ENV)" ]; then \
		echo "✅ Environment file exists: $(ENV)"; \
	else \
		echo "❌ Environment file not found: $(ENV)"; \
		exit 1; \
	fi
	@if [ -d "apps/$(APP)" ]; then \
		echo "✅ App found: apps/$(APP)"; \
	else \
		echo "❌ App not found: apps/$(APP)"; \
		exit 1; \
	fi
	@echo ""
	@echo "🚀 Ready to build $(APP) image"
	@echo "   Environment: $(ENV)"
	@echo "   Guide: apps/$(APP)/$(APP).md"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Review docs/AI-PIPELINE.md for framework"
	@echo "  2. Review apps/$(APP)/$(APP).md for app-specific steps"
	@echo "  3. Copy templates from scripts/templates/ to temp location"
	@echo "  4. Run build steps on golden-image VM"

# Validate environment file before build
validate-env:
	@if [ -z "$(ENV)" ]; then \
		echo "❌ Error: ENV is required"; \
		echo "Usage: make validate-env ENV=<path_to_env>"; \
		exit 1; \
	fi
	@echo "🔍 Validating environment file: $(ENV)"
	@if [ ! -f "$(ENV)" ]; then \
		echo "❌ File not found: $(ENV)"; \
		exit 1; \
	fi
	@echo "✅ Checking required variables..."
	@if grep -q "IMAGE_BUILD_HOST" $(ENV); then echo "  ✓ IMAGE_BUILD_HOST"; else echo "  ✗ Missing IMAGE_BUILD_HOST"; exit 1; fi
	@if grep -q "IMAGE_BUILD_USER" $(ENV); then echo "  ✓ IMAGE_BUILD_USER"; else echo "  ✗ Missing IMAGE_BUILD_USER"; exit 1; fi
	@if grep -q "IMAGE_BUILD_PASSWORD" $(ENV); then echo "  ✓ IMAGE_BUILD_PASSWORD"; else echo "  ✗ Missing IMAGE_BUILD_PASSWORD"; exit 1; fi
	@if grep -q "IMAGE_BUILD_SSH_PORT" $(ENV); then echo "  ✓ IMAGE_BUILD_SSH_PORT"; else echo "  ✗ Missing IMAGE_BUILD_SSH_PORT"; exit 1; fi
	@echo ""
	@echo "✅ Environment file is valid!"

# List all available apps
list-apps:
	@echo "📦 Available Apps:"
	@echo ""
	@ls -1d apps/*/ 2>/dev/null | sed 's|apps/||;s|/||' | while read app; do \
		if [ -f "apps/$$app/$$app.md" ]; then \
			status=$$(grep -o '\[.*\]' "apps/$$app/$$app.md" | head -1); \
			printf "  %-15s %s\n" "$$app" "$$status"; \
		else \
			printf "  %-15s %s\n" "$$app" "[no guide]"; \
		fi; \
	done
	@echo ""

# Clean up temporary files
cleanup-temp:
	@echo "🧹 Cleaning up temporary files..."
	@rm -rf tmp/ && echo "  ✓ Removed tmp/"
	@rm -rf tmp/*.env && echo "  ✓ Removed tmp/*.env"
	@rm -rf scripts/temp/ && echo "  ✓ Removed scripts/temp/"
	@echo ""
	@echo "✅ Cleanup complete!"

# Show documentation index
docs:
	@echo "📚 Documentation Index:"
	@echo ""
		@echo "Essential Reading:"
		@echo "  📖 docs/README.md               - Domain overview (start here)"
		@echo "  📖 AGENTS.md                    - Workspace instructions"
		@echo "  📖 docs/AI-PIPELINE.md          - Build pipeline framework"
	@echo ""
	@echo "References:"
	@echo "  📖 docs/references/mirrors.md                  - Thai mirror matrix"
	@echo "  📖 docs/references/cloud-init-scenarios.md     - Cloud-init templates"
	@echo ""
	@echo "Examples:"
	@echo "  (planned — see apps/{app}/{app}.md for per-app guides)"
	@echo ""
	@echo "Troubleshooting:"
	@echo "  📖 docs/DEPENDENCIES.md         - File dependencies"
	@echo "  📖 docs/ARCHITECTURE.md         - Folder structure explanation"
	@echo ""

# Clean project (remove all temp files)
clean:
	@echo "🧹 Full cleanup..."
		@rm -rf tmp/
		@rm -rf scripts/temp/
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.pyc" -delete 2>/dev/null || true
	@echo "✅ Clean complete!"

# Show current status (git + build)
status:
	@echo "📊 Project Status:"
	@echo ""
	@echo "Git Status:"
	@git status --short || echo "  Not a git repository"
	@echo ""
	@echo "Available Apps:"
	@make list-apps
	@echo ""
	@echo "Temporary Files:"
	@if [ -d "build/tmp" ]; then ls -la build/tmp 2>/dev/null || echo "  (empty)"; else echo "  (none)"; fi
