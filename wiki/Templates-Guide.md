# Templates Guide

Complete guide for working with configuration templates in the Proxmox Installer.

## Overview

Templates are configuration files with variable placeholders that get substituted during deployment. They live in the `templates/` directory with `.tmpl` extension.

```
templates/
├── sshd_config.tmpl        # SSH daemon config
├── nftables.conf.tmpl      # Firewall rules
├── promtail.yml.tmpl       # Log collector
├── *.service.tmpl          # Systemd services
├── *.timer.tmpl            # Systemd timers
└── ...
```

## Variable Syntax

Use double curly braces: `{{VARIABLE_NAME}}`

```bash
# Template: hosts.tmpl
{{MAIN_IPV4}}  {{HOSTNAME}}.{{DOMAIN_SUFFIX}}  {{HOSTNAME}}
127.0.0.1      localhost

# Result after substitution:
192.168.1.10  myserver.example.com  myserver
127.0.0.1     localhost
```

### Variable Naming Convention

- **UPPERCASE** with underscores: `{{MAIN_IPV4}}`, `{{SSH_PORT}}`
- Match global variable names from `003-init.sh` and `001-constants.sh`
- Use descriptive names: `{{PRIVATE_SUBNET}}` not `{{PRIV_SUB}}`

## Using Templates

### Basic Substitution

```bash
# Copy template to temp, substitute, deploy
local staged=$(mktemp)
cp "templates/config" "$staged"
apply_template_vars "$staged" \
  "HOSTNAME=${PVE_HOSTNAME}" \
  "PORT=8080"
remote_copy "$staged" "/etc/app/config"
rm -f "$staged"
```

> **Note:** Template files in the repository have `.tmpl` extension (e.g., `sshd_config.tmpl`), but at runtime they are downloaded without the extension (e.g., `./templates/sshd_config`). The `deploy_template` function works with the downloaded files without `.tmpl` suffix.

### Using deploy_template Helper

Combines the above pattern in one call:

```bash
deploy_template "templates/nginx.conf" "/etc/nginx/nginx.conf" \
  "SERVER_NAME=${FQDN}" \
  "PORT=${PORT_PROXMOX_UI}"
```

### Using apply_common_template_vars

For templates using common network/system variables:

```bash
local staged=$(mktemp)
cp "templates/interfaces" "$staged"
apply_common_template_vars "$staged"
remote_copy "$staged" "/etc/network/interfaces"
```

**Common variables applied automatically:**
- `MAIN_IPV4`, `MAIN_IPV4_GW`, `MAIN_IPV6`, `IPV6_GATEWAY`
- `FQDN`, `HOSTNAME`, `INTERFACE_NAME`
- `PRIVATE_IP_CIDR`, `PRIVATE_SUBNET`, `BRIDGE_MTU`
- `DNS_PRIMARY`, `DNS_SECONDARY`
- `LOCALE`, `KEYBOARD`, `COUNTRY`
- `PORT_SSH`, `PORT_PROXMOX_UI`

## Creating New Templates

### 1. Create Template File

Create the file in `templates/` with `.tmpl` extension:

```bash
# templates/myapp.conf.tmpl
[server]
hostname = {{HOSTNAME}}
bind_address = {{MAIN_IPV4}}
port = {{MYAPP_PORT}}

[security]
admin_email = {{EMAIL}}
```

### 2. Add to Download List

Add the template to `203-templates.sh` in `template_list`:

```bash
"./templates/myapp.conf:myapp.conf"
```

### 3. Deploy in Configure Script

Use the path **without** `.tmpl` suffix (templates are downloaded without extension):

```bash
# scripts/3XX-configure-myapp.sh
_config_myapp() {
  deploy_template "templates/myapp.conf" "/etc/myapp/config.conf" \
    "HOSTNAME=${PVE_HOSTNAME}" \
    "MAIN_IPV4=${MAIN_IPV4}" \
    "MYAPP_PORT=${MYAPP_PORT:-8080}" \
    "EMAIL=${EMAIL}"
}
```

### 4. Add Global Variable (if needed)

```bash
# scripts/003-init.sh (or 001-constants.sh for constants)
MYAPP_PORT="${MYAPP_PORT:-8080}"
```

## Special Characters

The template system auto-escapes:

| Character | Escaped As |
|-----------|------------|
| `\`       | `\\`       |
| `&`       | `\&`       |
| `\|`      | `\|`       |
| newline   | `\n`       |

You don't need to manually escape values.

## Systemd Templates

### Service Template

```ini
# templates/myapp.service.tmpl
[Unit]
Description=My Application
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/myapp --config /etc/myapp/config.conf
Restart=always
User={{ADMIN_USERNAME}}

[Install]
WantedBy=multi-user.target
```

### Timer Template

```ini
# templates/myapp-check.timer.tmpl
[Unit]
Description=Run myapp check daily

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
```

### Deploy Timer

```bash
deploy_systemd_timer "myapp-check"
# Deploys: myapp-check.service + myapp-check.timer
# Enables: myapp-check.timer
```

### Deploy Service Only

```bash
deploy_systemd_service "myapp" "ADMIN_USERNAME=${ADMIN_USERNAME}"
```

## Template Validation

### Unsubstituted Placeholders

`apply_template_vars` fails if placeholders remain:

```bash
# If {{MISSING_VAR}} not substituted:
# Log: ERROR: Unsubstituted placeholders remain in /tmp/xxx: {{MISSING_VAR}}
# Returns: 1
```

### Empty Variables

Debug log for empty values:

```bash
# If HOSTNAME is empty:
# Log: DEBUG: Template variable HOSTNAME is empty, {{HOSTNAME}} will be replaced with empty string
```

### Critical Variables

`apply_common_template_vars` warns about empty critical vars:

```bash
# Log: WARNING: Critical variable MAIN_IPV4 is empty for /tmp/xxx
```

## Common Variables Reference

### Network

| Variable | Description | Example |
|----------|-------------|---------|
| `{{MAIN_IPV4}}` | Primary IPv4 | `192.168.1.10` |
| `{{MAIN_IPV4_GW}}` | IPv4 gateway | `192.168.1.1` |
| `{{MAIN_IPV6}}` | Primary IPv6 | `2001:db8::1` |
| `{{IPV6_GATEWAY}}` | IPv6 gateway | `fe80::1` |
| `{{INTERFACE_NAME}}` | Network interface | `eno1` |
| `{{BRIDGE_MTU}}` | Bridge MTU | `9000` |

### Private Network

| Variable | Description | Example |
|----------|-------------|---------|
| `{{PRIVATE_SUBNET}}` | NAT subnet | `10.0.0.0/24` |
| `{{PRIVATE_IP_CIDR}}` | Host IP in subnet | `10.0.0.1/24` |
| `{{PRIVATE_GATEWAY}}` | NAT gateway | `10.0.0.1` |

### DNS

| Variable | Description | Example |
|----------|-------------|---------|
| `{{DNS_PRIMARY}}` | Primary DNS | `1.1.1.1` |
| `{{DNS_SECONDARY}}` | Secondary DNS | `1.0.0.1` |
| `{{DNS6_PRIMARY}}` | Primary IPv6 DNS | `2606:4700:4700::1111` |
| `{{DNS6_SECONDARY}}` | Secondary IPv6 DNS | `2606:4700:4700::1001` |

### System

| Variable | Description | Example |
|----------|-------------|---------|
| `{{HOSTNAME}}` | Short hostname | `myserver` |
| `{{FQDN}}` | Full domain name | `myserver.example.com` |
| `{{TIMEZONE}}` | Timezone | `Europe/Kyiv` |
| `{{LOCALE}}` | System locale | `en_US.UTF-8` |
| `{{KEYBOARD}}` | Keyboard layout | `en-us` |
| `{{COUNTRY}}` | Country code | `US` |

### User

| Variable | Description | Example |
|----------|-------------|---------|
| `{{ADMIN_USERNAME}}` | Admin user | `deploy` |
| `{{EMAIL}}` | Admin email | `admin@example.com` |

### Ports

| Variable | Description | Default |
|----------|-------------|---------|
| `{{PORT_SSH}}` | SSH port | `22` |
| `{{PORT_PROXMOX_UI}}` | Web UI port | `8006` |

### Feature Flags

| Variable | Description | Values |
|----------|-------------|--------|
| `{{INSTALL_TAILSCALE}}` | Tailscale VPN | `yes`/`no` |
| `{{INSTALL_FIREWALL}}` | nftables | `yes`/`no` |
| `{{FIREWALL_MODE}}` | Firewall mode | `stealth`/`strict`/`standard` |

## Best Practices

1. **Always stage templates** - Don't modify originals in `templates/`
2. **Use deploy_template** - Handles staging, substitution, copy, cleanup
3. **Validate critical vars** - Check required vars before deployment
4. **Log substitution issues** - Watch for warnings in log file
5. **Test templates locally** - Use `sed` to verify substitution works
6. **Keep templates readable** - Add comments for complex configs

---

## Template Variable Reference

Complete mapping of which templates use which variables.

### Templates by Variable Usage

#### Configuration Templates

| Template | Variables Used | Purpose |
|----------|----------------|---------|
| `hosts.tmpl` | `MAIN_IPV4`, `FQDN`, `HOSTNAME` | `/etc/hosts` file |
| `resolv.conf.tmpl` | `DNS_PRIMARY`, `DNS_SECONDARY` | DNS resolver config |
| `sshd_config.tmpl` | `ADMIN_USERNAME` | SSH daemon hardening |
| `postfix-main.cf.tmpl` | `HOSTNAME`, `FQDN`, `DOMAIN_SUFFIX`, `SMTP_RELAY_HOST`, `SMTP_RELAY_PORT` | Mail relay config |
| `promtail.yml.tmpl` | `HOSTNAME` | Log collector config |
| `netdata.conf.tmpl` | `NETDATA_BIND_TO` | Monitoring UI binding |
| `vnstat.conf.tmpl` | `INTERFACE_NAME` | Traffic monitoring |

#### Localization Templates

| Template | Variables Used | Purpose |
|----------|----------------|---------|
| `default-locale.tmpl` | `LOCALE` | System default locale |
| `environment.tmpl` | `LOCALE` | Environment locale |
| `locale.sh.tmpl` | `LOCALE` | Locale profile script |
| `zshrc.tmpl` | `LOCALE` | Zsh locale settings |

#### Systemd Service Templates

| Template | Variables Used | Purpose |
|----------|----------------|---------|
| `cpupower.service.tmpl` | `CPU_GOVERNOR` | CPU scaling service |
| `network-ringbuffer.service.tmpl` | (none) | Network buffer tuning |
| `aide-check.service.tmpl` | (none) | AIDE integrity check |
| `chkrootkit-scan.service.tmpl` | (none) | Rootkit scanner |
| `lynis-audit.service.tmpl` | (none) | Security audit |
| `zfs-scrub.service.tmpl` | (none) | ZFS pool scrub |

#### Script Templates

| Template | Variables Used | Purpose |
|----------|----------------|---------|
| `validation.sh.tmpl` | 18 variables (see below) | Post-install validation |
| `letsencrypt-firstboot.sh.tmpl` | `CERT_DOMAIN`, `CERT_EMAIL` | Let's Encrypt setup |
| `network-ringbuffer.sh.tmpl` | (none) | Network tuning script |
| `remove-subscription-nag.sh.tmpl` | (none) | Remove PVE nag |

#### Templates Without Variables

These use static configuration (39 templates):
- All `.timer.tmpl` files
- `fail2ban-jail.local.tmpl`
- `nftables.conf.tmpl` (generated dynamically)
- Security scan templates
- Various helper scripts

### validation.sh.tmpl Variables

The validation script template uses all feature flags for post-install verification:

```
ADMIN_USERNAME       INSTALL_AIDE         INSTALL_NETDATA
SHELL_TYPE           INSTALL_APPARMOR     INSTALL_NVIM
SSL_TYPE             INSTALL_AUDITD       INSTALL_PROMTAIL
INSTALL_FIREWALL     INSTALL_CHKROOTKIT   INSTALL_RINGBUFFER
FIREWALL_MODE        INSTALL_LYNIS        INSTALL_TAILSCALE
INSTALL_YAZI         INSTALL_NEEDRESTART  INSTALL_VNSTAT
```

### Variables by Category

#### Most Frequently Used

| Variable | Template Count | Templates |
|----------|----------------|-----------|
| `LOCALE` | 4 | default-locale, environment, locale.sh, zshrc |
| `HOSTNAME` | 3 | hosts, postfix-main.cf, promtail.yml |
| `FQDN` | 2 | hosts, postfix-main.cf |

#### Network Variables

| Variable | Template |
|----------|----------|
| `MAIN_IPV4` | hosts.tmpl |
| `INTERFACE_NAME` | vnstat.conf.tmpl |
| `NETDATA_BIND_TO` | netdata.conf.tmpl |

#### DNS Variables

| Variable | Template |
|----------|----------|
| `DNS_PRIMARY` | resolv.conf.tmpl |
| `DNS_SECONDARY` | resolv.conf.tmpl |

#### Email Variables

| Variable | Template |
|----------|----------|
| `SMTP_RELAY_HOST` | postfix-main.cf.tmpl |
| `SMTP_RELAY_PORT` | postfix-main.cf.tmpl |
| `DOMAIN_SUFFIX` | postfix-main.cf.tmpl |

#### SSL Variables

| Variable | Template |
|----------|----------|
| `CERT_DOMAIN` | letsencrypt-firstboot.sh.tmpl |
| `CERT_EMAIL` | letsencrypt-firstboot.sh.tmpl |
| `SSL_TYPE` | validation.sh.tmpl |

#### System Variables

| Variable | Template |
|----------|----------|
| `CPU_GOVERNOR` | cpupower.service.tmpl |
| `ADMIN_USERNAME` | sshd_config.tmpl, validation.sh.tmpl |
| `SHELL_TYPE` | validation.sh.tmpl |

### Summary Statistics

- **Total template files:** 54
- **Templates with variables:** 15
- **Templates without variables:** 39
- **Unique variables:** 32
- **Most variables in one template:** 18 (validation.sh.tmpl)

