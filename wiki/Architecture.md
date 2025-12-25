# Project Architecture

## Overview

This project is a bash automation framework that installs Proxmox VE on dedicated servers without console access. It runs a local QEMU VM with the Proxmox ISO, configures it via an interactive wizard, then deploys the configuration to the target system over SSH.

## High-Level Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Local Host    │     │    QEMU VM      │     │  Target Server  │
│                 │     │  (Proxmox ISO)  │     │   (Proxmox)     │
│  ┌───────────┐  │     │                 │     │                 │
│  │  Wizard   │──┼────►│  Installation   │────►│  Configuration  │
│  │   (TUI)   │  │ SSH │                 │     │                 │
│  └───────────┘  │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

**Execution Stages:**

1. **Initialization** (000-009) - Load colors, parse CLI args, setup logging
2. **System Check** (040-049) - Verify requirements (root, RAM, disk, KVM)
3. **Wizard** (100-119) - Interactive configuration via TUI
4. **QEMU Setup** (200-209) - Download ISO, launch VM, wait for SSH
5. **Installation** (200-209) - Proxmox auto-install via templates
6. **Configuration** (300-380) - Deploy configs, install packages, harden
7. **Finalization** (380-389) - Validate, show credentials, shutdown VM

## Component Architecture

```
scripts/
├── 000-009: Core Infrastructure
│   ├── 000-init.sh      # Globals, colors, constants, cleanup trap
│   ├── 001-cli.sh       # CLI argument parsing
│   ├── 002-logging.sh   # Log functions, metrics
│   └── 003-banner.sh    # ASCII art banner
│
├── 010-049: Utilities Layer
│   ├── 010-display.sh   # print_* functions, progress indicator
│   ├── 011-downloads.sh # File download with retry
│   ├── 012-utils.sh     # Secure file deletion
│   ├── 020-templates.sh # Template variable substitution
│   ├── 021-ssh.sh       # SSH session management, remote_*
│   ├── 034-password-utils.sh     # Password generation
│   ├── 035-zfs-helpers.sh        # ZFS RAID mapping
│   ├── 036-validation-helpers.sh # Validation UI helpers
│   ├── 037-parallel-helpers.sh   # Parallel execution
│   ├── 038-deploy-helpers.sh     # Deployment helpers
│   ├── 039-network-helpers.sh    # Network detection utilities
│   ├── 040-validation.sh         # Input validators
│   ├── 041-system-check.sh       # Requirements validation
│   └── 042-live-logs.sh          # Live log display
│
├── 100-119: Wizard Layer
│   ├── 100-wizard-core.sh    # Main wizard loop
│   ├── 101-wizard-ui.sh      # UI rendering, gum wrappers
│   ├── 102-wizard-nav.sh     # Navigation logic (screen switching)
│   ├── 103-wizard-menu.sh    # Menu building and field mapping
│   ├── 110-wizard-basic.sh   # Hostname, email, password, timezone
│   ├── 111-wizard-proxmox.sh # ISO version, repo type
│   ├── 112-wizard-network.sh # Interface, bridge, IPv4/IPv6
│   ├── 113-wizard-storage.sh # Boot disk, pool disks, ZFS mode
│   ├── 114-wizard-services.sh# Features, Tailscale, SSL
│   ├── 115-wizard-access.sh  # Admin user, SSH key
│   └── 116-wizard-disks.sh   # Disk detection
│
├── 200-209: Installation Layer
│   ├── 200-packages.sh    # Repo setup, package installation
│   ├── 201-qemu.sh        # QEMU launch, options detection
│   ├── 202-templates.sh   # Template deployment
│   ├── 203-iso-download.sh# ISO version detection, download
│   └── 204-autoinstall.sh # Proxmox auto-install answer file
│
├── 300-389: Configuration Layer
│   ├── 300-configure-base.sh      # Base system config
│   ├── 301-configure-tailscale.sh # VPN setup
│   ├── 302-configure-admin.sh     # Admin user creation
│   ├── 310-configure-firewall.sh  # nftables rules
│   ├── 311-configure-fail2ban.sh  # Intrusion prevention
│   ├── 312-configure-apparmor.sh  # MAC enforcement
│   ├── 320-configure-auditd.sh    # Kernel audit
│   ├── 321-configure-aide.sh      # File integrity
│   ├── 322-configure-chkrootkit.sh# Rootkit scanner
│   ├── 323-configure-lynis.sh     # Security audit
│   ├── 324-configure-needrestart.sh # Service restart checker
│   ├── 330-configure-ringbuffer.sh  # Network tuning
│   ├── 340-configure-vnstat.sh    # Bandwidth monitoring
│   ├── 341-configure-promtail.sh  # Log collector
│   ├── 342-configure-netdata.sh   # Real-time monitoring
│   ├── 350-configure-yazi.sh      # File manager
│   ├── 351-configure-nvim.sh      # Editor
│   ├── 360-configure-ssl.sh       # Certificates
│   ├── 361-configure-api-token.sh # Proxmox API
│   ├── 370-configure-zfs.sh       # ZFS ARC tuning
│   ├── 371-configure-zfs-pool.sh  # Pool creation
│   └── 380-configure-finalize.sh  # Validation, completion
│
└── 900-999: Orchestration
    └── 900-main.sh  # Main entry point
```

## Data Flow

### Configuration State

All configuration stored in global variables (defined in `000-init.sh`):

```
User Input (Wizard) → Global Variables → Template Substitution → Remote Files
```

**Key variable categories:**

- `PVE_*` - Proxmox settings (hostname, repo, ISO)
- `MAIN_IPV4/6*` - Network configuration
- `ZFS_*` - Storage settings
- `INSTALL_*` - Feature flags (yes/no)
- `ADMIN_*` - User credentials

### Template Pipeline

```
templates/*.tmpl → apply_template_vars() → /tmp/staged → remote_copy() → /target/path
```

Template variables use `{{VARIABLE}}` syntax. Special characters auto-escaped.

### SSH Communication

```
┌─────────────┐    sshpass + SSH    ┌─────────────┐
│ Local Host  │◄──────────────────►│   QEMU VM   │
│             │    Port 5555        │  (Proxmox)  │
└─────────────┘                     └─────────────┘

Session Management:
- _ssh_session_init()    → Create passfile once
- remote_exec()          → Low-level command
- remote_run()           → High-level with progress
- remote_copy()          → File transfer
- _ssh_session_cleanup() → Secure passfile deletion
```

### Parallel Execution

```
run_parallel_group "label" "done_msg" func1 func2 func3
         │
         ├── func1 ──► $result_dir/success_0 or fail_0
         ├── func2 ──► $result_dir/success_1 or fail_1
         └── func3 ──► $result_dir/success_2 or fail_2
                              │
                    ◄─────────┘
              Collect results, show single progress
```

## Wizard Architecture

### Screen Navigation

```
┌─────────────────────────────────────────────────────────────┐
│  ○ Basic   ○ Proxmox   ● Network   ○ Storage   ○ Services  │
│  ━━━━━━━━━━━━━━━━━━━━━━━◉━━━━━━━━━━━─────────────────────── │
└─────────────────────────────────────────────────────────────┘

Navigation:
- ←/→  Switch screens
- ↑/↓  Move within screen
- Enter  Edit field
- S  Start installation
- Q  Quit
```

### Component Breakdown

The wizard is split into modular components:

- **100-wizard-core.sh** - Main loop, event handling
- **101-wizard-ui.sh** - Gum wrappers, field rendering
- **102-wizard-nav.sh** - Screen switching, navigation state
- **103-wizard-menu.sh** - Menu building, field mapping

### Field Mapping

```bash
WIZ_SCREENS=("Basic" "Proxmox" "Network" "Storage" "Services" "Access")

# Each screen populates _WIZ_FIELD_MAP:
_WIZ_FIELD_MAP[0]="hostname"
_WIZ_FIELD_MAP[1]="domain"
# ...

# Selection triggers editor:
field="${_WIZ_FIELD_MAP[$selection]}"
"_edit_${field}"  # Calls _edit_hostname, _edit_domain, etc.
```

## Installation Flow

### ISO Download (203-iso-download.sh)

```
1. Fetch available versions from Proxmox downloads
2. Parse version list (PVE_AVAILABLE_VERSIONS array)
3. Select version via wizard or CLI
4. Download ISO with retry logic
5. Verify checksum
```

### Auto-Install (204-autoinstall.sh)

```
1. Generate answer file from wizard config
2. Deploy to ISO via QEMU
3. Wait for installation completion
4. Reboot into installed system
```

## Feature Configuration Pattern

Each optional feature follows consistent pattern:

```bash
# 1. Feature flag (set in wizard)
INSTALL_FEATURE="yes"

# 2. Parallel wrapper (checks flag)
_parallel_config_feature() {
  [[ $INSTALL_FEATURE != "yes" ]] && return 0
  _config_feature
}

# 3. Config function (does actual work)
_config_feature() {
  deploy_template "feature.conf.tmpl" "/etc/feature/config"
  deploy_systemd_timer "feature"
  remote_run "Enable feature" 'systemctl enable --now feature'
}

# 4. Templates
templates/feature.conf.tmpl
templates/feature.service.tmpl
templates/feature.timer.tmpl
```

## Error Handling Strategy

No `set -e` - all error handling explicit:

```bash
# Pattern 1: Fail fast
command || { log "ERROR: Failed"; return 1; }

# Pattern 2: Warn and continue
command || log "WARNING: Non-critical failure"

# Pattern 3: Cleanup on exit
trap '_cleanup_handler' EXIT

_cleanup_handler() {
  [[ $BASHPID != "$$" ]] && return  # Only main shell
  secure_delete_file "$passfile"
  [[ $QEMU_PID ]] && kill "$QEMU_PID" 2>/dev/null
}
```

## Testing Strategy

```bash
# Run in Docker (not macOS - bash 3.2 incompatible)
docker run --rm -v "$(pwd):/app" -w /app ubuntu:22.04 bash -c '
  apt-get update -qq && apt-get install -y -qq curl git >/dev/null 2>&1
  curl -fsSL https://git.io/shellspec | sh -s -- --yes >/dev/null 2>&1
  ~/.local/lib/shellspec/shellspec --format documentation
'
```

**Test organization:**

```
spec/
├── unit/
│   ├── 002_logging_spec.sh
│   ├── 010_display_spec.sh
│   ├── 040_validation_spec.sh
│   └── ...
└── support/
    └── mocks, fixtures
```

## Security Considerations

- **Passfile management**: Created once, reused, securely deleted on exit
- **Password generation**: `/dev/urandom` with alphanumeric + special chars
- **Template escaping**: Special chars auto-escaped before substitution
- **Input validation**: All user inputs validated before use
- **Credential display**: Only shown on completion screen, not logged
- **Cleanup trap**: Ensures sensitive files deleted on any exit

## File Number Ranges

| Range     | Purpose                                      |
|-----------|----------------------------------------------|
| 000-009   | Initialization (init, cli, logging, banner)  |
| 010-019   | Display & downloads                          |
| 020-029   | Templates & SSH                              |
| 030-039   | Helpers (password, zfs, validation, etc.)    |
| 040-049   | Validation & system checks                   |
| 100-109   | Wizard core (main logic, UI, nav, menu)      |
| 110-119   | Wizard editors (screens)                     |
| 200-209   | Installation (packages, QEMU, ISO, templates)|
| 300-309   | Base configuration                           |
| 310-319   | Security - Firewall & access control         |
| 320-329   | Security - Auditing & integrity              |
| 330-339   | Network & performance                        |
| 340-349   | Monitoring                                   |
| 350-359   | Tools                                        |
| 360-369   | SSL & API                                    |
| 370-379   | Storage (ZFS)                                |
| 380-389   | Finalization                                 |
| 900-999   | Main orchestrator                            |

