# WordPress Build Manifest

> Non-secret golden image build history. Do not record runtime/OpenStack context.

---

## Latest Build

| Field | Value |
|---|---|
| App | wordpress |
| Status | ✅ Built successfully — pre-capture gate passed; post-test PASS; no-cleanup |
| Build date | 2026-07-10 |
| Base OS | Ubuntu 26.04 LTS |
| Source guide | `apps/wordpress/wordpress.md` |

## Host Packages

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
| Docker Buildx | v0.35.0 |

## Container Images

| Image | Digest |
|---|---|
| `wordpress-local-mariadb:11.4.8-tools` (derived from `mariadb:11.4.8@sha256:bc474f00629f0123c10f9e1bca193a45d18af15a274cf0656acda64f1086c3b6`) | `sha256:0c916786ecadf0e9a0be96981c60007c56943f320db706640c0053b235909751` |
| `wordpress-local-fpm:7.0.0-php8.3-tools` (derived from `wordpress:7.0.0-php8.3-fpm@sha256:deb75f3a393f409d0fc4a9ec0aed1706e708b459014663b21774db5ded82ba3d`) | `sha256:cae18044ffae7c7daf268ec409c99829c0d372a6ce4faf52226f0b255ad2e4c0` |
| `wordpress-local-nginx:1.30.3-tools` (derived from `nginx:1.30.3@sha256:5825bde471b86b270298e80ba1f0f3e515a73da1a17a982632f1c262689f1144`) | `sha256:e30b6bc18a0991a056d28bd744ffdfe107a06627e8dcb6403a5a9767dbd13a79` |
| `wordpress-local-cli:2.12.0-php8.3-tools` (derived from `wordpress:cli-2.12.0-php8.3@sha256:f8aeb68164c6a04f5dcc91da30d8ffa096b0f7fafb7a65f144c2dd62587caca0`) | `sha256:b171062c548d9677dcd041d8b8a0c854d8338a4764246813508255f00ca8e014` |

## Build Notes

- Rebuild with pinned semver tags and customer-hardening fixes
- WP-CLI Dockerfile uses `apk` (Alpine-based image) instead of `apt-get`
- All 4 local derivative images built and preserved
- Bootstrap test passed: WordPress accessible on HTTP, no pull on first boot
- Pre-capture gate passed: service enabled, scripts exist, runtime files absent, images preserved, containers/volumes stopped
- VM left running for inspection (no poweroff)
- Post-test PASS on a fresh VM from the image: SSH login worked, cloud-init completed, machine-id and SSH host keys regenerated, WordPress bootstrap created runtime files, containers became healthy, no first-boot Docker pull occurred, helper commands worked, browser wizard completed, dashboard login worked, and a test post was published and visible publicly.
- Post-test cleanup mode: `no-cleanup` — runtime containers, volumes, generated runtime credentials, temporary admin user, and test post were intentionally left for admin inspection.
- Keypair note: fresh VM root `authorized_keys` was absent/empty while password SSH login worked. This means no golden-image key leak was found; keypair injection must be verified in the OpenStack server-create settings if key-based login is required.

## Changelog

| Date | Change |
|---|---|
| 2026-07-10 | Rebuild with pinned tags: `wordpress:7.0.0-php8.3-fpm`, `nginx:1.30.3`, `mariadb:11.4.8@sha256:...`, `wordpress:cli-2.12.0-php8.3` |
| 2026-07-10 | Customer-hardening: alphanumeric passwords, offline-safe bootstrap, English-only docs, 6 helper scripts |
| 2026-07-10 | Fixed WP-CLI Dockerfile to use `apk` (Alpine) instead of `apt-get` |
| 2026-07-10 | Post-test PASS on fresh VM; cleanup mode `no-cleanup` for admin inspection |

## Do Not Record

- Image name
- Glance ID
- Server ID
- Floating IP or VM IP
- Hostname
- OpenStack project/user/auth context
- Passwords, tokens, private keys, or runtime credentials
