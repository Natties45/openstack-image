OpenCode AI Coding Agent — Golden Image Quick Start
====================================================

1. Connect
   Open browser: http://<VM_IP>:4096
   Username: opencode
   Password: (see MOTD or /etc/opencode/environment)

2. Add API Key
   - Login → Settings → Providers
   - Add your API key (Anthropic, OpenAI, Google, OpenRouter, Zen, etc.)
   - Select default provider

3. Change Password
   nano /etc/opencode/environment
   systemctl restart opencode.service

4. Update OpenCode
   # Check latest version
   curl -s https://api.github.com/repos/anomalyco/opencode/releases/latest | grep tag_name

   # Download and replace
   VERSION="X.Y.Z"
   curl -fsSL https://github.com/anomalyco/opencode/releases/download/v${VERSION}/opencode-linux-x64.tar.gz | tar xz
   systemctl stop opencode.service
   cp opencode /usr/local/bin/opencode
   systemctl start opencode.service
   rm opencode

5. Service Management
   systemctl status opencode.service
   systemctl restart opencode.service
   journalctl -u opencode.service -f

6. Data Locations
   Sessions/Auth:  /home/opencode/.local/share/opencode/
   Provider Cache: /home/opencode/.cache/opencode/
   Config:         /home/opencode/.config/opencode/opencode.json
   Password:       /etc/opencode/environment (chmod 600)

7. Security Notes
   - HTTP only by default — no TLS
   - For HTTPS: install Nginx reverse proxy (see optional section in build guide)
   - Password stored in env var — visible via `systemctl show opencode.service`
   - Use OpenStack security group to restrict port 4096 to trusted IPs
   - API keys stored in ~/.local/share/opencode/auth.json (readable by opencode user)

8. Troubleshooting
   - Check logs: journalctl -u opencode.service -f
   - Check bootstrap log: cat /var/log/opencode-bootstrap.log
   - xdg-open error? Verify: /usr/local/bin/xdg-open exists and is executable
   - Service won't start? Check: /etc/opencode/environment exists and has valid values

MIT License — Free for all uses
https://github.com/anomalyco/opencode
