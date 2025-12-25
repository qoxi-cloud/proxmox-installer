# shellcheck shell=bash
# =============================================================================
# Initialization - temp files, cleanup, runtime variables
# =============================================================================

# =============================================================================
# Disk configuration
# =============================================================================

# Boot disk selection (empty = all disks in pool)
BOOT_DISK=""

# ZFS pool disks (array of paths like "/dev/nvme0n1")
ZFS_POOL_DISKS=()

# System utilities to install on Proxmox
SYSTEM_UTILITIES="btop iotop ncdu tmux pigz smartmontools jq bat fastfetch sysstat nethogs ethtool curl gnupg"
OPTIONAL_PACKAGES="libguestfs-tools"

# Log file
LOG_FILE="/root/pve-install-$(date +%Y%m%d-%H%M%S).log"

# Track if installation completed successfully
INSTALL_COMPLETED=false

# =============================================================================
# Temp file registry for cleanup on exit
# =============================================================================
# Array to track temp files for cleanup on script exit
_TEMP_FILES=()

# Register a temp file for automatic cleanup on script exit.
# Use this for any mktemp files that may not get cleaned up on early exit/SIGTERM.
# Parameters:
#   $1 - Path to temp file
register_temp_file() {
  _TEMP_FILES+=("$1")
}

# Cleans up temporary files created during installation.
# Removes ISO files, password files, logs, and other temporary artifacts.
# Behavior depends on INSTALL_COMPLETED flag - preserves files if installation succeeded.
# Uses secure deletion for files containing secrets.
cleanup_temp_files() {
  # Clean up registered temp files (from register_temp_file)
  for f in "${_TEMP_FILES[@]}"; do
    [[ -f "$f" ]] && rm -f "$f"
  done

  # Secure delete files containing secrets (API token, root password)
  # secure_delete_file is defined in 012-utils.sh, check if available
  if type secure_delete_file &>/dev/null; then
    secure_delete_file /tmp/pve-install-api-token.env
    secure_delete_file /root/answer.toml
    # Secure delete password files from /dev/shm and /tmp
    # Patterns: pve-ssh-session.* (current), pve-passfile.* (legacy), *passfile* (catch-all)
    while IFS= read -r -d '' pfile; do
      secure_delete_file "$pfile"
    done < <(find /dev/shm /tmp -name "pve-ssh-session.*" -type f -print0 2>/dev/null || true)
    while IFS= read -r -d '' pfile; do
      secure_delete_file "$pfile"
    done < <(find /dev/shm /tmp -name "pve-passfile.*" -type f -print0 2>/dev/null || true)
    while IFS= read -r -d '' pfile; do
      secure_delete_file "$pfile"
    done < <(find /dev/shm /tmp -name "*passfile*" -type f -print0 2>/dev/null || true)
  else
    # Fallback if secure_delete_file not yet loaded (early exit)
    rm -f /tmp/pve-install-api-token.env 2>/dev/null || true
    rm -f /root/answer.toml 2>/dev/null || true
    find /dev/shm /tmp -name "pve-ssh-session.*" -type f -delete 2>/dev/null || true
    find /dev/shm /tmp -name "pve-passfile.*" -type f -delete 2>/dev/null || true
    find /dev/shm /tmp -name "*passfile*" -type f -delete 2>/dev/null || true
  fi

  # Clean up standard temporary files (non-sensitive)
  rm -f /tmp/tailscale_*.txt /tmp/iso_checksum.txt /tmp/*.tmp 2>/dev/null || true

  # Clean up ISO and installation files (only if installation failed)
  if [[ $INSTALL_COMPLETED != "true" ]]; then
    rm -f /root/pve.iso /root/pve-autoinstall.iso /root/SHA256SUMS 2>/dev/null || true
    rm -f /root/qemu_*.log 2>/dev/null || true
  fi
}

# Cleanup handler invoked on script exit via trap.
# Performs graceful shutdown of background processes, drive cleanup, cursor restoration.
# Displays error message if installation failed (INSTALL_COMPLETED != true).
# Returns: Exit code from the script
cleanup_and_error_handler() {
  local exit_code=$?

  # Stop all background jobs
  jobs -p | xargs -r kill 2>/dev/null || true
  sleep "${PROCESS_KILL_WAIT:-1}"

  # Clean up SSH session passfile
  if type _ssh_session_cleanup &>/dev/null; then
    _ssh_session_cleanup
  fi

  # Clean up temporary files
  cleanup_temp_files

  # Release drives if QEMU is still running
  if [[ -n ${QEMU_PID:-} ]] && kill -0 "$QEMU_PID" 2>/dev/null; then
    log "Cleaning up QEMU process $QEMU_PID"
    # Source release_drives if available (may not be sourced yet)
    if type release_drives &>/dev/null; then
      release_drives
    else
      # Fallback cleanup
      pkill -TERM qemu-system-x86 2>/dev/null || true
      sleep "${RETRY_DELAY_SECONDS:-2}"
      pkill -9 qemu-system-x86 2>/dev/null || true
    fi
  fi

  # Exit alternate screen buffer and restore cursor visibility
  tput rmcup 2>/dev/null || true
  tput cnorm 2>/dev/null || true

  # Show error message if installation failed
  if [[ $INSTALL_COMPLETED != "true" && $exit_code -ne 0 ]]; then
    printf '%s\n' "${CLR_RED}*** INSTALLATION FAILED ***${CLR_RESET}"
    printf '\n'
    printf '%s\n' "${CLR_YELLOW}An error occurred and the installation was aborted.${CLR_RESET}"
    printf '\n'
    printf '%s\n' "${CLR_YELLOW}Please check the log file for details:${CLR_RESET}"
    printf '%s\n' "${CLR_YELLOW}  ${LOG_FILE}${CLR_RESET}"
    printf '\n'
  fi
}

trap cleanup_and_error_handler EXIT

# =============================================================================
# Installation state variables
# =============================================================================
# These variables track the installation process and timing.
# Set during early initialization, used throughout the installation.

# Start time for total duration tracking (epoch seconds)
# Set: here on script load, used: metrics_finish() in 005-logging.sh
INSTALL_START_TIME=$(date +%s)

# =============================================================================
# Runtime configuration variables
# =============================================================================
# These variables are populated by:
#   1. CLI arguments (004-cli.sh) - parsed at startup
#   2. System detection (050-059 scripts) - hardware detection
#   3. Wizard UI (100-wizard.sh) - user input
#   4. answer.toml (200-packages.sh) - passed to Proxmox installer
#
# Lifecycle:
#   CLI args → System detection → Wizard UI → answer.toml → Configuration
#
# Empty string = not set, will use default or prompt user

# --- QEMU Settings ---
# Set: CLI args (-r, -c) or auto-detected in 201-qemu.sh
QEMU_RAM_OVERRIDE=""   # Override RAM allocation (MB)
QEMU_CORES_OVERRIDE="" # Override CPU core count

# --- Proxmox Settings ---
# Set: CLI args (-v) or wizard (111-wizard-proxmox.sh)
PROXMOX_ISO_VERSION=""  # ISO version (empty = show menu)
PVE_REPO_TYPE=""        # no-subscription, enterprise, test
PVE_SUBSCRIPTION_KEY="" # Enterprise subscription key

# --- System Settings ---
# Set: Wizard (110-wizard-basic.sh, 114-wizard-services.sh)
SSL_TYPE=""   # self-signed, letsencrypt
SHELL_TYPE="" # zsh, bash

# --- Locale Settings ---
# Set: CLI args or wizard (110-wizard-basic.sh)
# Used: answer.toml generation, system configuration
KEYBOARD="en-us"     # Keyboard layout (see WIZ_KEYBOARD_LAYOUTS)
COUNTRY="us"         # ISO 3166-1 alpha-2 country code
LOCALE="en_US.UTF-8" # System locale (derived from country)
TIMEZONE="UTC"       # System timezone

# --- Performance Settings ---
# Set: Wizard (114-wizard-services.sh)
CPU_GOVERNOR="" # CPU frequency governor (performance, powersave, etc.)
ZFS_ARC_MODE="" # ZFS ARC strategy: vm-focused, balanced, storage-focused

# --- Security Features ---
# Set: Wizard (114-wizard-services.sh), default: "no"
# Used: batch_install_packages(), parallel config groups
INSTALL_AUDITD=""      # Kernel audit logging
INSTALL_AIDE=""        # File integrity monitoring (daily checks)
INSTALL_APPARMOR=""    # Mandatory access control
INSTALL_CHKROOTKIT=""  # Rootkit detection (weekly scans)
INSTALL_LYNIS=""       # Security auditing tool
INSTALL_NEEDRESTART="" # Auto-restart services after updates

# --- Monitoring Features ---
# Set: Wizard (114-wizard-services.sh), default: "no" except VNSTAT
INSTALL_NETDATA=""    # Real-time web dashboard (port 19999)
INSTALL_VNSTAT=""     # Bandwidth monitoring (default: yes)
INSTALL_PROMTAIL=""   # Log collector for Loki
INSTALL_RINGBUFFER="" # Network ring buffer tuning for high throughput

# --- Optional Tools ---
# Set: Wizard (114-wizard-services.sh), default: "no"
INSTALL_YAZI="" # Terminal file manager
INSTALL_NVIM="" # Neovim editor with config

# --- System Maintenance ---
# Set: Wizard (114-wizard-services.sh), default: "yes"
INSTALL_UNATTENDED_UPGRADES="" # Automatic security updates

# --- Tailscale VPN ---
# Set: Wizard (114-wizard-services.sh)
INSTALL_TAILSCALE=""  # Enable Tailscale VPN
TAILSCALE_AUTH_KEY="" # Pre-auth key for automatic login
TAILSCALE_WEBUI=""    # Expose Proxmox UI via Tailscale Serve (yes/no)

# --- Network Settings ---
# Set: Wizard (112-wizard-network.sh)
BRIDGE_MTU="" # Bridge MTU: 9000 (jumbo) or 1500 (standard)

# --- API Token ---
# Set: Wizard (114-wizard-services.sh)
# Used: create_api_token() in 361-configure-api-token.sh
INSTALL_API_TOKEN=""        # Create automation API token
API_TOKEN_NAME="automation" # Token name (default: automation)
API_TOKEN_VALUE=""          # Generated token value (set post-install)
API_TOKEN_ID=""             # Full token ID (user@pam!tokenname)

# --- Proxmox Root Password ---
# Set: Wizard (110-wizard-basic.sh)
# Used: SSH passfile for QEMU VM access, answer.toml for Proxmox installer
NEW_ROOT_PASSWORD="" # Proxmox root password (required, auto-generated if empty)

# --- Admin User ---
# Set: Wizard (115-wizard-ssh.sh)
# Used: 302-configure-admin.sh, sshd_config, API token
# Note: Root SSH is disabled, all access via admin user
ADMIN_USERNAME="" # Non-root admin username (required)
ADMIN_PASSWORD="" # Admin password for sudo/Proxmox UI (required)

# --- Firewall (nftables) ---
# Set: Wizard (114-wizard-services.sh)
# Modes:
#   stealth  - Blocks ALL incoming except Tailscale/bridges
#   strict   - SSH only (port 22)
#   standard - SSH + Proxmox Web UI (ports 22, 8006)
INSTALL_FIREWALL="" # Enable nftables firewall (yes/no)
FIREWALL_MODE=""    # stealth, strict, standard
