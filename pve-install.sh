#!/usr/bin/env bash
# Qoxi - Proxmox VE Automated Installer for Dedicated Servers
# Note: NOT using set -e because it interferes with trap EXIT handler
# All error handling is done explicitly with exit 1
cd /root || exit 1

# Ensure UTF-8 locale for proper Unicode display
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Colors for terminal output
readonly CLR_RED=$'\033[1;31m'
readonly CLR_CYAN=$'\033[38;2;0;177;255m'
readonly CLR_YELLOW=$'\033[1;33m'
readonly CLR_ORANGE=$'\033[38;5;208m'
readonly CLR_GRAY=$'\033[38;5;240m'
readonly CLR_GOLD=$'\033[38;5;179m'
readonly CLR_RESET=$'\033[m'

# Tree characters for live logs
readonly TREE_BRANCH="${CLR_ORANGE}├─${CLR_RESET}"
readonly TREE_VERT="${CLR_ORANGE}│${CLR_RESET}"
readonly TREE_END="${CLR_ORANGE}└─${CLR_RESET}"

# Hex colors for gum (terminal UI toolkit)
readonly HEX_RED="#ff0000"
readonly HEX_CYAN="#00b1ff"
readonly HEX_YELLOW="#ffff00"
readonly HEX_ORANGE="#ff8700"
readonly HEX_GRAY="#585858"
readonly HEX_WHITE="#ffffff"
readonly HEX_NONE="7"

# Version (MAJOR only - MINOR.PATCH added by CI from git tags/commits)
readonly VERSION="2.1.3"

# Terminal width for centering (wizard UI, headers, etc.)
readonly TERM_WIDTH=80

# Banner dimensions
readonly BANNER_WIDTH=51
# shellcheck shell=bash
# Configuration constants

# GitHub repository for template downloads (can be overridden via environment)
GITHUB_REPO="${GITHUB_REPO:-qoxi-cloud/proxmox-installer}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
GITHUB_BASE_URL="https://github.com/${GITHUB_REPO}/raw/refs/heads/${GITHUB_BRANCH}"

# Proxmox ISO download URLs
readonly PROXMOX_ISO_BASE_URL="https://enterprise.proxmox.com/iso/"
readonly PROXMOX_CHECKSUM_URL="https://enterprise.proxmox.com/iso/SHA256SUMS"

# DNS servers for connectivity checks and resolution (IPv4)
readonly DNS_SERVERS=("1.1.1.1" "8.8.8.8" "9.9.9.9")
readonly DNS_PRIMARY="1.1.1.1"
readonly DNS_SECONDARY="1.0.0.1"

# DNS servers (IPv6) - Cloudflare
readonly DNS6_PRIMARY="2606:4700:4700::1111"
readonly DNS6_SECONDARY="2606:4700:4700::1001"

# Default IPv6 gateway (standard link-local address)
readonly DEFAULT_IPV6_GATEWAY="fe80::1"

# Resource requirements (ISO ~3.5GB + QEMU + overhead = 6GB)
readonly MIN_DISK_SPACE_MB=6000
readonly MIN_RAM_MB=4000
readonly MIN_CPU_CORES=2

# QEMU defaults
readonly MIN_QEMU_RAM=4096

# Download settings
readonly DOWNLOAD_RETRY_COUNT=3
readonly DOWNLOAD_RETRY_DELAY=2

# SSH settings
readonly SSH_CONNECT_TIMEOUT=10

# Ports configuration
readonly SSH_PORT_QEMU=5555  # SSH port for QEMU VM (installer-internal)
readonly PORT_SSH=22         # Standard SSH port for firewall rules
readonly PORT_PROXMOX_UI=443 # Proxmox Web UI port (standard HTTPS)

# Password settings
readonly DEFAULT_PASSWORD_LENGTH=16

# QEMU memory settings
readonly QEMU_MIN_RAM_RESERVE=2048

# DNS lookup timeout (seconds)
readonly DNS_LOOKUP_TIMEOUT=5

# Retry delays (seconds)
readonly DNS_RETRY_DELAY=10

# QEMU timeouts (seconds)
readonly QEMU_INSTALL_TIMEOUT=300   # Max wait for Proxmox installation (5 min)
readonly QEMU_BOOT_TIMEOUT=300      # Max wait for QEMU to boot and expose SSH port
readonly QEMU_PORT_CHECK_INTERVAL=3 # Interval between port availability checks
readonly QEMU_SSH_READY_TIMEOUT=120 # Max wait for SSH to be fully ready

# ZFS storage defaults
readonly DEFAULT_ZFS_POOL_NAME="local-zfs"

# Retry and timing constants
readonly RETRY_DELAY_SECONDS=2      # Standard retry delay for recoverable operations
readonly SSH_RETRY_ATTEMPTS=3       # Number of SSH connection retries
readonly PROGRESS_POLL_INTERVAL=0.2 # Polling interval for progress indicators
readonly PROCESS_KILL_WAIT=1        # Wait time after sending SIGTERM before SIGKILL
readonly VM_SHUTDOWN_TIMEOUT=120    # Max wait for VM to shutdown gracefully
readonly WIZARD_MESSAGE_DELAY=3     # Display duration for wizard notifications
readonly PARALLEL_MAX_JOBS=8        # Max concurrent background jobs in parallel groups

# Keyboard layouts supported by Proxmox installer (from official documentation)
# shellcheck disable=SC2034
readonly WIZ_KEYBOARD_LAYOUTS="de
de-ch
dk
en-gb
en-us
es
fi
fr
fr-be
fr-ca
fr-ch
hu
is
it
jp
lt
mk
nl
no
pl
pt
pt-br
se
si
tr"
# shellcheck shell=bash
# Wizard menu option lists (WIZ_ prefix to avoid conflicts)

# IPv6 configuration modes
# shellcheck disable=SC2034
readonly WIZ_IPV6_MODES="Auto
Manual
Disabled"

# Private subnet presets
# shellcheck disable=SC2034
readonly WIZ_PRIVATE_SUBNETS="10.0.0.0/24
192.168.1.0/24
172.16.0.0/24
Custom"

# Firewall modes (nftables)
# shellcheck disable=SC2034
readonly WIZ_FIREWALL_MODES="Stealth (Tailscale only)
Strict (SSH only)
Standard (SSH + Web UI)
Disabled"

# Password entry options
# shellcheck disable=SC2034
readonly WIZ_PASSWORD_OPTIONS="Manual entry
Generate password"

# SSH key options (when key detected)
# shellcheck disable=SC2034
readonly WIZ_SSH_KEY_OPTIONS="Use detected key
Enter different key"

# Feature toggles - Security
# shellcheck disable=SC2034
readonly WIZ_FEATURES_SECURITY="apparmor
auditd
aide
chkrootkit
lynis
needrestart"

# Feature toggles - Monitoring
# shellcheck disable=SC2034
readonly WIZ_FEATURES_MONITORING="vnstat
netdata
promtail"

# Feature toggles - Tools
# shellcheck disable=SC2034
readonly WIZ_FEATURES_TOOLS="yazi
nvim
ringbuffer"

# Display → Internal value mappings for _wiz_choose_mapped
# Format: "Display text:internal_value"

# Bridge mode mapping
# shellcheck disable=SC2034
readonly WIZ_MAP_BRIDGE_MODE=(
  "Internal NAT:internal"
  "External bridge:external"
  "Both:both"
)

# Bridge MTU mapping
# shellcheck disable=SC2034
readonly WIZ_MAP_BRIDGE_MTU=(
  "9000 (jumbo frames):9000"
  "1500 (standard):1500"
)

# Shell type mapping
# shellcheck disable=SC2034
readonly WIZ_MAP_SHELL=(
  "ZSH:zsh"
  "Bash:bash"
)

# ZFS ARC mode mapping
# shellcheck disable=SC2034
readonly WIZ_MAP_ZFS_ARC=(
  "VM-focused (4GB fixed):vm-focused"
  "Balanced (25-40% of RAM):balanced"
  "Storage-focused (50% of RAM):storage-focused"
)

# Repository type mapping
# shellcheck disable=SC2034
readonly WIZ_MAP_REPO_TYPE=(
  "No-subscription (free):no-subscription"
  "Enterprise:enterprise"
  "Test/Development:test"
)

# SSL type mapping
# shellcheck disable=SC2034
readonly WIZ_MAP_SSL_TYPE=(
  "Self-signed:self-signed"
  "Let's Encrypt:letsencrypt"
)

# Disk wipe mapping
# shellcheck disable=SC2034
readonly WIZ_MAP_WIPE_DISKS=(
  "Yes - Full wipe (recommended):yes"
  "No - Keep existing:no"
)
# shellcheck shell=bash
# Initialization - disk config, log file, runtime variables

# Installation directory (rescue system home, can be overridden)
INSTALL_DIR="${INSTALL_DIR:-${HOME:-/root}}"

# Disk configuration

# Boot disk selection (empty = all disks in pool)
BOOT_DISK=""

# ZFS pool disks (array of paths like "/dev/nvme0n1")
ZFS_POOL_DISKS=()

# Use existing ZFS pool instead of creating new one
# When "yes": import existing pool, preserve all data
# When empty/"no": create new pool (default behavior)
USE_EXISTING_POOL=""
EXISTING_POOL_NAME=""  # Pool name to import (e.g., "tank", "rpool", "data")
EXISTING_POOL_DISKS=() # Disks containing the existing pool (detected or manual)

# Wipe disks before installation (removes old partitions, LVM, ZFS, mdadm)
# When "yes": fully wipe selected disks like fresh from factory
# When "no": only release locks (existing behavior)
WIPE_DISKS="yes"

# System utilities to install on Proxmox
SYSTEM_UTILITIES="sudo btop iotop ncdu tmux pigz smartmontools jq bat fastfetch sysstat nethogs ethtool curl gnupg"
OPTIONAL_PACKAGES="libguestfs-tools"

# Log file
LOG_FILE="${INSTALL_DIR}/pve-install-$(date +%Y%m%d-%H%M%S).log"

# Track if installation completed successfully
INSTALL_COMPLETED=false

# Installation state variables
# These variables track the installation process and timing.
# Set during early initialization, used throughout the installation.

# Start time for total duration tracking (epoch seconds)
# Set: here on script load, used: metrics_finish() in 005-logging.sh
INSTALL_START_TIME=$(date +%s)

# Runtime configuration variables
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

# --- Tailscale VPN ---
# Set: Wizard (114-wizard-services.sh)
INSTALL_TAILSCALE=""  # Enable Tailscale VPN
TAILSCALE_AUTH_KEY="" # Pre-auth key for automatic login
TAILSCALE_WEBUI=""    # Expose Proxmox UI via Tailscale Serve (yes/no)

# --- Postfix Mail ---
# Set: Wizard (121-wizard-features.sh)
INSTALL_POSTFIX=""     # Enable Postfix mail relay (yes/no)
SMTP_RELAY_HOST=""     # SMTP relay server (e.g., smtp.gmail.com)
SMTP_RELAY_PORT=""     # SMTP relay port (default: 587)
SMTP_RELAY_USER=""     # SMTP authentication username
SMTP_RELAY_PASSWORD="" # SMTP authentication password

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
#   standard - SSH + Proxmox Web UI (ports 22, 443)
INSTALL_FIREWALL="" # Enable nftables firewall (yes/no)
FIREWALL_MODE=""    # stealth, strict, standard

# --- Temp File Paths ---
# Centralized temp file path constants (PID-scoped for session isolation)
# All paths use $$ to ensure subshells share parent session's files
# Files are registered with register_temp_file() at creation time
#
# Pattern: Use _TEMP_* for internal paths, register at creation
#   _TEMP_API_TOKEN_FILE - API token credentials (secure delete)
#   _TEMP_SSH_CONTROL_PATH - SSH ControlMaster socket
#   _TEMP_SCP_LOCK_FILE - SCP serialization lock
#   _TEMP_SSH_PASSFILE_DIR - SSH password file directory (/dev/shm or /tmp)
#
# Note: SSH passfile uses dynamic path via _ssh_passfile_path() in 021-ssh.sh

_TEMP_API_TOKEN_FILE="/tmp/pve-install-api-token.$$.env"
_TEMP_SSH_CONTROL_PATH="/tmp/ssh-pve-control.$$"
_TEMP_SCP_LOCK_FILE="/tmp/pve-scp-lock.$$"
# shellcheck shell=bash
# Cleanup and error handling

# Temp file registry for cleanup on exit
# Array to track temp files for cleanup on script exit
_TEMP_FILES=()

# Register temp file for cleanup on exit. $1=path
register_temp_file() {
  _TEMP_FILES+=("$1")
}

# Clean up temp files, secure delete secrets
cleanup_temp_files() {
  # Use INSTALL_DIR with fallback for early cleanup calls
  local install_dir="${INSTALL_DIR:-${HOME:-/root}}"

  # Secure delete files containing secrets (API token, root password)
  # These are handled specially before registered files to ensure secure deletion
  # secure_delete_file is defined in 012-utils.sh, check if available
  if type secure_delete_file &>/dev/null; then
    # API token file (uses centralized constant from 003-init.sh)
    [[ -n "${_TEMP_API_TOKEN_FILE:-}" ]] && secure_delete_file "$_TEMP_API_TOKEN_FILE"
    secure_delete_file "${install_dir}/answer.toml"
  else
    # Fallback if secure_delete_file not yet loaded (early exit)
    if [[ -n "${_TEMP_API_TOKEN_FILE:-}" ]]; then
      rm -f "$_TEMP_API_TOKEN_FILE" 2>/dev/null || true
    fi
    rm -f "${install_dir}/answer.toml" 2>/dev/null || true
  fi

  # Clean up registered temp files (from register_temp_file)
  # This handles: SSH passfile, SSH control socket, SCP lock file, mktemp files, and temp directories
  for f in "${_TEMP_FILES[@]}"; do
    if [[ -d "$f" ]]; then
      # Handle temp directories (e.g., parallel group result dirs)
      rm -rf "$f" 2>/dev/null || true
    elif [[ -f "$f" ]] || [[ -S "$f" ]]; then
      # Use secure delete for passfile (contains password)
      if [[ "$f" == *"pve-ssh-session"* ]] && type secure_delete_file &>/dev/null; then
        secure_delete_file "$f"
      else
        rm -f "$f" 2>/dev/null || true
      fi
    fi
  done

  # Clean up ISO and installation files (only if installation failed)
  if [[ $INSTALL_COMPLETED != "true" ]]; then
    rm -f "${install_dir}/pve.iso" "${install_dir}/pve-autoinstall.iso" "${install_dir}/SHA256SUMS" 2>/dev/null || true
    rm -f "${install_dir}"/qemu_*.log 2>/dev/null || true
  fi
}

# EXIT trap: cleanup processes, drives, cursor, show error if failed
cleanup_and_error_handler() {
  local exit_code="$?"

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
    log_info "Cleaning up QEMU process $QEMU_PID"
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

# Pre-register SCP lock file for cleanup (must happen before any parallel execution)
# remote_copy() creates this file via flock redirection, but is often called from
# parallel subshells where $BASHPID != $$ prevents runtime registration
register_temp_file "$_TEMP_SCP_LOCK_FILE"
# shellcheck shell=bash
# Command line argument parsing

# Displays command-line help message with usage, options, and examples.
# Prints to stdout and returns 0.
show_help() {
  cat <<EOF
Qoxi Automated Installer v${VERSION}

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  --qemu-ram MB           Set QEMU RAM in MB (default: auto, 4096-8192)
  --qemu-cores N          Set QEMU CPU cores (default: auto, max 16)
  --iso-version FILE      Use specific Proxmox ISO (e.g., proxmox-ve_8.3-1.iso)
  -v, --version           Show version

Examples:
  $0                           # Interactive installation
  $0 --qemu-ram 16384 --qemu-cores 8  # Custom QEMU resources
  $0 --iso-version proxmox-ve_8.2-1.iso  # Use specific Proxmox version

EOF
}

# Parse CLI args. $@=args. Returns: 0=ok, 1=error, 2=help/version
parse_cli_args() {
  # Reset variables for clean parsing
  declare -g QEMU_RAM_OVERRIDE=""
  declare -g QEMU_CORES_OVERRIDE=""
  declare -g PROXMOX_ISO_VERSION=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      -h | --help)
        show_help
        return 2
        ;;
      -v | --version)
        printf '%s\n' "Proxmox Installer v${VERSION}"
        return 2
        ;;
      --qemu-ram)
        if [[ -z ${2:-} || ${2:-} =~ ^-- ]]; then
          printf '%s\n' "${CLR_RED}Error: --qemu-ram requires a value in MB${CLR_RESET}"
          return 1
        fi
        if ! [[ $2 =~ ^[0-9]{1,6}$ ]] || [[ $2 -lt 2048 ]]; then
          printf '%s\n' "${CLR_RED}Error: --qemu-ram must be a number >= 2048 MB${CLR_RESET}"
          return 1
        fi
        if [[ $2 -gt 131072 ]]; then
          printf '%s\n' "${CLR_RED}Error: --qemu-ram must be <= 131072 MB (128 GB)${CLR_RESET}"
          return 1
        fi
        declare -g QEMU_RAM_OVERRIDE="$2"
        shift 2
        ;;
      --qemu-cores)
        if [[ -z ${2:-} || ${2:-} =~ ^-- ]]; then
          printf '%s\n' "${CLR_RED}Error: --qemu-cores requires a value${CLR_RESET}"
          return 1
        fi
        if ! [[ $2 =~ ^[0-9]{1,3}$ ]] || [[ $2 -lt 1 ]]; then
          printf '%s\n' "${CLR_RED}Error: --qemu-cores must be a positive number${CLR_RESET}"
          return 1
        fi
        if [[ $2 -gt 256 ]]; then
          printf '%s\n' "${CLR_RED}Error: --qemu-cores must be <= 256${CLR_RESET}"
          return 1
        fi
        declare -g QEMU_CORES_OVERRIDE="$2"
        shift 2
        ;;
      --iso-version)
        if [[ -z ${2:-} || ${2:-} =~ ^-- ]]; then
          printf '%s\n' "${CLR_RED}Error: --iso-version requires a filename${CLR_RESET}"
          return 1
        fi
        if ! [[ $2 =~ ^proxmox-ve_[0-9]+\.[0-9]+-[0-9]+\.iso$ ]]; then
          printf '%s\n' "${CLR_RED}Error: --iso-version must be in format: proxmox-ve_X.Y-Z.iso${CLR_RESET}"
          return 1
        fi
        declare -g PROXMOX_ISO_VERSION="$2"
        shift 2
        ;;
      *)
        printf '%s\n' "Unknown option: $1"
        printf '%s\n' "Use --help for usage information"
        return 1
        ;;
    esac
  done
  return 0
}

# Parse CLI args at source time (main script execution)
# Return code 2 means help/version was shown - exit cleanly
# shellcheck disable=SC2317
if [[ ${BASH_SOURCE[0]} == "$0" ]] || [[ ${_CLI_PARSE_ON_SOURCE:-true} == "true" ]]; then
  parse_cli_args "$@"
  _cli_ret="$?"
  if [[ $_cli_ret -eq 2 ]]; then
    exit 0
  elif [[ $_cli_ret -ne 0 ]]; then
    exit 1
  fi
fi
# shellcheck shell=bash
# Logging setup

# Log message to file with timestamp. $*=message
log() {
  printf '%s\n' "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$LOG_FILE"
}

# Log info message. $*=message
log_info() {
  log "INFO: $*"
}

# Log error message. $*=message
log_error() {
  log "ERROR: $*"
}

# Log warning message. $*=message
log_warn() {
  log "WARNING: $*"
}

# Log debug message. $*=message
log_debug() {
  log "DEBUG: $*"
}

# Installation Metrics

# Start installation metrics timer. Sets INSTALL_START_TIME.
metrics_start() {
  declare -g INSTALL_START_TIME="$(date +%s)"
  log "METRIC: installation_started"
}

# Log metric with elapsed time. $1=step_name
log_metric() {
  local step="$1"
  if [[ -n $INSTALL_START_TIME ]]; then
    local elapsed="$(($(date +%s) - INSTALL_START_TIME))"
    log "METRIC: ${step}_completed elapsed=${elapsed}s"
  fi
}

# Log final installation metrics summary
metrics_finish() {
  if [[ -n $INSTALL_START_TIME ]]; then
    local total="$(($(date +%s) - INSTALL_START_TIME))"
    local minutes="$((total / 60))"
    local seconds="$((total % 60))"
    log "METRIC: installation_completed total_time=${total}s (${minutes}m ${seconds}s)"
  fi
}
# shellcheck shell=bash
# Banner display
# Note: cursor cleanup is handled by cleanup_and_error_handler in 00-init.sh

# Banner letter count for animation (P=0, r=1, o=2, x=3, m=4, o=5, x=6)
BANNER_LETTER_COUNT=7

# Banner height in lines (6 ASCII art + 1 empty + 1 tagline = 8, +1 for spacing = 9)
BANNER_HEIGHT=9

# Calculate banner padding from TERM_WIDTH and BANNER_WIDTH constants
_BANNER_PAD_SIZE=$(((TERM_WIDTH - BANNER_WIDTH) / 2))
printf -v _BANNER_PAD '%*s' "$_BANNER_PAD_SIZE" ''

# Display main ASCII banner
show_banner() {
  local p="$_BANNER_PAD"
  local tagline="${CLR_CYAN}Qoxi ${CLR_GRAY}Automated Installer ${CLR_GOLD}${VERSION}${CLR_RESET}"
  # Center the tagline within banner width
  local text="Qoxi Automated Installer ${VERSION}"
  local pad="$(((BANNER_WIDTH - ${#text}) / 2))"
  local spaces
  printf -v spaces '%*s' "$pad" ''
  printf '%s\n' \
    "${p}${CLR_GRAY} _____                                             ${CLR_RESET}" \
    "${p}${CLR_GRAY}|  __ \\                                            ${CLR_RESET}" \
    "${p}${CLR_GRAY}| |__) | _ __   ___  ${CLR_ORANGE}__  __${CLR_GRAY}  _ __ ___    ___  ${CLR_ORANGE}__  __${CLR_RESET}" \
    "${p}${CLR_GRAY}|  ___/ | '__| / _ \\ ${CLR_ORANGE}\\ \\/ /${CLR_GRAY} | '_ \` _ \\  / _ \\ ${CLR_ORANGE}\\ \\/ /${CLR_RESET}" \
    "${p}${CLR_GRAY}| |     | |   | (_) |${CLR_ORANGE} >  <${CLR_GRAY}  | | | | | || (_) |${CLR_ORANGE} >  <${CLR_RESET}" \
    "${p}${CLR_GRAY}|_|     |_|    \\___/ ${CLR_ORANGE}/_/\\_\\${CLR_GRAY} |_| |_| |_| \\___/ ${CLR_ORANGE}/_/\\_\\${CLR_RESET}" \
    "" \
    "${p}${spaces}${tagline}"
}

# Display banner frame with highlighted letter. $1=letter_idx (0-6, -1=none)
_show_banner_frame() {
  local h="${1:--1}"
  local M="${CLR_GRAY}"
  local A="${CLR_ORANGE}"
  local R="${CLR_RESET}"
  local p="$_BANNER_PAD"

  # Line 1: _____ is top of P
  local line1="${p}${M} "
  [[ $h -eq 0 ]] && line1+="${A}_____${M}" || line1+="_____"
  line1+="                                             ${R}"

  # Line 2: |  __ \
  local line2="${p}${M}"
  [[ $h -eq 0 ]] && line2+="${A}|  __ \\${M}" || line2+='|  __ \'
  line2+="                                            ${R}"

  # Line 3: | |__) | _ __   ___  __  __  _ __ ___    ___  __  __
  local line3="${p}${M}"
  [[ $h -eq 0 ]] && line3+="${A}| |__) |${M}" || line3+="| |__) |"
  [[ $h -eq 1 ]] && line3+=" ${A}_ __${M}" || line3+=" _ __"
  [[ $h -eq 2 ]] && line3+="   ${A}___${M}" || line3+="   ___"
  [[ $h -eq 3 ]] && line3+="  ${A}__  __${M}" || line3+="  __  __"
  [[ $h -eq 4 ]] && line3+="  ${A}_ __ ___${M}" || line3+="  _ __ ___"
  [[ $h -eq 5 ]] && line3+="    ${A}___${M}" || line3+="    ___"
  [[ $h -eq 6 ]] && line3+="  ${A}__  __${M}" || line3+="  __  __"
  line3+="${R}"

  # Line 4: |  ___/ | '__| / _ \ \ \/ / | '_ ` _ \  / _ \ \ \/ /
  local line4="${p}${M}"
  [[ $h -eq 0 ]] && line4+="${A}|  ___/ ${M}" || line4+="|  ___/ "
  [[ $h -eq 1 ]] && line4+="${A}| '__|${M}" || line4+="| '__|"
  [[ $h -eq 2 ]] && line4+=" ${A}/ _ \\${M}" || line4+=' / _ \'
  [[ $h -eq 3 ]] && line4+=" ${A}\\ \\/ /${M}" || line4+=' \ \/ /'
  [[ $h -eq 4 ]] && line4+=" ${A}| '_ \` _ \\${M}" || line4+=" | '_ \` _ \\"
  [[ $h -eq 5 ]] && line4+="  ${A}/ _ \\${M}" || line4+='  / _ \'
  [[ $h -eq 6 ]] && line4+=" ${A}\\ \\/ /${M}" || line4+=' \ \/ /'
  line4+="${R}"

  # Line 5: | |     | |   | (_) | >  <  | | | | | || (_) | >  <
  local line5="${p}${M}"
  [[ $h -eq 0 ]] && line5+="${A}| |     ${M}" || line5+="| |     "
  [[ $h -eq 1 ]] && line5+="${A}| |${M}" || line5+="| |"
  [[ $h -eq 2 ]] && line5+="   ${A}| (_) |${M}" || line5+="   | (_) |"
  [[ $h -eq 3 ]] && line5+="${A} >  <${M}" || line5+=" >  <"
  [[ $h -eq 4 ]] && line5+="  ${A}| | | | | |${M}" || line5+="  | | | | | |"
  [[ $h -eq 5 ]] && line5+="${A}| (_) |${M}" || line5+="| (_) |"
  [[ $h -eq 6 ]] && line5+="${A} >  <${M}" || line5+=" >  <"
  line5+="${R}"

  # Line 6: |_|     |_|    \___/ /_/\_\ |_| |_| |_| \___/ /_/\_\
  local line6="${p}${M}"
  [[ $h -eq 0 ]] && line6+="${A}|_|     ${M}" || line6+="|_|     "
  [[ $h -eq 1 ]] && line6+="${A}|_|${M}" || line6+="|_|"
  [[ $h -eq 2 ]] && line6+="    ${A}\\___/${M}" || line6+='    \___/'
  [[ $h -eq 3 ]] && line6+=" ${A}/_/\\_\\${M}" || line6+=' /_/\_\'
  [[ $h -eq 4 ]] && line6+=" ${A}|_| |_| |_|${M}" || line6+=" |_| |_| |_|"
  [[ $h -eq 5 ]] && line6+=" ${A}\\___/${M}" || line6+=' \___/'
  [[ $h -eq 6 ]] && line6+=" ${A}/_/\\_\\${M}" || line6+=' /_/\_\'
  line6+="${R}"

  # Tagline (centered within banner width)
  local text="Qoxi Automated Installer ${VERSION}"
  local pad="$(((BANNER_WIDTH - ${#text}) / 2))"
  local spaces
  printf -v spaces '%*s' "$pad" ''
  local line_tagline="${p}${spaces}${CLR_CYAN}Qoxi ${M}Automated Installer ${CLR_GOLD}${VERSION}${R}"

  # Output all lines atomically to prevent interference
  # Build the entire frame first, then output it all at once
  local frame
  frame=$(printf '\033[H\033[J%s\n%s\n%s\n%s\n%s\n%s\n\n%s\n' \
    "$line1" \
    "$line2" \
    "$line3" \
    "$line4" \
    "$line5" \
    "$line6" \
    "$line_tagline")

  # Output the entire frame at once
  printf '%s' "$frame"
}

# Background animation control

# PID of background animation process
BANNER_ANIMATION_PID=""

# Start animated banner in background. $1=frame_delay (default 0.1)
show_banner_animated_start() {
  local frame_delay="${1:-0.1}"

  # Skip animation in non-interactive environments
  [[ ! -t 1 ]] && return

  # Kill any existing animation
  show_banner_animated_stop 2>/dev/null

  # Hide cursor
  _wiz_hide_cursor

  # Clear screen once
  clear

  # Start animation in background subshell
  (
    direction=1
    current_letter=0

    # Trap to ensure clean exit and handle window resize
    trap 'exit 0' TERM INT
    trap 'clear' WINCH

    # Redirect output to tty (for animation), stderr to /dev/null
    [[ -c /dev/tty ]] && exec 1>/dev/tty
    exec 2>/dev/null

    while true; do
      _show_banner_frame "$current_letter"
      sleep "$frame_delay"

      # Move to next letter
      if [[ $direction -eq 1 ]]; then
        ((current_letter++))
        if [[ $current_letter -ge $BANNER_LETTER_COUNT ]]; then
          current_letter="$((BANNER_LETTER_COUNT - 2))"
          direction=-1
        fi
      else
        ((current_letter--))
        if [[ $current_letter -lt 0 ]]; then
          current_letter=1
          direction=1
        fi
      fi
    done
  ) &

  declare -g BANNER_ANIMATION_PID="$!"
}

# Stop background animated banner, show static banner
show_banner_animated_stop() {
  if [[ -n $BANNER_ANIMATION_PID ]]; then
    # Kill the background process
    kill "$BANNER_ANIMATION_PID" 2>/dev/null
    wait "$BANNER_ANIMATION_PID" 2>/dev/null
    declare -g BANNER_ANIMATION_PID=""
  fi

  # Clear screen and show static banner
  clear
  show_banner

  # Restore cursor
  _wiz_show_cursor
}
# shellcheck shell=bash
# Display utilities

# Print error with red cross. $1=message
print_error() {
  printf '%s\n' "${CLR_RED}✗${CLR_RESET} $1"
}

# Print warning with yellow icon. $1=message, $2="true" or value (optional)
print_warning() {
  local message="$1"
  local second="${2:-false}"
  local indent=""

  # Check if second argument is a value (not "true" for nested)
  if [[ $# -eq 2 && $second != "true" ]]; then
    printf '%s\n' "${CLR_YELLOW}⚠️${CLR_RESET} $message ${CLR_CYAN}$second${CLR_RESET}"
  else
    if [[ $second == "true" ]]; then
      indent="  "
    fi
    printf '%s\n' "${indent}${CLR_YELLOW}⚠️${CLR_RESET} $message"
  fi
}

# Print info with cyan icon. $1=message
print_info() {
  printf '%s\n' "${CLR_CYAN}ℹ${CLR_RESET} $1"
}

# Progress indicators

# Show gum spinner while process runs. $1=pid, $2=message, $3=done_msg/--silent
show_progress() {
  local pid="$1"
  local message="${2:-Processing}"
  local done_message="${3:-$message}"
  local silent=false
  [[ ${3:-} == "--silent" || ${4:-} == "--silent" ]] && silent=true
  [[ ${3:-} == "--silent" ]] && done_message="$message"

  # Use gum spin to wait for the process
  local poll_interval="${PROGRESS_POLL_INTERVAL:-0.2}"
  gum spin --spinner meter --spinner.foreground "#ff8700" --title "$message" -- bash -c "
    while kill -0 \"$pid\" 2>/dev/null; do
      sleep \"$poll_interval\"
    done
  "

  # Get exit code from the original process
  wait "$pid" 2>/dev/null
  local exit_code="$?"

  if [[ $exit_code -eq 0 ]]; then
    if [[ $silent != true ]]; then
      printf "${CLR_CYAN}✓${CLR_RESET} %s\n" "$done_message"
    fi
  else
    printf "${CLR_RED}✗${CLR_RESET} %s\n" "$message"
  fi

  return $exit_code
}

# Format wizard header with line-dot-line. $1=title
format_wizard_header() {
  local title="$1"

  # Use global constants for centering (from 000-init.sh and 003-banner.sh)
  local banner_pad="$_BANNER_PAD"
  local line_width="$((BANNER_WIDTH - 3))" # minus 3 as requested

  # Calculate line segments: left line + dot + right line = line_width
  # Dot takes 1 char, so each side = (line_width - 1) / 2
  local half="$(((line_width - 1) / 2))"
  local left_line="" right_line="" i

  # Use loop instead of tr (tr breaks multi-byte unicode chars on macOS)
  for ((i = 0; i < half; i++)); do
    left_line+="━"
  done
  for ((i = 0; i < line_width - 1 - half; i++)); do
    right_line+="─"
  done

  # Center title above the dot (dot is at position 'half' from line start)
  local title_len="${#title}"
  local dot_pos="$half"
  local title_start="$((dot_pos - title_len / 2))"
  local title_spaces=""
  ((title_start > 0)) && title_spaces=$(printf '%*s' "$title_start" '')

  # Output: label line, then line with dot
  # Add 2 spaces to center the shorter line relative to banner
  printf '%s  %s%s\n' "$banner_pad" "$title_spaces" "${CLR_ORANGE}${title}${CLR_RESET}"
  printf '%s  %s%s%s%s' "$banner_pad" "${CLR_CYAN}${left_line}" "${CLR_ORANGE}●" "${CLR_GRAY}${right_line}${CLR_RESET}" ""
}

# Run command with progress spinner. $1=message, $2=done_message, $@=command
run_with_progress() {
  local message="$1"
  local done_message="$2"
  shift 2

  (
    "$@" || exit 1
  ) >/dev/null 2>&1 &
  show_progress "$!" "$message" "$done_message"
}
# shellcheck shell=bash
# Download utilities

# Download file with retry. $1=output_path, $2=url
download_file() {
  local output_file="$1"
  local url="$2"
  local max_retries="${DOWNLOAD_RETRY_COUNT:-3}"
  local retry_delay="${DOWNLOAD_RETRY_DELAY:-2}"
  local retry_count=0

  while [[ "$retry_count" -lt "$max_retries" ]]; do
    if wget -q -O "$output_file" "$url"; then
      if [[ -s "$output_file" ]]; then
        return 0
      else
        print_error "Downloaded file is empty: $output_file"
      fi
    else
      print_warning "Download failed (attempt $((retry_count + 1))/$max_retries): $url"
    fi
    retry_count="$((retry_count + 1))"
    [[ "$retry_count" -lt "$max_retries" ]] && sleep "$retry_delay"
  done

  log_error "Failed to download $url after $max_retries attempts"
  return 1
}
# shellcheck shell=bash
# General utilities
# NOTE: Many functions have been moved to specialized modules:
# - download_file → 011-downloads.sh
# - apply_template_vars, download_template → 020-templates.sh
# - generate_password → 034-password-utils.sh
# - show_progress → 010-display.sh

# Command existence cache for frequently checked commands (jq, ip, etc.)
declare -gA _CMD_CACHE

# Check if command exists with caching. $1=command → 0 if available
cmd_exists() {
  local cmd="$1"
  if [[ -z "${_CMD_CACHE[$cmd]+isset}" ]]; then
    command -v "$cmd" &>/dev/null && _CMD_CACHE[$cmd]=1 || _CMD_CACHE[$cmd]=0
  fi
  [[ "${_CMD_CACHE[$cmd]}" -eq 1 ]]
}

# Clear command cache (call after installing packages)
cmd_cache_clear() {
  _CMD_CACHE=()
  hash -r
}

# Get file size in bytes (cross-platform: GNU and BSD stat, wc fallback). $1=file → size
_get_file_size() {
  local file="$1"
  local size
  # Try GNU stat first (-c%s), then BSD stat (-f%z), then wc -c
  size=$(stat -c%s "$file" 2>/dev/null) \
    || size=$(stat -f%z "$file" 2>/dev/null) \
    || size=$(wc -c <"$file" 2>/dev/null | tr -d ' ')
  # Return size or empty (caller must handle)
  [[ -n "$size" && "$size" =~ ^[0-9]+$ ]] && echo "$size"
}

# Securely delete file (shred or dd fallback). $1=file_path
secure_delete_file() {
  local file="$1"

  [[ -z "$file" ]] && return 0
  [[ ! -f "$file" ]] && return 0

  if cmd_exists shred; then
    shred -u -z "$file" 2>/dev/null || rm -f "$file"
  else
    # Fallback: overwrite with zeros before deletion
    local file_size
    file_size=$(_get_file_size "$file")
    if [[ -n "$file_size" ]]; then
      dd if=/dev/zero of="$file" bs=1 count="$file_size" conv=notrunc 2>/dev/null || true
    fi
    rm -f "$file"
  fi

  return 0
}
# shellcheck shell=bash
# Template processing utilities

# Apply {{VAR}} substitutions. $1=file, $@=VAR=value pairs
apply_template_vars() {
  local file="$1"
  shift

  if [[ ! -f "$file" ]]; then
    log_error "Template file not found: $file"
    return 1
  fi

  # Build sed command with all substitutions
  local sed_args=()

  if [[ $# -gt 0 ]]; then
    # Use provided VAR=VALUE pairs
    for pair in "$@"; do
      local var="${pair%%=*}"
      local value="${pair#*=}"

      # Debug log for empty values (skip IPv6 vars when IPv6 is disabled)
      if [[ -z "$value" ]] && grep -qF "{{${var}}}" "$file" 2>/dev/null; then
        local skip_log=false
        case "$var" in
          MAIN_IPV6 | IPV6_ADDRESS | IPV6_GATEWAY | IPV6_PREFIX)
            [[ ${IPV6_MODE:-} != "auto" && ${IPV6_MODE:-} != "manual" ]] && skip_log=true
            ;;
        esac
        [[ $skip_log == false ]] && log_debug "Template variable $var is empty, {{${var}}} will be replaced with empty string in $file"
      fi

      # Escape special characters in value for sed replacement
      # - \ must be escaped first (before adding more backslashes)
      # - & is replaced with matched pattern
      # - | is our delimiter
      # - newlines need special handling
      value="${value//\\/\\\\}"
      value="${value//&/\\&}"
      value="${value//|/\\|}"
      # Handle newlines - replace with escaped newline for sed
      value="${value//$'\n'/\\$'\n'}"

      sed_args+=(-e "s|{{${var}}}|${value}|g")
    done
  fi

  if [[ ${#sed_args[@]} -gt 0 ]]; then
    # Debug: log file size and substitution count
    local size_before
    size_before=$(wc -c <"$file" 2>/dev/null || echo "?")
    log_debug "Processing $file (${size_before} bytes, ${#sed_args[@]} substitutions)"

    # Use temp file approach - more portable than sed -i (busybox compatibility)
    local tmpfile="${file}.tmp.$$"
    if ! sed "${sed_args[@]}" "$file" >"$tmpfile" 2>>"$LOG_FILE"; then
      log_error "sed substitution failed for $file"
      rm -f "$tmpfile"
      return 1
    fi

    # Verify temp file exists and has content
    if [[ ! -s "$tmpfile" ]]; then
      log_error "sed produced empty output for $file"
      log_debug "Original file exists: $([[ -f "$file" ]] && echo yes || echo no), size: $(wc -c <"$file" 2>/dev/null || echo 0)"
      rm -f "$tmpfile"
      return 1
    fi

    # Check for unsubstituted placeholders BEFORE replacing the original file
    # This prevents deploying broken configs if caller ignores return code
    if grep -qE '\{\{[A-Za-z0-9_]+\}\}' "$tmpfile" 2>/dev/null; then
      local remaining
      remaining=$(grep -oE '\{\{[A-Za-z0-9_]+\}\}' "$tmpfile" 2>/dev/null | sort -u | tr '\n' ' ')
      log_error "Unsubstituted placeholders remain in $file: $remaining"
      rm -f "$tmpfile"
      return 1
    fi

    # Replace original with processed file (only after validation passed)
    if ! mv "$tmpfile" "$file"; then
      log_error "Failed to replace $file with processed template"
      rm -f "$tmpfile"
      return 1
    fi

    local size_after
    size_after=$(wc -c <"$file" 2>/dev/null || echo "?")
    log_debug "Finished $file (${size_after} bytes)"
  else
    # No substitutions requested - still validate no placeholders exist
    if grep -qE '\{\{[A-Za-z0-9_]+\}\}' "$file" 2>/dev/null; then
      local remaining
      remaining=$(grep -oE '\{\{[A-Za-z0-9_]+\}\}' "$file" 2>/dev/null | sort -u | tr '\n' ' ')
      log_error "Unsubstituted placeholders remain in $file: $remaining"
      return 1
    fi
  fi

  return 0
}

# Apply common template vars (IP, hostname, DNS, etc). $1=file
apply_common_template_vars() {
  local file="$1"

  # Warn about empty critical variables
  local -a critical_vars=(MAIN_IPV4 MAIN_IPV4_GW PVE_HOSTNAME INTERFACE_NAME)
  for var in "${critical_vars[@]}"; do
    if [[ -z ${!var:-} ]]; then
      log_warn "[apply_common_template_vars] Critical variable $var is empty for $file"
    fi
  done

  apply_template_vars "$file" \
    "MAIN_IPV4=${MAIN_IPV4:-}" \
    "MAIN_IPV4_GW=${MAIN_IPV4_GW:-}" \
    "MAIN_IPV6=${MAIN_IPV6:-}" \
    "FIRST_IPV6_CIDR=${FIRST_IPV6_CIDR:-}" \
    "IPV6_GATEWAY=${IPV6_GATEWAY:-fe80::1}" \
    "FQDN=${FQDN:-}" \
    "HOSTNAME=${PVE_HOSTNAME:-}" \
    "INTERFACE_NAME=${INTERFACE_NAME:-}" \
    "PRIVATE_IP_CIDR=${PRIVATE_IP_CIDR:-}" \
    "PRIVATE_SUBNET=${PRIVATE_SUBNET:-}" \
    "BRIDGE_MTU=${BRIDGE_MTU:-9000}" \
    "DNS_PRIMARY=${DNS_PRIMARY:-1.1.1.1}" \
    "DNS_SECONDARY=${DNS_SECONDARY:-1.0.0.1}" \
    "DNS6_PRIMARY=${DNS6_PRIMARY:-2606:4700:4700::1111}" \
    "DNS6_SECONDARY=${DNS6_SECONDARY:-2606:4700:4700::1001}" \
    "LOCALE=${LOCALE:-en_US.UTF-8}" \
    "KEYBOARD=${KEYBOARD:-en-us}" \
    "COUNTRY=${COUNTRY:-US}" \
    "BAT_THEME=${BAT_THEME:-Catppuccin Mocha}" \
    "PORT_SSH=${PORT_SSH:-22}" \
    "PORT_PROXMOX_UI=${PORT_PROXMOX_UI:-443}"
}

# Download template from GitHub with validation. $1=local_path, $2=remote_name (optional)
download_template() {
  local local_path="$1"
  local remote_file="${2:-$(basename "$local_path")}"
  # Add .tmpl extension for remote file (all templates use .tmpl on GitHub)
  local url="${GITHUB_BASE_URL}/templates/${remote_file}.tmpl"

  if ! download_file "$local_path" "$url"; then
    return 1
  fi

  # Verify file is not empty after download
  if [[ ! -s $local_path ]]; then
    print_error "Template $remote_file is empty or download failed"
    log_error "Template $remote_file is empty after download"
    return 1
  fi

  # Validate template integrity based on file type
  local filename
  filename=$(basename "$local_path")
  case "$filename" in
    answer.toml)
      if ! grep -q "\[global\]" "$local_path" 2>/dev/null; then
        print_error "Template $remote_file appears corrupted (missing [global] section)"
        log_error "Template $remote_file corrupted - missing [global] section"
        return 1
      fi
      ;;
    sshd_config)
      if ! grep -q "PasswordAuthentication" "$local_path" 2>/dev/null; then
        print_error "Template $remote_file appears corrupted (missing PasswordAuthentication)"
        log_error "Template $remote_file corrupted - missing PasswordAuthentication"
        return 1
      fi
      ;;
    *.sh)
      # Shell scripts should start with shebang or at least contain some bash syntax
      if ! head -1 "$local_path" | grep -qE "^#!.*bash|^# shellcheck|^export " && ! grep -qE "(if|then|echo|function|export)" "$local_path" 2>/dev/null; then
        print_error "Template $remote_file appears corrupted (invalid shell script)"
        log_error "Template $remote_file corrupted - invalid shell script"
        return 1
      fi
      ;;
    nftables.conf)
      # nftables config must have table definition
      if ! grep -q "table inet" "$local_path" 2>/dev/null; then
        print_error "Template $remote_file appears corrupted (missing table inet definition)"
        log_error "Template $remote_file corrupted - missing table inet"
        return 1
      fi
      ;;
    promtail.yml | promtail.yaml)
      # Promtail config must have server and clients sections
      if ! grep -q "server:" "$local_path" 2>/dev/null || ! grep -q "clients:" "$local_path" 2>/dev/null; then
        print_error "Template $remote_file appears corrupted (missing YAML structure)"
        log_error "Template $remote_file corrupted - missing server: or clients: section"
        return 1
      fi
      ;;
    chrony | chrony.conf)
      # Chrony config must have pool or server directive
      if ! grep -qE "^(pool|server)" "$local_path" 2>/dev/null; then
        print_error "Template $remote_file appears corrupted (missing NTP server config)"
        log_error "Template $remote_file corrupted - missing pool or server directive"
        return 1
      fi
      ;;
    *.service)
      # Systemd service files must have [Service] section and ExecStart directive
      if ! grep -q "\[Service\]" "$local_path" 2>/dev/null; then
        print_error "Template $remote_file appears corrupted (missing [Service] section)"
        log_error "Template $remote_file corrupted - missing [Service] section"
        return 1
      fi
      if ! grep -qE "^ExecStart=" "$local_path" 2>/dev/null; then
        print_error "Template $remote_file appears corrupted (missing ExecStart)"
        log_error "Template $remote_file corrupted - missing ExecStart"
        return 1
      fi
      ;;
    *.conf | *.sources | *.timer)
      # Config files should have some content
      if [[ $(wc -l <"$local_path" 2>/dev/null || echo 0) -lt 2 ]]; then
        print_error "Template $remote_file appears corrupted (too short)"
        log_error "Template $remote_file corrupted - file too short"
        return 1
      fi
      ;;
  esac

  log_info "Template $remote_file downloaded and validated successfully"
  return 0
}
# shellcheck shell=bash
# SSH helper functions - Session management and connection
# ControlMaster multiplexes all connections over single TCP socket

# Control socket path - uses centralized constant from 003-init.sh
# $_TEMP_SSH_CONTROL_PATH is PID-scoped so subshells share master connection

# SSH options for QEMU VM - host key checking disabled (local/ephemeral)
# Includes keepalive settings: ServerAliveInterval=30s, ServerAliveCountMax=3 (90s before disconnect)
SSH_OPTS=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
  -o "ConnectTimeout=${SSH_CONNECT_TIMEOUT:-10}"
  -o ServerAliveInterval=30
  -o ServerAliveCountMax=3
  -o ControlMaster=auto
  -o "ControlPath=${_TEMP_SSH_CONTROL_PATH}"
  -o ControlPersist=300
)
SSH_PORT="${SSH_PORT_QEMU:-5555}"

# Session passfile (created once, path uses $$ for subshell sharing)
_SSH_SESSION_PASSFILE=""
_SSH_SESSION_LOGGED=false

# Session management

# Gets passfile path based on top-level PID ($$ inherited by subshells)
_ssh_passfile_path() {
  local passfile_dir="/dev/shm"
  if [[ ! -d /dev/shm ]] || [[ ! -w /dev/shm ]]; then
    passfile_dir="/tmp"
  fi
  printf '%s\n' "${passfile_dir}/pve-ssh-session.$$"
}

# Initializes SSH session with persistent passfile (creates once, reuses across operations)
_ssh_session_init() {
  local passfile_path
  passfile_path=$(_ssh_passfile_path)

  # Already exists with content? Just set variable and return
  if [[ -f "$passfile_path" ]] && [[ -s "$passfile_path" ]]; then
    declare -g _SSH_SESSION_PASSFILE="$passfile_path"
    return 0
  fi

  # Create new passfile (no trailing newline - sshpass reads entire file content)
  printf '%s' "$NEW_ROOT_PASSWORD" >"$passfile_path"
  chmod 600 "$passfile_path"
  declare -g _SSH_SESSION_PASSFILE="$passfile_path"

  # Register temp files for cleanup (once from main shell)
  if [[ $BASHPID == "$$" ]] && [[ $_SSH_SESSION_LOGGED != true ]]; then
    register_temp_file "$passfile_path"
    register_temp_file "$_TEMP_SSH_CONTROL_PATH"
    log_info "SSH session initialized: $passfile_path"
    declare -g _SSH_SESSION_LOGGED=true
  fi
}

# Cleans up SSH control master socket (graceful close)
_ssh_control_cleanup() {
  if [[ -S "$_TEMP_SSH_CONTROL_PATH" ]]; then
    # Gracefully close master connection
    ssh -o ControlPath="$_TEMP_SSH_CONTROL_PATH" -O exit root@localhost >>"${LOG_FILE:-/dev/null}" 2>&1 || true
    rm -f "$_TEMP_SSH_CONTROL_PATH" 2>/dev/null || true
    log_info "SSH control socket cleaned up: $_TEMP_SSH_CONTROL_PATH"
  fi
}

# Cleans up SSH session (control socket + passfile with secure deletion)
_ssh_session_cleanup() {
  # Clean up control socket first
  _ssh_control_cleanup

  local passfile_path
  passfile_path=$(_ssh_passfile_path)

  [[ ! -f "$passfile_path" ]] && return 0

  # Use secure_delete_file if available (defined in 012-utils.sh)
  if type secure_delete_file &>/dev/null; then
    secure_delete_file "$passfile_path"
  elif cmd_exists shred; then
    shred -u -z "$passfile_path" 2>/dev/null || rm -f "$passfile_path"
  else
    # Fallback: overwrite with zeros (cross-platform stat: GNU -c%s, BSD -f%z, wc -c)
    local file_size
    file_size=$(stat -c%s "$passfile_path" 2>/dev/null) \
      || file_size=$(stat -f%z "$passfile_path" 2>/dev/null) \
      || file_size=$(wc -c <"$passfile_path" 2>/dev/null | tr -d ' ')
    if [[ -n "$file_size" && "$file_size" =~ ^[0-9]+$ ]]; then
      dd if=/dev/zero of="$passfile_path" bs=1 count="$file_size" conv=notrunc 2>/dev/null || true
    fi
    rm -f "$passfile_path"
  fi

  declare -g _SSH_SESSION_PASSFILE=""
  log_info "SSH session cleaned up: $passfile_path"
}

# Gets session passfile (initializes if needed)
_ssh_get_passfile() {
  _ssh_session_init
  printf '%s\n' "$_SSH_SESSION_PASSFILE"
}

# Port and connection checks

# Checks if port is available. Returns 0 if available, 1 if in use
check_port_available() {
  local port="$1"
  if cmd_exists ss; then
    if ss -tuln 2>/dev/null | grep -q ":$port "; then
      return 1
    fi
  elif cmd_exists netstat; then
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
      return 1
    fi
  fi
  return 0
}

# Waits for SSH to be ready on localhost:SSH_PORT. $1=timeout (default 120)
wait_for_ssh_ready() {
  local timeout="${1:-120}"
  local start_time
  start_time=$(date +%s)

  # Clear any stale known_hosts entries
  local ssh_known_hosts="${INSTALL_DIR:-${HOME:-/root}}/.ssh/known_hosts"
  ssh-keygen -f "$ssh_known_hosts" -R "[localhost]:${SSH_PORT}" >>"${LOG_FILE:-/dev/null}" 2>&1 || true

  # Port check - wait for VM to boot and open SSH port
  # Allow up to 75% of timeout for port check, but track actual elapsed time
  local port_timeout="$((timeout * 3 / 4))"
  local retry_delay="${RETRY_DELAY_SECONDS:-2}"
  local port_check=0
  local elapsed=0
  while ((elapsed < port_timeout)); do
    if (echo >/dev/tcp/localhost/"$SSH_PORT") 2>/dev/null; then
      port_check=1
      break
    fi
    sleep "$retry_delay"
    ((elapsed += retry_delay))
  done

  if [[ $port_check -eq 0 ]]; then
    print_error "Port $SSH_PORT is not accessible"
    log_error "Port $SSH_PORT not accessible after ${port_timeout}s"
    return 1
  fi

  # Calculate remaining time for SSH verification
  local actual_elapsed="$(($(date +%s) - start_time))"
  local ssh_timeout="$((timeout - actual_elapsed))"
  if ((ssh_timeout < 10)); then
    ssh_timeout=10 # Minimum 10s for SSH check
  fi

  local passfile
  passfile=$(_ssh_get_passfile)

  # Wait for SSH to be ready with background process
  (
    elapsed=0
    retry_delay="${RETRY_DELAY_SECONDS:-2}"
    while ((elapsed < ssh_timeout)); do
      if sshpass -f "$passfile" ssh -p "$SSH_PORT" "${SSH_OPTS[@]}" root@localhost 'echo ready' >>"${LOG_FILE:-/dev/null}" 2>&1; then
        exit 0
      fi
      sleep "$retry_delay"
      ((elapsed += retry_delay))
    done
    exit 1
  ) &
  local wait_pid="$!"

  show_progress "$wait_pid" "Waiting for SSH to be ready" "SSH connection established"
  return "$?"
}

# SSH key utilities

# Parses SSH key into SSH_KEY_TYPE, SSH_KEY_DATA, SSH_KEY_COMMENT, SSH_KEY_SHORT
parse_ssh_key() {
  local key="$1"

  declare -g SSH_KEY_TYPE=""
  declare -g SSH_KEY_DATA=""
  declare -g SSH_KEY_COMMENT=""
  declare -g SSH_KEY_SHORT=""

  [[ -z "$key" ]] && return 1

  declare -g SSH_KEY_TYPE="$(printf '%s\n' "$key" | awk '{print $1}')"
  declare -g SSH_KEY_DATA="$(printf '%s\n' "$key" | awk '{print $2}')"
  declare -g SSH_KEY_COMMENT="$(printf '%s\n' "$key" | awk '{$1=""; $2=""; print}' | sed 's/^ *//')"

  if [[ ${#SSH_KEY_DATA} -gt 35 ]]; then
    declare -g SSH_KEY_SHORT="${SSH_KEY_DATA:0:20}...${SSH_KEY_DATA: -10}"
  else
    declare -g SSH_KEY_SHORT="$SSH_KEY_DATA"
  fi

  return 0
}

# Gets SSH public key from rescue system's authorized_keys (first valid key)
get_rescue_ssh_key() {
  local auth_keys="${INSTALL_DIR:-${HOME:-/root}}/.ssh/authorized_keys"
  if [[ -f "$auth_keys" ]]; then
    grep -E "^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-nistp(256|384|521)|sk-(ssh-ed25519|ecdsa-sha2-nistp256)@openssh.com)" "$auth_keys" 2>/dev/null | head -1
  fi
}
# shellcheck shell=bash
# SSH helper functions - Remote execution

# Default timeout for remote commands (seconds)
# Can be overridden per-call or via SSH_COMMAND_TIMEOUT environment variable
readonly SSH_DEFAULT_TIMEOUT=300

# Mask passwords/secrets in script for logging. $1=script → stdout
_sanitize_script_for_log() {
  local script="$1"

  # Use \x01 (ASCII SOH) as delimiter - won't appear in passwords or scripts
  # Avoids conflict with # in passwords or / in paths
  local d=$'\x01'

  # Mask common password patterns (variable assignments and chpasswd)
  # Handle escaped quotes in double-quoted strings: "([^"\\]|\\.)*" matches "foo\"bar"
  script=$(printf '%s\n' "$script" | sed -E "s${d}(PASSWORD|password|PASSWD|passwd|SECRET|secret|TOKEN|token|KEY|key)=('[^']*'|\"([^\"\\\\]|\\\\.)*\"|[^[:space:]'\";]+)${d}\\1=[REDACTED]${d}g")

  # Pattern: echo "user:password" | chpasswd (double-quoted, handles | and escaped chars)
  script=$(printf '%s\n' "$script" | sed -E "s${d}(echo[[:space:]]+\"[^:]+:)([^\"\\\\]|\\\\.)*(\")${d}\\1[REDACTED]\\3${d}g")

  # Pattern: echo 'user:password' | chpasswd (single-quoted, handles | in password)
  script=$(printf '%s\n' "$script" | sed -E "s${d}(echo[[:space:]]+'[^:]+:)[^']*(')${d}\\1[REDACTED]\\2${d}g")

  # Pattern: echo user:password | chpasswd (unquoted - | is pipe delimiter, not in password)
  script=$(printf '%s\n' "$script" | sed -E "s${d}(echo[[:space:]]+[^:\"'[:space:]]+:)[^|[:space:]]*${d}\\1[REDACTED]${d}g")

  # Pattern: --authkey='...' or --authkey="..." or --authkey=...
  script=$(printf '%s\n' "$script" | sed -E "s${d}(--authkey=)('[^']*'|\"[^\"]*\"|[^[:space:]'\";]+)${d}\\1[REDACTED]${d}g")

  # Pattern: echo 'base64string' | base64 -d | chpasswd (encoded credentials)
  script=$(printf '%s\n' "$script" | sed -E "s${d}(echo[[:space:]]+['\"]?)[A-Za-z0-9+/=]+(['\"]?[[:space:]]*\\|[[:space:]]*base64[[:space:]]+-d)${d}\\1[REDACTED]\\2${d}g")

  printf '%s\n' "$script"
}

# Execute command on remote VM with exponential backoff retry. $*=command. Returns exit code (124=timeout)
# Note: stderr is redirected to LOG_FILE to prevent breaking live logs display
remote_exec() {
  local passfile
  passfile=$(_ssh_get_passfile)

  local cmd_timeout="${SSH_COMMAND_TIMEOUT:-$SSH_DEFAULT_TIMEOUT}"
  local max_attempts="${SSH_RETRY_ATTEMPTS:-3}"
  local base_delay="${RETRY_DELAY_SECONDS:-2}"
  local attempt=0

  while [[ $attempt -lt $max_attempts ]]; do
    attempt="$((attempt + 1))"

    timeout "$cmd_timeout" sshpass -f "$passfile" ssh -p "$SSH_PORT" "${SSH_OPTS[@]}" root@localhost "$@" 2>>"$LOG_FILE"
    local exit_code="$?"

    if [[ $exit_code -eq 0 ]]; then
      return 0
    fi

    if [[ $exit_code -eq 124 ]]; then
      log_error "SSH command timed out after ${cmd_timeout}s: $(_sanitize_script_for_log "$*")"
      return 124
    fi

    if [[ $attempt -lt $max_attempts ]]; then
      # Exponential backoff: delay = base_delay * 2^(attempt-1), capped at 30s
      local delay="$((base_delay * (1 << (attempt - 1))))"
      ((delay > 30)) && delay=30
      log_info "SSH attempt $attempt failed, retrying in ${delay} seconds..."
      sleep "$delay"
    fi
  done

  log_error "SSH command failed after $max_attempts attempts: $(_sanitize_script_for_log "$*")"
  return 1
}

# Internal: remote script with progress. Use remote_run() instead.
_remote_exec_with_progress() {
  local message="$1"
  local script="$2"
  local done_message="${3:-$message}"

  log_info "_remote_exec_with_progress: $message"
  log_info "--- Script start (sanitized) ---"
  # Sanitize script before logging to prevent password leaks
  _sanitize_script_for_log "$script" >>"$LOG_FILE"
  log_info "--- Script end ---"

  local passfile
  passfile=$(_ssh_get_passfile)

  local output_file=""
  output_file=$(mktemp) || {
    log_error "mktemp failed for output_file in _remote_exec_with_progress"
    return 1
  }
  register_temp_file "$output_file"

  local cmd_timeout="${SSH_COMMAND_TIMEOUT:-$SSH_DEFAULT_TIMEOUT}"

  printf '%s\n' "$script" | timeout "$cmd_timeout" sshpass -f "$passfile" ssh -p "$SSH_PORT" "${SSH_OPTS[@]}" root@localhost 'bash -s' >"$output_file" 2>&1 &
  local pid="$!"
  show_progress "$pid" "$message" "$done_message"
  local exit_code="$?"

  # Check output for critical errors (exclude package names like liberror-perl)
  # Use word boundaries and exclude common false positives from apt/installer output
  # Known harmless: grub-probe ZFS warnings, USB device detection in QEMU VM
  local exclude_pattern='(lib.*error|error-perl|\.deb|Unpacking|Setting up|Selecting|grub-probe|/sys/bus/usb|bInterface)'
  if grep -iE '\b(error|failed|cannot|unable|fatal)\b' "$output_file" 2>/dev/null \
    | grep -qivE "$exclude_pattern"; then
    log_warn "Potential errors in remote command output:"
    grep -iE '\b(error|failed|cannot|unable|fatal)\b' "$output_file" 2>/dev/null \
      | grep -ivE "$exclude_pattern" >>"$LOG_FILE" || true
  fi

  cat "$output_file" >>"$LOG_FILE"
  rm -f "$output_file"

  if [[ $exit_code -ne 0 ]]; then
    log_info "_remote_exec_with_progress: FAILED with exit code $exit_code"
  else
    log_info "_remote_exec_with_progress: completed successfully"
  fi

  return $exit_code
}

# PRIMARY: Run remote script with progress, exit on failure.
# $1=message, $2=script, $3=done_message (optional)
remote_run() {
  local message="$1"
  local script="$2"
  local done_message="${3:-$message}"

  if ! _remote_exec_with_progress "$message" "$script" "$done_message"; then
    log_error "$message failed"
    exit 1
  fi
}

# Copy file to remote via SCP with lock. $1=src, $2=dst. Returns 0=success, 1=failure
# Uses flock to serialize parallel scp calls through ControlMaster socket
# Lock file path uses centralized constant from 003-init.sh ($_TEMP_SCP_LOCK_FILE)
# Note: Lock file is pre-registered in 004-trap.sh (before parallel execution begins)
# Note: stdout/stderr redirected to LOG_FILE to prevent breaking live logs display
remote_copy() {
  local src="$1"
  local dst="$2"

  local passfile
  passfile=$(_ssh_get_passfile)

  # Use flock to serialize scp operations (prevents ControlMaster data corruption)
  # FD 200 is arbitrary high number to avoid conflicts
  # Note: subshell exit code is captured and returned properly
  (
    flock -x 200 || {
      log_error "Failed to acquire SCP lock for $src"
      exit 1
    }
    if ! sshpass -f "$passfile" scp -P "$SSH_PORT" "${SSH_OPTS[@]}" "$src" "root@localhost:$dst" >>"$LOG_FILE" 2>&1; then
      log_error "Failed to copy $src to $dst"
      exit 1
    fi
  ) 200>"$_TEMP_SCP_LOCK_FILE"
  # Capture and return subshell exit code (fixes silent failure bug)
  return $?
}
# shellcheck shell=bash
# Password utilities

# Generate secure random password. $1=length (default 16) → password
generate_password() {
  local length="${1:-16}"
  # Use /dev/urandom with base64, filter to alphanumeric + some special chars
  tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c "$length"
}
# shellcheck shell=bash
# ZFS Helper Functions
# Reusable ZFS utilities for RAID validation, disk mapping, and pool creation

# Generate virtio device name. $1=idx → "vda", "vdz", "vdaa", etc
_virtio_name_for_index() {
  local idx="$1"
  local letters="abcdefghijklmnopqrstuvwxyz"

  if ((idx < 26)); then
    printf 'vd%s\n' "${letters:$idx:1}"
  else
    # After vdz: vdaa, vdab, ..., vdaz, vdba, ...
    local prefix_idx="$(((idx - 26) / 26))"
    local suffix_idx="$(((idx - 26) % 26))"
    printf 'vd%s%s\n' "${letters:$prefix_idx:1}" "${letters:$suffix_idx:1}"
  fi
}

# Create virtio disk mapping. $1=boot_disk, $2+=pool_disks → /tmp/virtio_map.env
create_virtio_mapping() {
  local boot_disk="$1"
  shift
  local pool_disks=("$@")

  declare -gA VIRTIO_MAP
  local virtio_idx=0

  # Add boot disk first (if separate)
  if [[ -n "$boot_disk" ]]; then
    local vdev
    vdev="$(_virtio_name_for_index "$virtio_idx")"
    VIRTIO_MAP["$boot_disk"]="$vdev"
    log_info "Virtio mapping: $boot_disk → /dev/$vdev (boot)"
    ((virtio_idx++))
  fi

  # Add pool disks (skip if already mapped as boot disk)
  for drive in "${pool_disks[@]}"; do
    if [[ -n ${VIRTIO_MAP[$drive]:-} ]]; then
      log_info "Virtio mapping: $drive already mapped as boot disk, skipping"
      continue
    fi
    local vdev
    vdev="$(_virtio_name_for_index "$virtio_idx")"
    VIRTIO_MAP["$drive"]="$vdev"
    log_info "Virtio mapping: $drive → /dev/$vdev (pool)"
    ((virtio_idx++))
  done

  # Export mapping to file (use -gA so it creates global when sourced)
  declare -p VIRTIO_MAP | sed 's/declare -A/declare -gA/' >/tmp/virtio_map.env
  register_temp_file "/tmp/virtio_map.env"
  log_info "Virtio mapping saved to /tmp/virtio_map.env"
}

# Load virtio mapping from /tmp/virtio_map.env into VIRTIO_MAP array
load_virtio_mapping() {
  if [[ -f /tmp/virtio_map.env ]]; then
    # Validate file contains only expected declare statement (defense in depth)
    if ! grep -qE '^declare -gA VIRTIO_MAP=' /tmp/virtio_map.env; then
      log_error "virtio_map.env missing expected declare statement"
      return 1
    fi
    if grep -qvE '^declare -gA VIRTIO_MAP=' /tmp/virtio_map.env; then
      log_error "virtio_map.env contains unexpected content"
      return 1
    fi
    # shellcheck disable=SC1091
    source /tmp/virtio_map.env
    return 0
  else
    log_error "Virtio mapping file not found"
    return 1
  fi
}

# Map disks to virtio. $1=format (toml_array/bash_array/space_separated), $2+=disks
map_disks_to_virtio() {
  local format="$1"
  shift
  local disks=("$@")

  if [[ ${#disks[@]} -eq 0 ]]; then
    log_error "No disks provided to map_disks_to_virtio"
    return 1
  fi

  local vdevs=()
  for disk in "${disks[@]}"; do
    if [[ -z "${VIRTIO_MAP[$disk]+isset}" ]]; then
      log_error "VIRTIO_MAP not initialized or disk $disk not mapped"
      return 1
    fi
    local vdev="${VIRTIO_MAP[$disk]}"
    vdevs+=("/dev/$vdev")
  done

  case "$format" in
    toml_array)
      # TOML array format for answer.toml: ["vda", "vdb"] (short names, no /dev/)
      # Proxmox docs: https://pve.proxmox.com/wiki/Automated_Installation
      local result="["
      for i in "${!vdevs[@]}"; do
        local short_name="${vdevs[$i]#/dev/}" # Strip /dev/ prefix
        result+="\"${short_name}\""
        [[ $i -lt $((${#vdevs[@]} - 1)) ]] && result+=", "
      done
      result+="]"
      printf '%s\n' "$result"
      ;;
    bash_array)
      # Bash array format: (/dev/vda /dev/vdb) - for use in scripts
      printf '%s\n' "(${vdevs[*]})"
      ;;
    space_separated)
      # Space-separated list: /dev/vda /dev/vdb - for use in commands
      printf '%s\n' "${vdevs[*]}"
      ;;
    *)
      log_error "Unknown format: $format"
      return 1
      ;;
  esac
}

# Build zpool create command. $1=pool, $2=raid_type, $3+=vdevs
build_zpool_command() {
  local pool_name="$1"
  local raid_type="$2"
  shift 2
  local vdevs=("$@")

  if [[ -z "$pool_name" ]]; then
    log_error "Pool name not provided"
    return 1
  fi

  if [[ ${#vdevs[@]} -eq 0 ]]; then
    log_error "No vdevs provided to build_zpool_command"
    return 1
  fi

  local cmd="zpool create -f $pool_name"

  case "$raid_type" in
    single)
      cmd+=" ${vdevs[0]}"
      ;;
    raid0)
      cmd+=" ${vdevs[*]}"
      ;;
    raid1)
      cmd+=" mirror ${vdevs[*]}"
      ;;
    raidz1)
      cmd+=" raidz ${vdevs[*]}"
      ;;
    raidz2)
      cmd+=" raidz2 ${vdevs[*]}"
      ;;
    raidz3)
      cmd+=" raidz3 ${vdevs[*]}"
      ;;
    raid10)
      # RAID10: pair up disks for striped mirrors
      # Example: mirror vda vdb mirror vdc vdd
      local vdev_count="${#vdevs[@]}"
      if ((vdev_count < 4)); then
        log_error "raid10 requires at least 4 vdevs, got $vdev_count"
        return 1
      fi
      if ((vdev_count % 2 != 0)); then
        log_error "raid10 requires even number of vdevs, got $vdev_count"
        return 1
      fi
      for ((i = 0; i < vdev_count; i += 2)); do
        cmd+=" mirror ${vdevs[$i]} ${vdevs[$((i + 1))]}"
      done
      ;;
    *)
      log_error "Unknown RAID type: $raid_type"
      return 1
      ;;
  esac

  printf '%s\n' "$cmd"
}

# Map RAID type to TOML format. $1=raid_type → "raidz-1" etc
map_raid_to_toml() {
  local raid="$1"

  case "$raid" in
    single) echo "raid0" ;; # Single disk uses raid0 in TOML
    raid0) echo "raid0" ;;
    raid1) echo "raid1" ;;
    raidz1) echo "raidz-1" ;;
    raidz2) echo "raidz-2" ;;
    raidz3) echo "raidz-3" ;;
    raid5) echo "raidz-1" ;; # Legacy mapping
    raid10) echo "raid10" ;;
    *)
      log_warn "Unknown RAID type '$raid', defaulting to raid0"
      printf '%s\n' "raid0"
      ;;
  esac
}
# shellcheck shell=bash
# Parallel execution framework for faster installation

# Internal: run single task in parallel group. $1=result_dir, $2=idx, $3=func
_run_parallel_task() {
  local result_dir="$1"
  local idx="$2"
  local func="$3"

  # Default to failure marker on ANY exit (handles remote_run's exit 1)
  # shellcheck disable=SC2064
  trap "touch '$result_dir/fail_$idx' 2>/dev/null" EXIT

  if "$func" >/dev/null 2>&1; then
    # Write success marker BEFORE clearing trap to avoid race condition
    # If touch fails, trap still fires and marks as failed
    if touch "$result_dir/success_$idx" 2>/dev/null; then
      trap - EXIT # Only clear trap after success marker is confirmed written
    fi
  fi
}

# Run config functions in parallel with concurrency limit. $1=name, $2=done_msg, $@=functions
run_parallel_group() {
  local group_name="$1"
  local done_msg="$2"
  shift 2
  local funcs=("$@")

  if [[ ${#funcs[@]} -eq 0 ]]; then
    log_info "No functions to run in parallel group: $group_name"
    return 0
  fi

  # Max concurrent jobs (prevents fork bombs, default 8)
  local max_jobs="${PARALLEL_MAX_JOBS:-8}"
  log_info "Running parallel group '$group_name' with functions: ${funcs[*]} (max $max_jobs concurrent)"

  # Track results via temp files (avoid subshell variable issues)
  local result_dir
  result_dir=$(mktemp -d) || {
    log_error "Failed to create temp dir for parallel group '$group_name'"
    return 1
  }
  register_temp_file "$result_dir"
  export PARALLEL_RESULT_DIR="$result_dir"

  # Start functions in background with concurrency limit
  # Use trap to ensure marker created even if function calls exit 1 (like remote_run)
  # NOTE: Each subshell gets its own copy of variables at fork time.
  local i=0
  local running=0
  local -a task_pids=()
  for func in "${funcs[@]}"; do
    _run_parallel_task "$result_dir" "$i" "$func" &
    task_pids+=("$!")
    ((i++))
    ((running++))

    # Poll for job completion (wait -n requires bash 4.3+, we support 4.0+)
    while ((running >= max_jobs)); do
      local completed=0
      for ((j = 0; j < i; j++)); do
        [[ -f "$result_dir/success_$j" || -f "$result_dir/fail_$j" ]] && ((completed++))
      done
      running="$((i - completed))"
      ((running >= max_jobs)) && sleep 0.1
    done
  done

  local count="$i"

  # Wait for all with single progress
  (
    while true; do
      local done_count=0
      for ((j = 0; j < count; j++)); do
        [[ -f "$result_dir/success_$j" || -f "$result_dir/fail_$j" ]] && ((done_count++))
      done
      [[ $done_count -eq $count ]] && break
      sleep "${PROGRESS_POLL_INTERVAL:-0.2}"
    done
    # Exit non-zero if any task failed (for correct progress indicator)
    for ((j = 0; j < count; j++)); do
      [[ -f "$result_dir/fail_$j" ]] && exit 1
    done
    exit 0
  ) &
  show_progress "$!" "$group_name" "$done_msg"

  # Reap background task processes to prevent zombies (wait for specific PIDs only)
  for pid in "${task_pids[@]}"; do
    wait "$pid" 2>/dev/null || true
  done

  # Collect configured features for display
  local configured=()
  for f in "$result_dir"/ran_*; do
    [[ -f "$f" ]] && configured+=("$(cat "$f")")
  done

  # Show configured features as subtasks (one per line)
  for item in "${configured[@]}"; do
    add_subtask_log "$item"
  done

  # Check for failures
  local failures=0
  for ((j = 0; j < count; j++)); do
    [[ -f "$result_dir/fail_$j" ]] && ((failures++))
  done

  # Cleanup before return (not using RETURN trap - it overwrites exit status)
  rm -rf "$result_dir"
  unset PARALLEL_RESULT_DIR

  if [[ $failures -gt 0 ]]; then
    log_error "$failures/$count functions failed in group '$group_name'"
    return $failures
  fi

  return 0
}

# Mark feature as configured in parallel group. $1=feature name
# Safe to call outside parallel groups - becomes a no-op (always returns 0)
parallel_mark_configured() {
  local feature="$1"
  # Only write if directory exists (protects against stale PARALLEL_RESULT_DIR)
  if [[ -n ${PARALLEL_RESULT_DIR:-} && -d $PARALLEL_RESULT_DIR ]]; then
    printf '%s' "$feature" >"$PARALLEL_RESULT_DIR/ran_$BASHPID"
  fi
  return 0
}

# Async feature execution helpers

# Start async feature if flag is set. $1=feature, $2=flag_var. Sets REPLY to PID.
# IMPORTANT: Do NOT call via $(). Call directly to keep process as child of main shell.
start_async_feature() {
  local feature="$1"
  local flag_var="$2"
  local flag_value="${!flag_var:-}"

  REPLY=""
  [[ $flag_value != "yes" ]] && return 0

  "configure_${feature}" >>"$LOG_FILE" 2>&1 &
  REPLY="$!"
}

# Wait for async feature and log result. $1=feature, $2=pid
wait_async_feature() {
  local feature="$1"
  local pid="$2"

  [[ -z $pid ]] && return 0

  wait "$pid" 2>/dev/null
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    log_error "configure_${feature} failed (exit code: $exit_code)"
    return 1
  fi
  return 0
}
# shellcheck shell=bash
# Parallel file operations and deployment helpers

# Copy multiple files to remote with error aggregation. $@="src:dst" pairs
# Note: Copies are serialized due to ControlMaster socket locking
run_batch_copies() {
  local -a pids=()
  local -a pairs=("$@")

  for pair in "${pairs[@]}"; do
    local src="${pair%%:*}"
    local dst="${pair#*:}"
    remote_copy "$src" "$dst" &
    pids+=("$!")
  done

  # Wait for all copies and track failures
  local failures=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      ((failures++))
    fi
  done

  if [[ $failures -gt 0 ]]; then
    log_error "$failures/${#pairs[@]} parallel copies failed"
    return 1
  fi

  return 0
}

# Deploy systemd timer and create log dir. $1=timer_name, $2=log_dir
deploy_timer_with_logdir() {
  local timer_name="$1"
  local log_dir="$2"

  deploy_systemd_timer "$timer_name" || return 1

  remote_exec "mkdir -p '$log_dir'" || {
    log_error "Failed to create $log_dir"
    return 1
  }
}

# Deploy template with variable substitution. $1=template, $2=dest, $@=VAR=value
# For .service files: validates ExecStart exists and verifies remote copy
deploy_template() {
  local template="$1"
  local dest="$2"
  shift 2
  local staged
  local is_service=false
  [[ $dest == *.service ]] && is_service=true

  # Stage template to temp location to preserve original
  staged=$(mktemp) || {
    log_error "Failed to create temp file for $template"
    return 1
  }
  register_temp_file "$staged"
  cp "$template" "$staged" || {
    log_error "Failed to stage template $template"
    rm -f "$staged"
    return 1
  }

  # Apply template vars (also validates no unsubstituted placeholders remain)
  apply_template_vars "$staged" "$@" || {
    log_error "Template substitution failed for $template"
    rm -f "$staged"
    return 1
  }

  # For .service files, verify ExecStart exists after substitution
  if [[ $is_service == true ]] && ! grep -q "ExecStart=" "$staged" 2>/dev/null; then
    log_error "Service file $dest missing ExecStart after template substitution"
    rm -f "$staged"
    return 1
  fi

  # Create parent directory on remote if needed
  local dest_dir
  dest_dir=$(dirname "$dest")
  remote_exec "mkdir -p '$dest_dir'" || {
    log_error "Failed to create directory $dest_dir"
    rm -f "$staged"
    return 1
  }

  remote_copy "$staged" "$dest" || {
    log_error "Failed to deploy $template to $dest"
    rm -f "$staged"
    return 1
  }
  rm -f "$staged"

  # Set proper permissions for systemd files (fixes "world-inaccessible" warning)
  if [[ $dest == /etc/systemd/* || $dest == *.service || $dest == *.timer ]]; then
    remote_exec "chmod 644 '$dest'" || {
      log_error "Failed to set permissions on $dest"
      return 1
    }
  fi

  # For .service files, verify remote copy wasn't corrupted
  if [[ $is_service == true ]]; then
    remote_exec "grep -q 'ExecStart=' '$dest'" || {
      log_error "Remote service file $dest appears corrupted (missing ExecStart)"
      return 1
    }
  fi
}
# shellcheck shell=bash
# Feature wrapper factory functions

# Create configure_* wrapper checking INSTALL_* flag. $1=feature, $2=flag_var
# shellcheck disable=SC2086,SC2154
make_feature_wrapper() {
  local feature="$1"
  local flag_var="$2"
  eval "configure_${feature}() { [[ \${${flag_var}:-} != \"yes\" ]] && return 0; _config_${feature}; }"
}

# Create configure_* wrapper checking VAR==value. $1=feature, $2=var, $3=expected
# shellcheck disable=SC2086,SC2154
make_condition_wrapper() {
  local feature="$1"
  local var_name="$2"
  local expected_value="$3"
  eval "configure_${feature}() { [[ \${${var_name}:-} != \"${expected_value}\" ]] && return 0; _config_${feature}; }"
}
# shellcheck shell=bash
# Systemd units deployment helpers

# Deploy .service + .timer and enable. $1=timer_name, $2=template_dir (optional)
deploy_systemd_timer() {
  local timer_name="$1"
  local template_dir="${2:+$2/}"

  remote_copy "templates/${template_dir}${timer_name}.service" \
    "/etc/systemd/system/${timer_name}.service" || {
    log_error "Failed to deploy ${timer_name} service"
    return 1
  }

  remote_copy "templates/${template_dir}${timer_name}.timer" \
    "/etc/systemd/system/${timer_name}.timer" || {
    log_error "Failed to deploy ${timer_name} timer"
    return 1
  }

  # Set proper permissions to avoid systemd warnings
  remote_exec "chmod 644 /etc/systemd/system/${timer_name}.service /etc/systemd/system/${timer_name}.timer" || {
    log_warn "Failed to set permissions on ${timer_name} unit files"
  }

  remote_exec "systemctl daemon-reload && systemctl enable --now ${timer_name}.timer" || {
    log_error "Failed to enable ${timer_name} timer"
    return 1
  }
}

# Deploy .service with template vars and enable. $1=service_name, $@=VAR=value
# Wrapper around deploy_template that also enables the service
deploy_systemd_service() {
  local service_name="$1"
  shift
  local template="templates/${service_name}.service"
  local dest="/etc/systemd/system/${service_name}.service"

  # Deploy using common function
  deploy_template "$template" "$dest" "$@" || return 1

  # Set proper permissions to avoid systemd warnings
  remote_exec "chmod 644 '$dest'" || {
    log_warn "Failed to set permissions on $dest"
  }

  remote_enable_services "${service_name}.service" || return 1
}

# Enable multiple systemd services (with daemon-reload). $@=service names
remote_enable_services() {
  local services=("$@")

  if [[ ${#services[@]} -eq 0 ]]; then
    return 0
  fi

  remote_exec "systemctl daemon-reload && systemctl enable --now ${services[*]}" || {
    log_error "Failed to enable services: ${services[*]}"
    return 1
  }
}
# shellcheck shell=bash
# User config deployment helpers

# Deploy config to admin home. Creates dirs, sets ownership, applies template vars.
# $1=template, $2=relative_path (e.g. ".config/bat/config"), $@=VAR=value (optional)
deploy_user_config() {
  require_admin_username "deploy user config" || return 1

  local template="$1"
  local relative_path="$2"
  shift 2
  local home_dir="/home/${ADMIN_USERNAME}"
  local dest="${home_dir}/${relative_path}"
  local dest_dir staged
  dest_dir="$(dirname "$dest")"

  # Stage template to temp location to preserve original
  staged=$(mktemp) || {
    log_error "Failed to create temp file for $template"
    return 1
  }
  register_temp_file "$staged"
  cp "$template" "$staged" || {
    log_error "Failed to stage template $template"
    rm -f "$staged"
    return 1
  }

  # Apply template vars (also validates no unsubstituted placeholders remain)
  apply_template_vars "$staged" "$@" || {
    log_error "Template substitution failed for $template"
    rm -f "$staged"
    return 1
  }

  # Create parent directory if needed (skip if deploying to home root)
  if [[ "$dest_dir" != "$home_dir" ]]; then
    remote_exec "mkdir -p '$dest_dir'" || {
      log_error "Failed to create directory $dest_dir"
      rm -f "$staged"
      return 1
    }
    # Fix ownership of ALL directories created by mkdir -p (they're created as root)
    # Walk up from dest_dir to home, collecting all intermediate directories
    local dirs_to_chown=""
    local dir="$dest_dir"
    while [[ "$dir" != "$home_dir" && "$dir" != "/" ]]; do
      # Escape single quotes in path for safe shell quoting
      local escaped_dir="${dir//\'/\'\\\'\'}"
      dirs_to_chown+="'$escaped_dir' "
      dir="$(dirname "$dir")"
    done
    [[ -n $dirs_to_chown ]] && {
      remote_exec "chown ${ADMIN_USERNAME}:${ADMIN_USERNAME} $dirs_to_chown" || {
        log_error "Failed to set ownership on $dirs_to_chown"
        rm -f "$staged"
        return 1
      }
    }
  fi

  # Copy file
  remote_copy "$staged" "$dest" || {
    log_error "Failed to copy $template to $dest"
    rm -f "$staged"
    return 1
  }
  rm -f "$staged"

  # Set ownership
  remote_exec "chown ${ADMIN_USERNAME}:${ADMIN_USERNAME} '$dest'" || {
    log_error "Failed to set ownership on $dest"
    return 1
  }
}

# Batch deploy configs to admin home. $@="template:relative_dest" pairs
deploy_user_configs() {
  for pair in "$@"; do
    local template="${pair%%:*}"
    local relative="${pair#*:}"
    deploy_user_config "$template" "$relative" || return 1
  done
}
# shellcheck shell=bash
# Network interfaces configuration - generates /etc/network/interfaces

# Generates loopback interface section
_generate_loopback() {
  cat <<'EOF'
auto lo
iface lo inet loopback

iface lo inet6 loopback
EOF
}

# Generates physical interface section (manual mode for bridges)
_generate_iface_manual() {
  cat <<EOF
# Physical interface (no IP, part of bridge)
auto ${INTERFACE_NAME}
iface ${INTERFACE_NAME} inet manual
EOF
}

# Generates physical interface with static IP (uses detected CIDR, falls back to /32)
# Adds pointopoint for /32 subnets where gateway is outside interface subnet
_generate_iface_static() {
  local ipv4_addr="${MAIN_IPV4_CIDR:-${MAIN_IPV4}/32}"
  local ipv6_addr="${IPV6_ADDRESS:-${IPV6_CIDR:-${MAIN_IPV6}/128}}"
  local ipv4_prefix="${ipv4_addr##*/}"
  local ipv6_prefix="${ipv6_addr##*/}"

  cat <<EOF
# Physical interface with host IP
auto ${INTERFACE_NAME}
iface ${INTERFACE_NAME} inet static
    address ${ipv4_addr}
EOF

  # For /32 subnets, gateway is outside interface subnet - add pointopoint route
  if [[ $ipv4_prefix == "32" ]]; then
    cat <<EOF
    pointopoint ${MAIN_IPV4_GW}
EOF
  fi

  cat <<EOF
    gateway ${MAIN_IPV4_GW}
    up sysctl --system
EOF

  # Add IPv6 if enabled (auto-detected or manual)
  if [[ ${IPV6_MODE:-} != "disabled" ]] && [[ -n ${MAIN_IPV6:-} || -n ${IPV6_ADDRESS:-} ]]; then
    local ipv6_gw="${IPV6_GATEWAY:-fe80::1}"
    # Translate "auto" to link-local default (Hetzner standard)
    [[ $ipv6_gw == "auto" ]] && ipv6_gw="fe80::1"
    cat <<EOF

iface ${INTERFACE_NAME} inet6 static
    address ${ipv6_addr}
    gateway ${ipv6_gw}
EOF
    # For /128 with non-link-local gateway, add explicit on-link route
    if [[ $ipv6_prefix == "128" && ! $ipv6_gw =~ ^fe80: ]]; then
      cat <<EOF
    up ip -6 route add ${ipv6_gw}/128 dev ${INTERFACE_NAME}
EOF
    fi
    cat <<EOF
    accept_ra 2
EOF
  fi
}

# Generates vmbr0 as external bridge with host IP (uses detected CIDR)
_generate_vmbr0_external() {
  local ipv4_addr="${MAIN_IPV4_CIDR:-${MAIN_IPV4}/32}"
  local ipv6_addr="${IPV6_ADDRESS:-${IPV6_CIDR:-${MAIN_IPV6}/128}}"
  local ipv4_prefix="${ipv4_addr##*/}"
  local ipv6_prefix="${ipv6_addr##*/}"
  local mtu="${BRIDGE_MTU:-1500}"

  cat <<EOF
# vmbr0: External bridge - VMs get IPs from router/DHCP
# Host IP is on this bridge
auto vmbr0
iface vmbr0 inet static
    address ${ipv4_addr}
EOF

  # For /32 subnets, gateway is outside interface subnet - add pointopoint route
  if [[ $ipv4_prefix == "32" ]]; then
    cat <<EOF
    pointopoint ${MAIN_IPV4_GW}
EOF
  fi

  cat <<EOF
    gateway ${MAIN_IPV4_GW}
    bridge-ports ${INTERFACE_NAME}
    bridge-stp off
    bridge-fd 0
    mtu ${mtu}
    up sysctl --system
EOF

  # Add IPv6 if enabled (auto-detected or manual)
  if [[ ${IPV6_MODE:-} != "disabled" ]] && [[ -n ${MAIN_IPV6:-} || -n ${IPV6_ADDRESS:-} ]]; then
    local ipv6_gw="${IPV6_GATEWAY:-fe80::1}"
    # Translate "auto" to link-local default (Hetzner standard)
    [[ $ipv6_gw == "auto" ]] && ipv6_gw="fe80::1"
    cat <<EOF

iface vmbr0 inet6 static
    address ${ipv6_addr}
    gateway ${ipv6_gw}
EOF
    # For /128 with non-link-local gateway, add explicit on-link route
    if [[ $ipv6_prefix == "128" && ! $ipv6_gw =~ ^fe80: ]]; then
      cat <<EOF
    up ip -6 route add ${ipv6_gw}/128 dev vmbr0
EOF
    fi
    cat <<EOF
    accept_ra 2
EOF
  fi
}

# Generates vmbr0 as NAT bridge (private network for VMs)
_generate_vmbr0_nat() {
  local mtu="${BRIDGE_MTU:-9000}"
  local private_ip="${PRIVATE_IP_CIDR:-10.0.0.1/24}"

  local mtu_comment=""
  [[ $mtu -gt 1500 ]] && mtu_comment=" (jumbo frames for improved VM-to-VM performance)"

  cat <<EOF
# vmbr0: Private NAT network for VMs
# All VMs connect here and access internet via NAT${mtu_comment}
auto vmbr0
iface vmbr0 inet static
    address ${private_ip}
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    mtu ${mtu}
EOF

  # Add IPv6 if enabled
  if [[ -n ${FIRST_IPV6_CIDR:-} && ${IPV6_MODE:-} != "disabled" ]]; then
    cat <<EOF

iface vmbr0 inet6 static
    address ${FIRST_IPV6_CIDR}
EOF
  fi
}

# Generates vmbr1 as secondary NAT bridge
_generate_vmbr1_nat() {
  local mtu="${BRIDGE_MTU:-9000}"
  local private_ip="${PRIVATE_IP_CIDR:-10.0.0.1/24}"

  local mtu_comment=""
  [[ $mtu -gt 1500 ]] && mtu_comment=" (jumbo frames for improved VM-to-VM performance)"

  cat <<EOF
# vmbr1: Private NAT network for VMs
# VMs connect here for isolated network with NAT to internet${mtu_comment}
auto vmbr1
iface vmbr1 inet static
    address ${private_ip}
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    mtu ${mtu}
EOF

  # Add IPv6 if enabled
  if [[ -n ${FIRST_IPV6_CIDR:-} && ${IPV6_MODE:-} != "disabled" ]]; then
    cat <<EOF

iface vmbr1 inet6 static
    address ${FIRST_IPV6_CIDR}
EOF
  fi
}

# Generates complete /etc/network/interfaces content
# Uses: BRIDGE_MODE, INTERFACE_NAME, MAIN_IPV4, MAIN_IPV4_GW, MAIN_IPV6, etc.
_generate_interfaces_conf() {
  local mode="${BRIDGE_MODE:-internal}"

  cat <<'EOF'
# network interface settings; autogenerated
# Please do NOT modify this file directly, unless you know what
# you're doing.
#
# If you want to manage parts of the network configuration manually,
# please utilize the 'source' or 'source-directory' directives to do
# so.
# PVE will preserve these directives, but will NOT read its network
# configuration from sourced files, so do not attempt to move any of
# the PVE managed interfaces into external files!

source /etc/network/interfaces.d/*

EOF

  _generate_loopback
  echo ""

  case "$mode" in
    internal)
      # Host IP on physical interface, vmbr0 for NAT
      _generate_iface_static
      echo ""
      _generate_vmbr0_nat
      ;;
    external)
      # Physical interface manual, host IP on vmbr0 bridge
      _generate_iface_manual
      echo ""
      _generate_vmbr0_external
      ;;
    both)
      # Physical interface manual, vmbr0 for external, vmbr1 for NAT
      _generate_iface_manual
      echo ""
      _generate_vmbr0_external
      echo ""
      _generate_vmbr1_nat
      ;;
    *)
      # Fallback to static config if invalid mode - ensures network connectivity
      log_warn "Unknown BRIDGE_MODE '${mode}', falling back to static config"
      _generate_iface_static
      echo ""
      _generate_vmbr0_nat
      ;;
  esac
}

# Generate interfaces config to file. $1=output_path
generate_interfaces_file() {
  local output="${1:-./templates/interfaces}"
  _generate_interfaces_conf >"$output" || return 1
  log_info "Generated interfaces config (mode: ${BRIDGE_MODE:-internal})"
}
# shellcheck shell=bash
# Basic validation functions (hostname, user, email, password)

# Guard for functions that require ADMIN_USERNAME. $1=context (optional)
require_admin_username() {
  if [[ -z ${ADMIN_USERNAME:-} ]]; then
    log_error "ADMIN_USERNAME is empty${1:+, cannot $1}"
    return 1
  fi
}

# Validate hostname format. $1=hostname
validate_hostname() {
  local hostname="$1"
  # Reject reserved hostname "localhost"
  [[ ${hostname,,} == "localhost" ]] && return 1
  # Hostname: alphanumeric and hyphens, 1-63 chars, cannot start/end with hyphen
  [[ $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]
}

# Validate admin username (lowercase, starts with letter, 1-32 chars). $1=username
validate_admin_username() {
  local username="$1"

  # Must be lowercase alphanumeric, can contain underscore/hyphen, 1-32 chars
  # Must start with a letter
  [[ ! $username =~ ^[a-z][a-z0-9_-]{0,31}$ ]] && return 1

  # Block reserved system usernames
  case "$username" in
    root | nobody | daemon | bin | sys | sync | games | man | lp | mail | \
      news | uucp | proxy | www-data | backup | list | irc | gnats | \
      sshd | systemd-network | systemd-resolve | messagebus | \
      polkitd | postfix | syslog | _apt | tss | uuidd | avahi | colord | \
      cups-pk-helper | dnsmasq | geoclue | hplip | kernoops | lightdm | \
      nm-openconnect | nm-openvpn | pulse | rtkit | saned | speech-dispatcher | \
      whoopsie | admin | administrator | operator | guest)
      return 1
      ;;
  esac

  return 0
}

# Validate FQDN format. $1=fqdn
validate_fqdn() {
  local fqdn="$1"
  # FQDN: valid hostname labels separated by dots
  [[ $fqdn =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]]
}

# Validate email format. $1=email
validate_email() {
  local email="$1"
  # Basic email validation
  [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

# Validate SMTP host (hostname, FQDN, or IP). $1=host
validate_smtp_host() {
  local host="$1"
  [[ -z $host ]] && return 1
  # Accept: hostname, FQDN, IPv4, or IPv6
  # Relaxed: alphanumeric, dots, hyphens, colons (IPv6), brackets
  # Note: ] must be first in class, - must be last for literal matching
  [[ $host =~ ^[][a-zA-Z0-9.:-]+$ ]] && [[ ${#host} -le 253 ]]
}

# Validate SMTP port (1-65535). $1=port
validate_smtp_port() {
  local port="$1"
  [[ $port =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535))
}

# Validate non-empty string. $1=string
validate_not_empty() {
  [[ -n $1 ]]
}

# Check if string is ASCII printable. $1=string
is_ascii_printable() {
  local LC_ALL=C
  [[ $1 =~ ^[[:print:]]+$ ]]
}

# Get password error message (empty if valid). $1=password → error_msg
get_password_error() {
  local password="$1"
  if [[ -z $password ]]; then
    printf '%s\n' "Password cannot be empty!"
  elif [[ ${#password} -lt 8 ]]; then
    printf '%s\n' "Password must be at least 8 characters long."
  elif ! is_ascii_printable "$password"; then
    printf '%s\n' "Password contains invalid characters (Cyrillic or non-ASCII). Only Latin letters, digits, and special characters are allowed."
  fi
}

# Check if boot disk conflicts with pool disks. Returns 0=conflict, 1=ok
validate_pool_disk_conflict() {
  [[ -z $BOOT_DISK ]] && return 1
  for disk in "${ZFS_POOL_DISKS[@]}"; do
    [[ $disk == "$BOOT_DISK" ]] && return 0
  done
  return 1
}

# Check if RAID mode matches disk count. Returns 0=mismatch, 1=ok
validate_raid_disk_count() {
  local pool_count="${#ZFS_POOL_DISKS[@]}"
  case "$ZFS_RAID" in
    single) [[ $pool_count -ne 1 ]] && return 0 ;;
    raid0 | raid1) [[ $pool_count -lt 2 ]] && return 0 ;;
    raidz1) [[ $pool_count -lt 3 ]] && return 0 ;;
    raid10 | raidz2) [[ $pool_count -lt 4 ]] && return 0 ;;
    raidz3) [[ $pool_count -lt 5 ]] && return 0 ;;
  esac
  return 1
}

# Get required disk count for RAID mode. $1=raid_mode → count
get_raid_min_disks() {
  case "$1" in
    single) echo 1 ;;
    raid0 | raid1) echo 2 ;;
    raidz1) echo 3 ;;
    raid10 | raidz2) echo 4 ;;
    raidz3) echo 5 ;;
    *) echo 1 ;;
  esac
}
# shellcheck shell=bash
# Network validation functions (subnet, IPv6)

# Validate subnet CIDR. $1=subnet
validate_subnet() {
  local subnet="$1"
  # Validate CIDR notation (e.g., 10.0.0.0/24)
  if [[ ! $subnet =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]]; then
    return 1
  fi
  # Validate each octet is 0-255 using parameter expansion
  local ip="${subnet%/*}"
  local octet1 octet2 octet3 octet4 temp
  octet1="${ip%%.*}"
  temp="${ip#*.}"
  octet2="${temp%%.*}"
  temp="${temp#*.}"
  octet3="${temp%%.*}"
  octet4="${temp#*.}"

  # Use 10# prefix to force base-10 interpretation (prevents 08/09 octal errors)
  # shellcheck disable=SC2309 # arithmetic comparison is intentional
  [[ 10#$octet1 -le 255 && 10#$octet2 -le 255 && 10#$octet3 -le 255 && 10#$octet4 -le 255 ]]
}

# IPv6 validation functions

# Validate IPv6 address. $1=ipv6
validate_ipv6() {
  local ipv6="$1"

  # Empty check
  [[ -z $ipv6 ]] && return 1

  # Remove zone ID if present (e.g., %eth0)
  ipv6="${ipv6%%\%*}"

  # Check for valid characters
  [[ ! $ipv6 =~ ^[0-9a-fA-F:]+$ ]] && return 1

  # Cannot start or end with single colon (but :: is valid)
  [[ $ipv6 =~ ^:[^:] ]] && return 1
  [[ $ipv6 =~ [^:]:$ ]] && return 1

  # Reject three or more consecutive colons (invalid)
  [[ $ipv6 =~ ::: ]] && return 1

  # Cannot have more than one :: sequence (pure bash: count by removal)
  local temp="${ipv6//::/}"
  local double_colon_count="$(((${#ipv6} - ${#temp}) / 2))"
  [[ $double_colon_count -gt 1 ]] && return 1

  # Count groups using pure bash (split by :, accounting for ::)
  local groups left_count=0 right_count=0 colons
  if [[ $ipv6 == *"::"* ]]; then
    # With :: compression, count actual groups via colon count
    local left="${ipv6%%::*}"
    local right="${ipv6##*::}"
    if [[ -n $left ]]; then
      colons="${left//[!:]/}"
      left_count="$((${#colons} + 1))"
    fi
    if [[ -n $right ]]; then
      colons="${right//[!:]/}"
      right_count="$((${#colons} + 1))"
    fi
    groups="$((left_count + right_count))"
    # Total groups must be less than 8 (:: fills the rest)
    [[ $groups -ge 8 ]] && return 1
  else
    # Without compression, must have exactly 8 groups (7 colons)
    colons="${ipv6//[!:]/}"
    [[ ${#colons} -ne 7 ]] && return 1
  fi

  # Validate each group (1-4 hex digits) using IFS splitting
  local group IFS=':'
  # shellcheck disable=SC2086
  set -- $ipv6
  for group in "$@"; do
    [[ -z $group ]] && continue
    [[ ${#group} -gt 4 ]] && return 1
    [[ ! $group =~ ^[0-9a-fA-F]+$ ]] && return 1
  done

  return 0
}

# Validate IPv6/CIDR. $1=ipv6_cidr
validate_ipv6_cidr() {
  local ipv6_cidr="$1"

  # Check for CIDR format
  [[ ! $ipv6_cidr =~ ^.+/[0-9]+$ ]] && return 1

  local ipv6="${ipv6_cidr%/*}"
  local prefix="${ipv6_cidr##*/}"

  # Validate prefix length (0-128)
  [[ ! $prefix =~ ^[0-9]+$ ]] && return 1
  [[ $prefix -lt 0 || $prefix -gt 128 ]] && return 1

  # Validate IPv6 address
  validate_ipv6 "$ipv6"
}

# Validate IPv6 gateway (empty, "auto", or IPv6). $1=gateway
validate_ipv6_gateway() {
  local gateway="$1"

  # Empty is valid (no IPv6 gateway)
  [[ -z $gateway ]] && return 0

  # Special value "auto" means use link-local
  [[ $gateway == "auto" ]] && return 0

  # Validate as IPv6 address
  validate_ipv6 "$gateway"
}
# shellcheck shell=bash
# DNS validation functions

# Extract IPv4 address from text. Returns first valid IPv4 found.
_extract_ipv4() {
  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1
}

# Parse dig output for A record. Handles CNAME chains and various formats.
_parse_dig_output() {
  local output="$1"
  local ip=""
  # Primary: dig +short returns IPs directly (may have CNAMEs first)
  ip=$(printf '%s\n' "$output" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
  # Fallback: extract any IPv4 from output
  [[ -z $ip ]] && ip=$(printf '%s\n' "$output" | _extract_ipv4)
  printf '%s' "$ip"
}

# Parse host output for A record. Handles different locales and formats.
_parse_host_output() {
  local output="$1"
  local ip=""
  # Primary: "hostname has address x.x.x.x"
  ip=$(printf '%s\n' "$output" | grep -i "has address" | head -1 | awk '{print $NF}')
  # Fallback: "hostname A x.x.x.x" or similar
  [[ -z $ip ]] && ip=$(printf '%s\n' "$output" | grep -iE '(^|\s)A\s' | head -1 | _extract_ipv4)
  # Last resort: any IPv4 after the first line (skip server info)
  [[ -z $ip ]] && ip=$(printf '%s\n' "$output" | tail -n +2 | _extract_ipv4)
  printf '%s' "$ip"
}

# Parse nslookup output for A record. Handles BSD/GNU/busybox variations.
_parse_nslookup_output() {
  local output="$1"
  local ip=""
  # Skip the server info section, look for Address without port (#)
  ip=$(printf '%s\n' "$output" | awk '/^Address:/ && !/#/ {print $2; exit}')
  # Fallback: look for "Address: x.x.x.x" without port anywhere
  [[ -z $ip ]] && ip=$(printf '%s\n' "$output" | grep -E '^Address:\s*[0-9]' | grep -v '#' | head -1 | awk '{print $2}')
  # Fallback: "Name:...Address:" pattern (some nslookup versions)
  [[ -z $ip ]] && ip=$(printf '%s\n' "$output" | awk '/^Name:/{found=1} found && /^Address:/{print $2; exit}')
  # Last resort: any IPv4 after "Non-authoritative" or "Name:" line
  [[ -z $ip ]] && ip=$(printf '%s\n' "$output" | sed -n '/Non-authoritative\|^Name:/,$p' | _extract_ipv4)
  printf '%s' "$ip"
}

# Parse getent ahosts output. Handles different formats.
_parse_getent_output() {
  local output="$1"
  local ip=""
  # Primary: "x.x.x.x STREAM hostname"
  ip=$(printf '%s\n' "$output" | grep -i 'STREAM' | head -1 | awk '{print $1}')
  # Fallback: first IPv4 in output
  [[ -z $ip ]] && ip=$(printf '%s\n' "$output" | _extract_ipv4)
  printf '%s' "$ip"
}

# Validate FQDN resolves to IP. $1=fqdn, $2=expected_ip. Sets DNS_RESOLVED_IP.
# Returns: 0=match, 1=no resolution, 2=wrong IP
validate_dns_resolution() {
  local fqdn="$1"
  local expected_ip="$2"
  local resolved_ip=""
  local dns_timeout="${DNS_LOOKUP_TIMEOUT:-5}" # Default 5 second timeout
  local retry_delay="${DNS_RETRY_DELAY:-10}"   # Default 10 second delay between retries
  local max_attempts=3

  # Determine which DNS tool to use (check once, not in loop)
  local dns_tool=""
  if cmd_exists dig; then
    dns_tool="dig"
  elif cmd_exists host; then
    dns_tool="host"
  elif cmd_exists nslookup; then
    dns_tool="nslookup"
  fi

  # If no DNS tool available, log warning and return no resolution
  if [[ -z $dns_tool ]]; then
    log_warn "No DNS lookup tool available (dig, host, or nslookup)"
    declare -g DNS_RESOLVED_IP=""
    return 1
  fi

  # Retry loop for DNS resolution
  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    resolved_ip=""

    # Try each public DNS server until we get a result (use global DNS_SERVERS)
    local raw_output=""
    for dns_server in "${DNS_SERVERS[@]}"; do
      case "$dns_tool" in
        dig)
          # Use outer timeout only to avoid conflicting timeout values
          raw_output=$(timeout "$dns_timeout" dig +short +tries=1 A "$fqdn" "@${dns_server}" 2>/dev/null)
          resolved_ip=$(_parse_dig_output "$raw_output")
          ;;
        host)
          # Use outer timeout only to avoid conflicting timeout values
          raw_output=$(timeout "$dns_timeout" host -t A "$fqdn" "$dns_server" 2>/dev/null)
          resolved_ip=$(_parse_host_output "$raw_output")
          ;;
        nslookup)
          # Use outer timeout only to avoid conflicting timeout values
          raw_output=$(timeout "$dns_timeout" nslookup "$fqdn" "$dns_server" 2>/dev/null)
          resolved_ip=$(_parse_nslookup_output "$raw_output")
          ;;
      esac

      if [[ -n $resolved_ip ]]; then
        break
      fi
    done

    # Fallback to system resolver if public DNS fails
    if [[ -z $resolved_ip ]]; then
      case "$dns_tool" in
        dig)
          raw_output=$(timeout "$dns_timeout" dig +short +tries=1 A "$fqdn" 2>/dev/null)
          resolved_ip=$(_parse_dig_output "$raw_output")
          ;;
        *)
          if cmd_exists getent; then
            raw_output=$(timeout "$dns_timeout" getent ahosts "$fqdn" 2>/dev/null)
            resolved_ip=$(_parse_getent_output "$raw_output")
          fi
          ;;
      esac
    fi

    # If we got a result, process it
    if [[ -n $resolved_ip ]]; then
      declare -g DNS_RESOLVED_IP="$resolved_ip"
      if [[ $resolved_ip == "$expected_ip" ]]; then
        return 0 # Match
      else
        return 2 # Wrong IP
      fi
    fi

    # No resolution on this attempt
    if [[ $attempt -lt $max_attempts ]]; then
      log_warn "DNS lookup for $fqdn failed (attempt $attempt/$max_attempts), retrying in ${retry_delay}s..."
      sleep "$retry_delay"
    fi
  done

  # All attempts failed
  log_error "Failed to resolve $fqdn after $max_attempts attempts"
  declare -g DNS_RESOLVED_IP=""
  return 1 # No resolution
}
# shellcheck shell=bash
# Security validation functions (SSH key, Tailscale, disk space)

# Validate SSH public key format and security. $1=key
validate_ssh_key_secure() {
  local key="$1"

  # Validate and get key info in single ssh-keygen call
  local key_info
  if ! key_info=$(echo "$key" | ssh-keygen -l -f - 2>/dev/null); then
    log_error "Invalid SSH public key format"
    return 1
  fi

  # Parse bits from cached output (first field)
  local bits
  bits=$(echo "$key_info" | awk '{print $1}')

  # Check key type is secure (no DSA/RSA <2048)
  local key_type
  key_type=$(echo "$key" | awk '{print $1}')

  case "$key_type" in
    ssh-ed25519)
      log_info "SSH key validated (ED25519)"
      return 0
      ;;
    ecdsa-*)
      # ECDSA keys report curve size (256, 384, 521), not RSA-equivalent bits
      # ECDSA-256 is equivalent to ~3072-bit RSA, so all standard curves are secure
      if [[ $bits -ge 256 ]]; then
        log_info "SSH key validated ($key_type, $bits bits)"
        return 0
      fi
      log_error "ECDSA key curve too small (current: $bits)"
      return 1
      ;;
    ssh-rsa)
      if [[ $bits -ge 2048 ]]; then
        log_info "SSH key validated ($key_type, $bits bits)"
        return 0
      fi
      log_error "RSA key must be >= 2048 bits (current: $bits)"
      return 1
      ;;
    *)
      log_error "Unsupported key type: $key_type"
      return 1
      ;;
  esac
}

# Disk space validation

# Validate disk space. $1=path, $2=min_mb. Sets DISK_SPACE_MB global.
validate_disk_space() {
  local path="${1:-/root}"
  local min_required_mb="${2:-${MIN_DISK_SPACE_MB}}"
  local available_mb

  # Get available space in MB
  available_mb=$(df -m "$path" 2>/dev/null | awk 'NR==2 {print $4}')

  if [[ -z $available_mb ]]; then
    log_error "Could not determine disk space for $path"
    return 1
  fi

  declare -g DISK_SPACE_MB="$available_mb"

  if [[ $available_mb -lt $min_required_mb ]]; then
    log_error "Insufficient disk space: ${available_mb}MB available, ${min_required_mb}MB required"
    return 1
  fi

  log_info "Disk space OK: ${available_mb}MB available (${min_required_mb}MB required)"
  return 0
}

# Validate Tailscale auth key format. $1=key
validate_tailscale_key() {
  local key="$1"

  [[ -z $key ]] && return 1

  # Must start with tskey-auth- or tskey-client-
  # Followed by alphanumeric ID, dash, and alphanumeric secret
  if [[ $key =~ ^tskey-(auth|client)-[a-zA-Z0-9]+-[a-zA-Z0-9]+$ ]]; then
    return 0
  fi

  return 1
}
# shellcheck shell=bash
# System package installation

# Check if ZFS is actually functional (not just wrapper script)
_zfs_functional() {
  # zpool version exits 0 and shows version if ZFS is compiled/loaded
  zpool version &>/dev/null
}

# Install ZFS if needed (rescue scripts or apt fallback)
_install_zfs_if_needed() {
  # Check if ZFS is actually working, not just wrapper exists
  if _zfs_functional; then
    log_info "ZFS already installed and functional"
    return 0
  fi

  log_info "ZFS not functional, attempting installation..."

  # Hetzner rescue: zpool command is a wrapper that compiles ZFS on first run
  # Need to run it with 'y' to accept license (timeout 90s for compilation)
  if cmd_exists zpool; then
    log_info "Found zpool wrapper, triggering ZFS compilation..."
    timeout 90 bash -c 'echo "y" | zpool version' &>/dev/null || true
    if _zfs_functional; then
      log_info "ZFS compiled successfully via wrapper"
      return 0
    fi
  fi

  # Common rescue system ZFS install scripts (auto-accept prompts)
  local install_dir="${INSTALL_DIR:-${HOME:-/root}}"
  local zfs_scripts=(
    "${install_dir}/.oldroot/nfs/install/zfs.sh" # Hetzner
    "${install_dir}/zfs-install.sh"              # Generic
    "/usr/local/bin/install-zfs"                 # Some providers
  )

  for script in "${zfs_scripts[@]}"; do
    if [[ -x $script ]]; then
      log_info "Running ZFS install script: $script"
      # shellcheck disable=SC2016
      timeout 90 bash -c 'echo "y" | "$1"' _ "$script" >/dev/null 2>&1 || true
      if _zfs_functional; then
        log_info "ZFS installed successfully via $script"
        return 0
      fi
    fi
  done

  # Fallback: try apt on Debian-based systems (timeout 120s)
  if [[ -f /etc/debian_version ]]; then
    log_info "Trying apt install zfsutils-linux..."
    timeout 120 apt-get install -qq -y zfsutils-linux >/dev/null 2>&1 || true
    if _zfs_functional; then
      log_info "ZFS installed via apt"
      return 0
    fi
  fi

  log_warn "Failed to install ZFS - existing pool detection unavailable"
}

# Install required packages (aria2c, jq, gum, etc.)
_install_required_packages() {
  local -A required_commands=(
    [column]="bsdmainutils"
    [ip]="iproute2"
    [udevadm]="udev"
    [timeout]="coreutils"
    [curl]="curl"
    [jq]="jq"
    [aria2c]="aria2"
    [findmnt]="util-linux"
    [gpg]="gnupg"
    [xargs]="findutils"
    [gum]="gum"
  )

  local packages_to_install=()
  local need_charm_repo=false

  for cmd in "${!required_commands[@]}"; do
    if ! cmd_exists "$cmd"; then
      packages_to_install+=("${required_commands[$cmd]}")
      [[ $cmd == "gum" ]] && need_charm_repo=true
    fi
  done

  if [[ $need_charm_repo == true ]]; then
    mkdir -p /etc/apt/keyrings 2>/dev/null
    curl -fsSL https://repo.charm.sh/apt/gpg.key 2>/dev/null | gpg --dearmor -o /etc/apt/keyrings/charm.gpg >/dev/null 2>&1
    printf '%s\n' "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" >/etc/apt/sources.list.d/charm.list 2>/dev/null
  fi

  if [[ ${#packages_to_install[@]} -gt 0 ]]; then
    apt-get update -qq >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive timeout 120 apt-get install -qq -y "${packages_to_install[@]}" >/dev/null 2>&1
  fi

  # Install ZFS for pool detection (needed for existing pool feature)
  _install_zfs_if_needed
}

# Install all base system packages in one batch
install_base_packages() {
  # shellcheck disable=SC2206
  local packages=(${SYSTEM_UTILITIES} ${OPTIONAL_PACKAGES} usrmerge locales chrony unattended-upgrades apt-listchanges linux-cpupower)
  # Add ZSH packages if needed
  [[ ${SHELL_TYPE:-bash} == "zsh" ]] && packages+=(zsh git)
  local pkg_list && printf -v pkg_list '"%s" ' "${packages[@]}"
  log_info "Installing base packages: ${packages[*]}"
  remote_run "Installing system packages" "
    set -e
    export DEBIAN_FRONTEND=noninteractive
    # Wait for apt locks (max 5 min)
    waited=0
    while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock >/dev/null 2>&1; do
      [ \$waited -ge 300 ] && { echo 'ERROR: Timeout waiting for apt lock' >&2; exit 1; }
      sleep 2; waited=\$((waited + 2))
    done
    apt-get update -qq
    apt-get dist-upgrade -yqq
    apt-get install -yqq ${pkg_list}
    apt-get autoremove -yqq
    apt-get clean
    set +e
    pveupgrade 2>/dev/null || echo 'pveupgrade check skipped' >&2
    pveam update 2>/dev/null || echo 'pveam update skipped' >&2
  " "System packages installed"
  # Show installed packages as subtasks
  log_subtasks "${packages[@]}"
}

# Collect and install all feature packages in one batch
batch_install_packages() {
  local packages=()
  # Security packages
  [[ $INSTALL_FIREWALL == "yes" ]] && packages+=(nftables)
  if [[ $INSTALL_FIREWALL == "yes" && ${FIREWALL_MODE:-standard} != "stealth" ]]; then
    packages+=(fail2ban)
  fi
  [[ $INSTALL_APPARMOR == "yes" ]] && packages+=(apparmor apparmor-utils)
  [[ $INSTALL_AUDITD == "yes" ]] && packages+=(auditd audispd-plugins)
  [[ $INSTALL_AIDE == "yes" ]] && packages+=(aide aide-common)
  [[ $INSTALL_CHKROOTKIT == "yes" ]] && packages+=(chkrootkit binutils)
  [[ $INSTALL_LYNIS == "yes" ]] && packages+=(lynis)
  [[ $INSTALL_NEEDRESTART == "yes" ]] && packages+=(needrestart)
  # Monitoring packages
  [[ $INSTALL_VNSTAT == "yes" ]] && packages+=(vnstat)
  [[ $INSTALL_PROMTAIL == "yes" ]] && packages+=(promtail)
  [[ $INSTALL_NETDATA == "yes" ]] && packages+=(netdata)
  # Tools packages
  [[ $INSTALL_NVIM == "yes" ]] && packages+=(neovim)
  [[ $INSTALL_RINGBUFFER == "yes" ]] && packages+=(ethtool)
  [[ $INSTALL_YAZI == "yes" ]] && packages+=(yazi ffmpeg 7zip jq poppler-utils fd-find ripgrep fzf zoxide imagemagick)
  # Tailscale (needs custom repo)
  [[ $INSTALL_TAILSCALE == "yes" ]] && packages+=(tailscale)
  # SSL packages
  [[ ${SSL_TYPE:-self-signed} == "letsencrypt" ]] && packages+=(certbot)
  if [[ ${#packages[@]} -eq 0 ]]; then
    log_info "No optional packages to install"
    return 0
  fi

  local pkg_list && printf -v pkg_list '"%s" ' "${packages[@]}"
  log_info "Batch installing packages: ${packages[*]}"

  # Build repo setup commands (detect Debian codename dynamically for future releases)
  # shellcheck disable=SC2016
  local repo_setup='
    DEBIAN_CODENAME=$(grep -oP "VERSION_CODENAME=\K\w+" /etc/os-release 2>/dev/null || echo "bookworm")
  '

  if [[ $INSTALL_TAILSCALE == "yes" ]]; then
    # shellcheck disable=SC2016
    repo_setup+='
      curl -fsSL "https://pkgs.tailscale.com/stable/debian/${DEBIAN_CODENAME}.noarmor.gpg" | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
      curl -fsSL "https://pkgs.tailscale.com/stable/debian/${DEBIAN_CODENAME}.tailscale-keyring.list" | tee /etc/apt/sources.list.d/tailscale.list
    '
  fi

  if [[ $INSTALL_NETDATA == "yes" ]]; then
    # shellcheck disable=SC2016
    repo_setup+='
      curl -fsSL https://repo.netdata.cloud/netdatabot.gpg.key | gpg --dearmor -o /usr/share/keyrings/netdata-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/netdata-archive-keyring.gpg] https://repo.netdata.cloud/repos/stable/debian/ ${DEBIAN_CODENAME}/" > /etc/apt/sources.list.d/netdata.list
    '
  fi

  if [[ $INSTALL_PROMTAIL == "yes" ]]; then
    repo_setup+='
      curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor -o /usr/share/keyrings/grafana-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/grafana-archive-keyring.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list
    '
  fi

  if [[ $INSTALL_YAZI == "yes" ]]; then
    # shellcheck disable=SC2016
    repo_setup+='
      curl -fsSL https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpg
      echo "deb https://debian.griffo.io/apt ${DEBIAN_CODENAME} main" > /etc/apt/sources.list.d/debian.griffo.io.list
    '
  fi

  # remote_run exits on failure, so no need for error handling here
  # shellcheck disable=SC2086,SC2016
  remote_run "Installing packages (${#packages[@]})" '
      set -e
      export DEBIAN_FRONTEND=noninteractive
      # Wait for apt locks (max 5 min)
      waited=0
      while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock >/dev/null 2>&1; do
        [ $waited -ge 300 ] && { echo "ERROR: Timeout waiting for apt lock" >&2; exit 1; }
        sleep 2; waited=$((waited + 2))
      done
      '"$repo_setup"'
      apt-get update -qq
      apt-get install -yqq '"${pkg_list}"'
    ' "Packages installed"

  # Show installed packages as subtasks
  log_subtasks "${packages[@]}"
  return 0
}
# shellcheck shell=bash
# System preflight checks (root, internet, disk, RAM, CPU, KVM)

# Check root access. Sets PREFLIGHT_ROOT*.
_check_root_access() {
  if [[ $EUID -ne 0 ]]; then
    declare -g PREFLIGHT_ROOT="✗ Not root"
    declare -g PREFLIGHT_ROOT_STATUS="error"
    return 1
  else
    declare -g PREFLIGHT_ROOT="Running as root"
    declare -g PREFLIGHT_ROOT_STATUS="ok"
    return 0
  fi
}

# Check internet connectivity. Sets PREFLIGHT_NET*.
_check_internet() {
  if ping -c 1 -W 3 "$DNS_PRIMARY" >/dev/null 2>&1; then
    declare -g PREFLIGHT_NET="Available"
    declare -g PREFLIGHT_NET_STATUS="ok"
    return 0
  else
    declare -g PREFLIGHT_NET="No connection"
    declare -g PREFLIGHT_NET_STATUS="error"
    return 1
  fi
}

# Check disk space. Sets PREFLIGHT_DISK*.
_check_disk_space() {
  if validate_disk_space "/root" "$MIN_DISK_SPACE_MB"; then
    declare -g PREFLIGHT_DISK="${DISK_SPACE_MB} MB"
    declare -g PREFLIGHT_DISK_STATUS="ok"
    return 0
  else
    declare -g PREFLIGHT_DISK="${DISK_SPACE_MB:-0} MB (need ${MIN_DISK_SPACE_MB}MB+)"
    declare -g PREFLIGHT_DISK_STATUS="error"
    return 1
  fi
}

# Check RAM. Sets PREFLIGHT_RAM*.
_check_ram() {
  local total_ram_mb
  total_ram_mb=$(free -m | awk '/^Mem:/{print $2}')
  if [[ $total_ram_mb -ge $MIN_RAM_MB ]]; then
    declare -g PREFLIGHT_RAM="${total_ram_mb} MB"
    declare -g PREFLIGHT_RAM_STATUS="ok"
    return 0
  else
    declare -g PREFLIGHT_RAM="${total_ram_mb} MB (need ${MIN_RAM_MB}MB+)"
    declare -g PREFLIGHT_RAM_STATUS="error"
    return 1
  fi
}

# Check CPU cores. Sets PREFLIGHT_CPU*.
_check_cpu() {
  local cpu_cores
  cpu_cores=$(nproc)
  if [[ $cpu_cores -ge 2 ]]; then
    declare -g PREFLIGHT_CPU="${cpu_cores} cores"
    declare -g PREFLIGHT_CPU_STATUS="ok"
  else
    declare -g PREFLIGHT_CPU="${cpu_cores} core(s)"
    declare -g PREFLIGHT_CPU_STATUS="warn"
  fi
}

# Check KVM, load modules if needed. Sets PREFLIGHT_KVM*.
_check_kvm() {
  if [[ ! -e /dev/kvm ]]; then
    modprobe kvm 2>/dev/null || true

    if grep -q "Intel" /proc/cpuinfo 2>/dev/null; then
      modprobe kvm_intel 2>/dev/null || true
    elif grep -q "AMD" /proc/cpuinfo 2>/dev/null; then
      modprobe kvm_amd 2>/dev/null || true
    else
      modprobe kvm_intel 2>/dev/null || modprobe kvm_amd 2>/dev/null || true
    fi

    # Wait for /dev/kvm to appear (up to 3 seconds)
    local retries=6
    while [[ ! -e /dev/kvm && $retries -gt 0 ]]; do
      sleep 0.5
      ((retries--))
    done
  fi

  if [[ -e /dev/kvm ]]; then
    declare -g PREFLIGHT_KVM="Available"
    declare -g PREFLIGHT_KVM_STATUS="ok"
    return 0
  else
    declare -g PREFLIGHT_KVM="Not available"
    declare -g PREFLIGHT_KVM_STATUS="error"
    return 1
  fi
}

# Run all preflight checks. Sets PREFLIGHT_* variables.
_run_preflight_checks() {
  local errors=0

  _check_root_access || ((errors++))
  _check_internet || ((errors++))
  _check_disk_space || ((errors++))
  _check_ram || ((errors++))
  _check_cpu
  _check_kvm || ((errors++))

  declare -g PREFLIGHT_ERRORS="$errors"
}

# Main collection function

# Collect system info and run preflight checks
collect_system_info() {
  # Install required tools
  _install_required_packages

  # Run preflight checks
  _run_preflight_checks

  # Detect network interface
  _detect_default_interface
  _detect_predictable_name
  _detect_available_interfaces

  # Collect IP information
  if ! _detect_ipv4; then
    log_warn "IPv4 detection failed - network config will require manual configuration"
  fi
  _detect_ipv6_and_mac

  # Load dynamic data for wizard
  _load_wizard_data
}
# shellcheck shell=bash
# Network interface and IP detection

# Detect default network interface. Sets CURRENT_INTERFACE.
_detect_default_interface() {
  if cmd_exists ip && cmd_exists jq; then
    declare -g CURRENT_INTERFACE="$(ip -j route 2>/dev/null | jq -r '.[] | select(.dst == "default") | .dev' | head -n1)"
  elif cmd_exists ip; then
    declare -g CURRENT_INTERFACE="$(ip route | grep default | awk '{print $5}' | head -n1)"
  elif cmd_exists route; then
    declare -g CURRENT_INTERFACE="$(route -n | awk '/^0\.0\.0\.0/ {print $8}' | head -n1)"
  fi

  if [[ -z $CURRENT_INTERFACE ]]; then
    if cmd_exists ip && cmd_exists jq; then
      declare -g CURRENT_INTERFACE="$(ip -j link show 2>/dev/null | jq -r '.[] | select(.ifname != "lo" and .operstate == "UP") | .ifname' | head -n1)"
    elif cmd_exists ip; then
      declare -g CURRENT_INTERFACE="$(ip link show | awk -F': ' '/^[0-9]+:/ && !/lo:/ {print $2; exit}')"
    elif cmd_exists ifconfig; then
      declare -g CURRENT_INTERFACE="$(ifconfig -a | awk '/^[a-z]/ && !/^lo/ {print $1; exit}' | tr -d ':')"
    fi
  fi

  if [[ -z $CURRENT_INTERFACE ]]; then
    declare -g CURRENT_INTERFACE="eth0"
    log_warn "Could not detect network interface, defaulting to eth0"
  fi
}

# Get predictable interface name from udev. Sets PREDICTABLE_NAME, DEFAULT_INTERFACE.
# Prefers MAC-based naming (enx*) for maximum reliability across udev versions.
_detect_predictable_name() {
  declare -g PREDICTABLE_NAME=""

  if [[ -e "/sys/class/net/${CURRENT_INTERFACE}" ]]; then
    local udev_info
    udev_info=$(udevadm info "/sys/class/net/${CURRENT_INTERFACE}" 2>/dev/null)

    # Prefer MAC-based naming (enx*) - most reliable across different udev versions
    # Different kernels/udev can interpret SMBIOS slots differently (enp* vs ens*)
    # but MAC-based names are always consistent
    declare -g PREDICTABLE_NAME="$(printf '%s\n' "$udev_info" | grep "ID_NET_NAME_MAC=" | cut -d'=' -f2)"

    # Fallback to path-based if MAC naming unavailable
    if [[ -z $PREDICTABLE_NAME ]]; then
      declare -g PREDICTABLE_NAME="$(printf '%s\n' "$udev_info" | grep "ID_NET_NAME_PATH=" | cut -d'=' -f2)"
    fi

    if [[ -z $PREDICTABLE_NAME ]]; then
      declare -g PREDICTABLE_NAME="$(printf '%s\n' "$udev_info" | grep "ID_NET_NAME_ONBOARD=" | cut -d'=' -f2)"
    fi

    if [[ -z $PREDICTABLE_NAME ]]; then
      declare -g PREDICTABLE_NAME="$(ip -d link show "$CURRENT_INTERFACE" 2>/dev/null | grep "altname" | awk '{print $2}' | head -1)"
    fi
  fi

  if [[ -n $PREDICTABLE_NAME ]]; then
    declare -g DEFAULT_INTERFACE="$PREDICTABLE_NAME"
  else
    declare -g DEFAULT_INTERFACE="$CURRENT_INTERFACE"
  fi
}

# Get MAC-based predictable name for an interface. Outputs name to stdout.
_get_mac_based_name() {
  local iface="$1"
  local udev_info mac_name

  if [[ -e "/sys/class/net/${iface}" ]]; then
    udev_info=$(udevadm info "/sys/class/net/${iface}" 2>/dev/null)
    mac_name=$(printf '%s\n' "$udev_info" | grep "ID_NET_NAME_MAC=" | cut -d'=' -f2)

    if [[ -n $mac_name ]]; then
      printf '%s' "$mac_name"
      return 0
    fi

    # Fallback to PATH-based if no MAC name
    mac_name=$(printf '%s\n' "$udev_info" | grep "ID_NET_NAME_PATH=" | cut -d'=' -f2)
    if [[ -n $mac_name ]]; then
      printf '%s' "$mac_name"
      return 0
    fi
  fi

  # Return original if no predictable name found
  printf '%s' "$iface"
}

# Get available interfaces. Sets AVAILABLE_INTERFACES, INTERFACE_NAME, etc.
# Converts all interface names to MAC-based predictable names for reliability.
_detect_available_interfaces() {
  declare -g AVAILABLE_ALTNAMES=$(ip -d link show | grep -v "lo:" | grep -E '(^[0-9]+:|altname)' | awk '/^[0-9]+:/ {interface=$2; gsub(/:/, "", interface); printf "%s", interface} /altname/ {printf ", %s", $2} END {print ""}' | sed 's/, $//')

  # Get raw interface names first
  local raw_interfaces
  if cmd_exists ip && cmd_exists jq; then
    raw_interfaces=$(ip -j link show 2>/dev/null | jq -r '.[] | select(.ifname != "lo") | .ifname' | sort)
  elif cmd_exists ip; then
    raw_interfaces=$(ip link show | awk -F': ' '/^[0-9]+:/ && !/lo:/ {print $2}' | sort)
  else
    raw_interfaces="$CURRENT_INTERFACE"
  fi

  # Convert each interface to MAC-based name
  declare -g AVAILABLE_INTERFACES=""
  local iface mac_name
  while IFS= read -r iface; do
    [[ -z $iface ]] && continue
    mac_name=$(_get_mac_based_name "$iface")
    if [[ -n $AVAILABLE_INTERFACES ]]; then
      declare -g AVAILABLE_INTERFACES="${AVAILABLE_INTERFACES}"$'\n'"${mac_name}"
    else
      declare -g AVAILABLE_INTERFACES="${mac_name}"
    fi
  done <<<"$raw_interfaces"

  declare -g INTERFACE_COUNT="$(printf '%s\n' "$AVAILABLE_INTERFACES" | wc -l)"

  if [[ -z $INTERFACE_NAME ]]; then
    declare -g INTERFACE_NAME="$DEFAULT_INTERFACE"
  fi
}

# IP address detection

# Detect IPv4 address and gateway. Sets MAIN_IPV4, MAIN_IPV4_CIDR, MAIN_IPV4_GW.
_detect_ipv4() {
  local max_attempts="${SSH_RETRY_ATTEMPTS:-3}"
  local attempt=0

  while [[ $attempt -lt $max_attempts ]]; do
    attempt="$((attempt + 1))"

    if cmd_exists ip && cmd_exists jq; then
      declare -g MAIN_IPV4_CIDR="$(ip -j address show "$CURRENT_INTERFACE" 2>/dev/null | jq -r '.[0].addr_info[] | select(.family == "inet" and .scope == "global") | "\(.local)/\(.prefixlen)"' | head -n1)"
      declare -g MAIN_IPV4="${MAIN_IPV4_CIDR%/*}"
      declare -g MAIN_IPV4_GW="$(ip -j route 2>/dev/null | jq -r '.[] | select(.dst == "default") | .gateway' | head -n1)"
      [[ -n $MAIN_IPV4 ]] && [[ -n $MAIN_IPV4_GW ]] && return 0
    elif cmd_exists ip; then
      declare -g MAIN_IPV4_CIDR="$(ip address show "$CURRENT_INTERFACE" 2>/dev/null | grep global | grep "inet " | awk '{print $2}' | head -n1)"
      declare -g MAIN_IPV4="${MAIN_IPV4_CIDR%/*}"
      declare -g MAIN_IPV4_GW="$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n1)"
      [[ -n $MAIN_IPV4 ]] && [[ -n $MAIN_IPV4_GW ]] && return 0
    elif cmd_exists ifconfig; then
      declare -g MAIN_IPV4="$(ifconfig "$CURRENT_INTERFACE" 2>/dev/null | awk '/inet / {print $2}' | sed 's/addr://')"
      local netmask
      netmask=$(ifconfig "$CURRENT_INTERFACE" 2>/dev/null | awk '/inet / {print $4}' | sed 's/Mask://')
      if [[ -n $MAIN_IPV4 ]] && [[ -n $netmask ]]; then
        case "$netmask" in
          255.255.255.0) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/24" ;;
          255.255.255.128) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/25" ;;
          255.255.255.192) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/26" ;;
          255.255.255.224) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/27" ;;
          255.255.255.240) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/28" ;;
          255.255.255.248) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/29" ;;
          255.255.255.252) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/30" ;;
          255.255.0.0) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/16" ;;
          *) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/24" ;;
        esac
      fi
      if cmd_exists route; then
        declare -g MAIN_IPV4_GW="$(route -n 2>/dev/null | awk '/^0\.0\.0\.0/ {print $2}' | head -n1)"
      fi
      [[ -n $MAIN_IPV4 ]] && [[ -n $MAIN_IPV4_GW ]] && return 0
    fi

    if [[ $attempt -lt $max_attempts ]]; then
      log_info "Network info attempt $attempt failed, retrying in ${RETRY_DELAY_SECONDS:-2} seconds..."
      sleep "${RETRY_DELAY_SECONDS:-2}"
    fi
  done

  # All attempts failed
  log_error "IPv4 detection failed after $max_attempts attempts"
  return 1
}

# Detect MAC and IPv6 info. Sets MAC_ADDRESS, IPV6_*, MAIN_IPV6.
_detect_ipv6_and_mac() {
  if cmd_exists ip && cmd_exists jq; then
    declare -g MAC_ADDRESS="$(ip -j link show "$CURRENT_INTERFACE" 2>/dev/null | jq -r '.[0].address // empty')"
    declare -g IPV6_CIDR="$(ip -j address show "$CURRENT_INTERFACE" 2>/dev/null | jq -r '.[0].addr_info[] | select(.family == "inet6" and .scope == "global") | "\(.local)/\(.prefixlen)"' | head -n1)"
  elif cmd_exists ip; then
    declare -g MAC_ADDRESS="$(ip link show "$CURRENT_INTERFACE" 2>/dev/null | awk '/ether/ {print $2}')"
    declare -g IPV6_CIDR="$(ip address show "$CURRENT_INTERFACE" 2>/dev/null | grep global | grep "inet6 " | awk '{print $2}' | head -n1)"
  elif cmd_exists ifconfig; then
    declare -g MAC_ADDRESS="$(ifconfig "$CURRENT_INTERFACE" 2>/dev/null | awk '/ether/ {print $2}')"
    declare -g IPV6_CIDR="$(ifconfig "$CURRENT_INTERFACE" 2>/dev/null | awk '/inet6/ && /global/ {print $2}')"
  fi
  declare -g MAIN_IPV6="${IPV6_CIDR%/*}"

  if [[ -n $IPV6_CIDR ]]; then
    local ipv6_prefix
    ipv6_prefix=$(printf '%s' "$MAIN_IPV6" | cut -d':' -f1-4)
    declare -g FIRST_IPV6_CIDR="${ipv6_prefix}:1::1/80"
  else
    declare -g FIRST_IPV6_CIDR=""
  fi

  if [[ -n $MAIN_IPV6 ]]; then
    if cmd_exists ip; then
      declare -g IPV6_GATEWAY="$(ip -6 route 2>/dev/null | grep default | awk '{print $3}' | head -n1)"
    fi
  fi
}
# shellcheck shell=bash
# Drive detection and role assignment

# Detect available drives. Sets DRIVES, DRIVE_COUNT, DRIVE_NAMES/SIZES/MODELS.
detect_drives() {
  # Find all NVMe drives (excluding partitions)
  mapfile -t DRIVES < <(lsblk -d -n -o NAME,TYPE | grep nvme | grep disk | awk '{print "/dev/"$1}' | sort)
  declare -g DRIVE_COUNT="${#DRIVES[@]}"

  # Fall back to any available disk if no NVMe found (for budget servers)
  if [[ $DRIVE_COUNT -eq 0 ]]; then
    # Find any disk (sda, vda, etc.) excluding loop devices
    mapfile -t DRIVES < <(lsblk -d -n -o NAME,TYPE | grep disk | grep -v loop | awk '{print "/dev/"$1}' | sort)
    declare -g DRIVE_COUNT="${#DRIVES[@]}"
  fi

  # Collect drive info
  declare -g -a DRIVE_NAMES=()
  declare -g -a DRIVE_SIZES=()
  declare -g -a DRIVE_MODELS=()

  for drive in "${DRIVES[@]}"; do
    local name size model
    name="$(basename "$drive")"
    size="$(lsblk -d -n -o SIZE "$drive" | xargs)"
    model="$(lsblk -d -n -o MODEL "$drive" 2>/dev/null | xargs || echo "Disk")"
    DRIVE_NAMES+=("$name")
    DRIVE_SIZES+=("$size")
    DRIVE_MODELS+=("$model")
  done
}

# Initialize disk roles without auto-selection. User must manually select.
# Sets BOOT_DISK="", ZFS_POOL_DISKS=().
detect_disk_roles() {
  [[ $DRIVE_COUNT -eq 0 ]] && return 1

  # Initialize empty - user must select manually in wizard
  declare -g BOOT_DISK=""
  declare -g -a ZFS_POOL_DISKS=()

  log_info "Disk roles initialized (user selection required)"
  log_info "Available drives: ${DRIVES[*]}"
}

# Existing ZFS pool detection

# Detect existing ZFS pools → stdout "name|status|disks" per line
detect_existing_pools() {
  # Check if zpool command exists
  if ! cmd_exists zpool; then
    log_warn "zpool not found - ZFS not installed in rescue"
    return 0
  fi

  local pools=()

  # Get importable pools - try multiple methods
  # Method 1: scan all devices explicitly (catches more pools)
  local import_output
  import_output=$(zpool import -d /dev 2>&1) || true

  # Fallback: try without -d flag
  if [[ -z "$import_output" ]] || [[ $import_output == *"no pools available"* ]]; then
    import_output=$(zpool import 2>&1) || true
  fi

  log_debug "zpool import output: ${import_output:-(empty)}"

  # Check if output contains pool info (not just "no pools available")
  if [[ -z "$import_output" ]] || [[ $import_output == *"no pools available"* ]]; then
    log_debug "No importable pools found"
    return 0
  fi

  # Parse zpool import output
  # Format:
  #   pool: tankname
  #      id: 12345
  #   state: ONLINE
  #  action: The pool can be imported...
  #  config:
  #      tankname    ONLINE
  #        mirror-0  ONLINE
  #          nvme0n1 ONLINE
  #          nvme1n1 ONLINE

  local current_pool=""
  local current_state=""
  local current_disks=""
  local in_config=false

  while IFS= read -r line; do
    # Pool name
    if [[ $line =~ ^[[:space:]]*pool:[[:space:]]*(.+)$ ]]; then
      # Save previous pool if exists
      if [[ -n $current_pool ]]; then
        pools+=("${current_pool}|${current_state}|${current_disks}")
      fi
      current_pool="${BASH_REMATCH[1]}"
      current_state=""
      current_disks=""
      in_config=false
    # State
    elif [[ $line =~ ^[[:space:]]*state:[[:space:]]*(.+)$ ]]; then
      current_state="${BASH_REMATCH[1]}"
    # Config section start
    elif [[ $line =~ ^[[:space:]]*config: ]]; then
      in_config=true
    # Disk entries - match common disk patterns
    elif [[ $in_config == true ]]; then
      # Match: nvme0n1, sda, vda, xvda, hda, etc (with partition suffix optional)
      if [[ $line =~ ^[[:space:]]+(nvme[0-9]+n[0-9]+|[shxv]d[a-z]+)[p0-9]*[[:space:]] ]]; then
        local disk="${BASH_REMATCH[1]}"
        if [[ -n $current_disks ]]; then
          current_disks="${current_disks},/dev/${disk}"
        else
          current_disks="/dev/${disk}"
        fi
      fi
    fi
  done <<<"$import_output"

  # Save last pool
  if [[ -n $current_pool ]]; then
    pools+=("${current_pool}|${current_state}|${current_disks}")
  fi

  # Output pools
  for pool in "${pools[@]}"; do
    printf '%s\n' "$pool"
  done
}

# Get disks in pool. $1=pool_name → comma-separated disk paths
get_pool_disks() {
  local pool_name="$1"

  for line in "${DETECTED_POOLS[@]}"; do
    local name="${line%%|*}"
    if [[ $name == "$pool_name" ]]; then
      local rest="${line#*|}"
      printf '%s\n' "${rest#*|}"
      return 0
    fi
  done

  return 1
}

# Stores detected pools for wizard use
# Format: DETECTED_POOLS[0]="name|status|disks"
DETECTED_POOLS=()
# shellcheck shell=bash
# Wizard data loading (timezones, countries, mappings)

# Load timezones list. Sets WIZ_TIMEZONES.
_load_timezones() {
  if cmd_exists timedatectl; then
    declare -g WIZ_TIMEZONES=$(timedatectl list-timezones 2>/dev/null)
  else
    # Fallback: parse zoneinfo directory
    declare -g WIZ_TIMEZONES=$(find /usr/share/zoneinfo -type f 2>/dev/null \
      | sed 's|/usr/share/zoneinfo/||' \
      | grep -E '^(Africa|America|Antarctica|Asia|Atlantic|Australia|Europe|Indian|Pacific)/' \
      | sort)
  fi
  # Add UTC at the end
  WIZ_TIMEZONES+=$'\nUTC'
}

# Loads ISO 3166-1 alpha-2 country codes for wizard selection.
# Load countries list. Sets WIZ_COUNTRIES.
_load_countries() {
  local iso_file="/usr/share/iso-codes/json/iso_3166-1.json"
  if [[ -f $iso_file ]]; then
    # Parse JSON with grep (no jq dependency for this)
    declare -g WIZ_COUNTRIES=$(grep -oP '"alpha_2":\s*"\K[^"]+' "$iso_file" | tr '[:upper:]' '[:lower:]' | sort)
  else
    # Fallback: extract from locale data
    declare -g WIZ_COUNTRIES=$(locale -a 2>/dev/null | grep -oP '^[a-z]{2}(?=_)' | sort -u)
  fi
}

# Build timezone→country mapping. Sets TZ_TO_COUNTRY.
_build_tz_to_country() {
  declare -gA TZ_TO_COUNTRY
  local zone_tab="/usr/share/zoneinfo/zone.tab"
  [[ -f $zone_tab ]] || return 0

  while IFS=$'\t' read -r country _ tz _; do
    [[ $country == \#* ]] && continue
    [[ -z $tz ]] && continue
    TZ_TO_COUNTRY["$tz"]="${country,,}" # lowercase
  done <"$zone_tab"
}

# Detect existing ZFS pools. Sets DETECTED_POOLS.
_detect_pools() {
  declare -g -a DETECTED_POOLS=()

  # Capture both stdout and any errors
  local pool_output
  pool_output=$(detect_existing_pools 2>&1)

  while IFS= read -r line; do
    # Skip debug/log lines, only keep pool data (contains |)
    [[ $line == *"|"* ]] && DETECTED_POOLS+=("$line")
  done <<<"$pool_output"

  if [[ ${#DETECTED_POOLS[@]} -gt 0 ]]; then
    log_info "Detected ${#DETECTED_POOLS[@]} existing ZFS pool(s):"
    for pool in "${DETECTED_POOLS[@]}"; do
      log_info "  - $pool"
    done
  else
    log_info "No existing ZFS pools detected"
  fi
}

# Loads all dynamic wizard data from system.
# Orchestrates loading of timezones, countries, and TZ-to-country mapping.
# Called by collect_system_info() during initialization.
_load_wizard_data() {
  _load_timezones
  _load_countries
  _build_tz_to_country
  _detect_pools
}
# shellcheck shell=bash
# System status display

# Displays system status summary in formatted table.
# Only shows table if there are errors, then exits.
# If all checks pass, silently proceeds to wizard.
show_system_status() {
  detect_drives
  detect_disk_roles

  local no_drives=0
  if [[ $DRIVE_COUNT -eq 0 ]]; then
    no_drives=1
  fi

  # Check for errors first
  local has_errors=false
  if [[ $PREFLIGHT_ERRORS -gt 0 || $no_drives -eq 1 ]]; then
    has_errors=true
  fi

  # If no errors, go straight to wizard
  if [[ $has_errors == false ]]; then
    _wiz_start_edit
    return 0
  fi

  # Build table data with colored status markers
  local table_data
  table_data=",,
Status,Item,Value
"

  # Helper to format status with color using gum style
  format_status() {
    local status="$1"
    case "$status" in
      ok) gum style --foreground "$HEX_CYAN" "[OK]" ;;
      warn) gum style --foreground "$HEX_YELLOW" "[WARN]" ;;
      error) gum style --foreground "$HEX_RED" "[ERROR]" ;;
    esac
  }

  # Helper to add row
  add_row() {
    local status="$1"
    local label="$2"
    local value="$3"
    local status_text
    status_text=$(format_status "$status")
    table_data+="${status_text},${label},${value}
"
  }

  add_row "$PREFLIGHT_ROOT_STATUS" "Root Access" "$PREFLIGHT_ROOT"
  add_row "$PREFLIGHT_NET_STATUS" "Internet" "$PREFLIGHT_NET"
  add_row "$PREFLIGHT_DISK_STATUS" "Temp Space" "$PREFLIGHT_DISK"
  add_row "$PREFLIGHT_RAM_STATUS" "RAM" "$PREFLIGHT_RAM"
  add_row "$PREFLIGHT_CPU_STATUS" "CPU" "$PREFLIGHT_CPU"
  add_row "$PREFLIGHT_KVM_STATUS" "KVM" "$PREFLIGHT_KVM"

  # Add storage rows
  if [[ $no_drives -eq 1 ]]; then
    local error_status
    error_status=$(format_status "error")
    table_data+="${error_status},No drives detected!,
"
  else
    for i in "${!DRIVE_NAMES[@]}"; do
      local ok_status
      ok_status=$(format_status "ok")
      table_data+="${ok_status},${DRIVE_NAMES[$i]},${DRIVE_SIZES[$i]}  ${DRIVE_MODELS[$i]:0:25}
"
    done
  fi

  # Remove trailing newline
  table_data="${table_data%$'\n'}"

  # Display table using gum table
  printf '%s\n' "$table_data" | gum table \
    --print \
    --border "none" \
    --cell.foreground "$HEX_GRAY" \
    --header.foreground "$HEX_ORANGE"

  printf '\n'
  print_error "System requirements not met. Please fix the issues above."
  printf '\n'
  log_error "Pre-flight checks failed"
  exit 1
}
# shellcheck shell=bash
# Live installation logs with logo and auto-scroll

# Get terminal dimensions. Sets _LOG_TERM_HEIGHT, _LOG_TERM_WIDTH.
get_terminal_dimensions() {
  if [[ -t 1 && -n ${TERM:-} ]]; then
    _LOG_TERM_HEIGHT="$(tput lines 2>/dev/null)"
    _LOG_TERM_WIDTH="$(tput cols 2>/dev/null)"
  fi
  # Fallback if empty or non-numeric (declare || fallback doesn't work)
  [[ $_LOG_TERM_HEIGHT =~ ^[0-9]+$ ]] || _LOG_TERM_HEIGHT=24
  [[ $_LOG_TERM_WIDTH =~ ^[0-9]+$ ]] || _LOG_TERM_WIDTH=80
}

# Logo height uses BANNER_HEIGHT constant from 003-banner.sh
# Fallback to 9 if not defined (6 ASCII art + 1 empty + 1 tagline + 1 spacing)
LOGO_HEIGHT=${BANNER_HEIGHT:-9}

# Fixed header height (title label + line with dot + 2 blank lines)
HEADER_HEIGHT=4

# Calculate log area height. Sets LOG_AREA_HEIGHT.
calculate_log_area() {
  get_terminal_dimensions
  declare -g LOG_AREA_HEIGHT="$((_LOG_TERM_HEIGHT - LOGO_HEIGHT - HEADER_HEIGHT - 1))"
}

# Array to store log lines
declare -a LOG_LINES=()
LOG_COUNT=0

# Add log entry to live display. $1=message
add_log() {
  local message="$1"
  LOG_LINES+=("$message")
  ((LOG_COUNT++))
  render_logs
}

# Renders installation header in wizard style with progress indicator.
# Positions cursor below banner and displays "Installing Proxmox" header.
# Output goes to /dev/tty to prevent leaking into log files
_render_install_header() {
  # Use ANSI escape instead of tput for speed
  printf '\033[%d;0H' "$((LOGO_HEIGHT + 1))"
  format_wizard_header "Installing Proxmox"
  _wiz_blank_line
  _wiz_blank_line
} >/dev/tty 2>/dev/null

# Renders all log lines with auto-scroll behavior.
# Shows most recent logs that fit in LOG_AREA_HEIGHT, clears remaining lines.
# Uses ANSI escapes for flicker-free updates.
# IMPORTANT: All output goes to /dev/tty to prevent leaking into log files
render_logs() {
  _render_install_header

  local start_line=0
  local lines_printed=0
  if ((LOG_COUNT > LOG_AREA_HEIGHT)); then
    start_line="$((LOG_COUNT - LOG_AREA_HEIGHT))"
  fi
  for ((i = start_line; i < LOG_COUNT; i++)); do
    printf '%s\033[K\n' "${LOG_LINES[$i]}"
    ((lines_printed++))
  done

  # Clear any remaining lines below (in case log count decreased)
  local remaining="$((LOG_AREA_HEIGHT - lines_printed))"
  for ((i = 0; i < remaining; i++)); do
    printf '\033[K\n'
  done
} >/dev/tty 2>/dev/null

# Start task with "..." suffix. $1=message. Sets TASK_INDEX.
start_task() {
  local message="$1"
  add_log "$message..."
  declare -g TASK_INDEX="$((LOG_COUNT - 1))"
}

# Complete task with status. $1=idx, $2=message, $3=status (success/error/warning)
complete_task() {
  local task_index="$1"
  local message="$2"
  local status="${3:-success}"
  local indicator
  case "$status" in
    error) indicator="${CLR_RED}✗${CLR_RESET}" ;;
    warning) indicator="${CLR_YELLOW}⚠${CLR_RESET}" ;;
    *) indicator="${CLR_CYAN}✓${CLR_RESET}" ;;
  esac
  LOG_LINES[task_index]="$message $indicator"
  render_logs
}

# Add indented subtask with tree prefix. $1=message, $2=color (optional)
add_subtask_log() {
  local message="$1"
  local color="${2:-$CLR_GRAY}"
  add_log "${TREE_VERT}   ${color}${message}${CLR_RESET}"
}

# Start live installation display in alternate screen buffer
start_live_installation() {
  # Override show_progress with live version
  # shellcheck disable=SC2317,SC2329
  show_progress() {
    live_show_progress "$@"
  }

  calculate_log_area
  tput smcup # Enter alternate screen buffer
  tput civis # Hide cursor immediately
  _wiz_clear
  show_banner

  # Chain with existing cleanup handler - capture exit code, restore terminal, then run global cleanup
  # shellcheck disable=SC2064,SC2154
  trap 'ec=$?; tput cnorm 2>/dev/null; tput rmcup 2>/dev/null; (exit $ec); cleanup_and_error_handler' EXIT
}

# Finishes live installation display and restores normal terminal.
# Shows cursor and exits alternate screen buffer.
finish_live_installation() {
  tput cnorm # Show cursor
  tput rmcup # Exit alternate screen buffer
}

# Show progress with animated dots. $1=pid, $2=message, $3=done_msg, $4=--silent
live_show_progress() {
  local pid="$1"
  local message="${2:-Processing}"
  local done_message="${3:-$message}"
  local silent=false
  [[ ${3:-} == "--silent" || ${4:-} == "--silent" ]] && silent=true
  [[ ${3:-} == "--silent" ]] && done_message="$message"

  # Add task to live display with spinner
  start_task "${TREE_BRANCH} ${message}"
  local task_idx="$TASK_INDEX"

  # Wait for process with periodic updates
  local animation_counter=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 0.3 # Animation timing, kept at 0.3 for visual smoothness
    # Update the task line with animated dots (orange)
    local dots_count="$(((animation_counter % 3) + 1))"
    local dots=""
    for ((d = 0; d < dots_count; d++)); do dots+="."; done
    LOG_LINES[task_idx]="${TREE_BRANCH} ${message}${CLR_ORANGE}${dots}${CLR_RESET}"
    render_logs
    ((animation_counter++))
  done

  # Get exit code
  wait "$pid" 2>/dev/null
  local exit_code="$?"

  # Update with final status
  if [[ $exit_code -eq 0 ]]; then
    if [[ $silent != true ]]; then
      complete_task "$task_idx" "${TREE_BRANCH} ${done_message}"
    else
      # Remove the line for silent mode
      unset 'LOG_LINES[task_idx]'
      LOG_LINES=("${LOG_LINES[@]}")
      ((LOG_COUNT--))
      render_logs
    fi
  else
    complete_task "$task_idx" "${TREE_BRANCH} ${message}" "error"
  fi

  return $exit_code
}

# Add subtask to live log. $1=message
live_log_subtask() {
  local message="$1"
  add_subtask_log "$message"
}

# Log items as comma-separated wrapped list. $@=items
log_subtasks() {
  local max_width=55
  local current_line=""
  local first=true

  for item in "$@"; do
    local addition
    if [[ $first == true ]]; then
      addition="$item"
      first=false
    else
      addition=", $item"
    fi

    if [[ $((${#current_line} + ${#addition})) -gt $max_width && -n $current_line ]]; then
      add_subtask_log "${current_line},"
      current_line="$item"
    else
      current_line+="$addition"
    fi
  done

  # Print remaining items
  if [[ -n $current_line ]]; then
    add_subtask_log "$current_line"
  fi
}
# shellcheck shell=bash
# Configuration Wizard - Main Logic

# Main wizard loop

# Main wizard loop. Returns 0 when 'S' pressed to start installation.
_wizard_main() {
  local selection=0

  while true; do
    _wiz_render_menu "$selection"
    _wiz_read_key

    case "$WIZ_KEY" in
      up)
        if [[ $selection -gt 0 ]]; then
          ((selection--))
        fi
        ;;
      down)
        if [[ $selection -lt $((_WIZ_FIELD_COUNT - 1)) ]]; then
          ((selection++))
        fi
        ;;
      left)
        # Previous screen
        if [[ $WIZ_CURRENT_SCREEN -gt 0 ]]; then
          ((WIZ_CURRENT_SCREEN--))
          selection=0
        fi
        ;;
      right)
        # Next screen
        if [[ $WIZ_CURRENT_SCREEN -lt $((${#WIZ_SCREENS[@]} - 1)) ]]; then
          ((WIZ_CURRENT_SCREEN++))
          selection=0
        fi
        ;;
      enter)
        # Show cursor for edit screens
        _wiz_show_cursor
        # Edit selected field based on field map
        local field_name="${_WIZ_FIELD_MAP[$selection]:-}"
        # Skip if field name empty
        if [[ -z $field_name ]]; then
          log_warn "No field mapped for selection $selection"
        else
          case "$field_name" in
            hostname) _edit_hostname ;;
            email) _edit_email ;;
            password) _edit_password ;;
            timezone) _edit_timezone ;;
            keyboard) _edit_keyboard ;;
            country) _edit_country ;;
            iso_version) _edit_iso_version ;;
            repository) _edit_repository ;;
            interface) _edit_interface ;;
            bridge_mode) _edit_bridge_mode ;;
            private_subnet) _edit_private_subnet ;;
            bridge_mtu) _edit_bridge_mtu ;;
            ipv6) _edit_ipv6 ;;
            firewall) _edit_firewall ;;
            boot_disk) _edit_boot_disk ;;
            wipe_disks) _edit_wipe_disks ;;
            existing_pool) _edit_existing_pool ;;
            pool_disks) _edit_pool_disks ;;
            zfs_mode) _edit_zfs_mode ;;
            zfs_arc) _edit_zfs_arc ;;
            tailscale) _edit_tailscale ;;
            ssl) _edit_ssl ;;
            postfix) _edit_postfix ;;
            shell) _edit_shell ;;
            power_profile) _edit_power_profile ;;
            security) _edit_features_security ;;
            monitoring) _edit_features_monitoring ;;
            tools) _edit_features_tools ;;
            api_token) _edit_api_token ;;
            admin_username) _edit_admin_username ;;
            admin_password) _edit_admin_password ;;
            ssh_key) _edit_ssh_key ;;
            *) log_warn "Unknown field name: $field_name" ;;
          esac
        fi
        # Hide cursor again
        _wiz_hide_cursor
        ;;
      start)
        # Exit wizard loop to proceed with validation and installation
        return 0
        ;;
      quit | esc)
        # Clear screen and show confirmation with banner
        _wiz_start_edit
        _wiz_show_cursor
        if _wiz_confirm "Quit installation?" --default=false; then
          # Clean exit: restore screen, clear it, show cursor
          tput rmcup 2>/dev/null || true
          clear
          tput cnorm 2>/dev/null || true
          exit 0
        fi
        # Hide cursor and continue (menu will be redrawn on next iteration)
        _wiz_hide_cursor
        ;;
    esac
  done
}

# Edit screen helpers

# Show footer with key hints. $1=type (input/filter/checkbox), $2=lines
_show_input_footer() {
  local type="${1:-input}"
  local component_lines="${2:-1}"
  local -r footer_fixed_lines=2 # 1 blank line + 1 footer line

  # Print empty lines for component space
  local i
  for ((i = 0; i < component_lines; i++)); do
    _wiz_blank_line
  done

  # Blank line + centered footer
  _wiz_blank_line
  local footer_text
  case "$type" in
    filter)
      footer_text="${CLR_GRAY}[${CLR_ORANGE}↑↓${CLR_GRAY}] navigate  [${CLR_ORANGE}Enter${CLR_GRAY}] select  [${CLR_ORANGE}Esc${CLR_GRAY}] cancel${CLR_RESET}"
      ;;
    checkbox)
      footer_text="${CLR_GRAY}[${CLR_ORANGE}↑↓${CLR_GRAY}] navigate  [${CLR_ORANGE}Space${CLR_GRAY}] toggle  [${CLR_ORANGE}Enter${CLR_GRAY}] confirm  [${CLR_ORANGE}Esc${CLR_GRAY}] cancel${CLR_RESET}"
      ;;
    *)
      footer_text="${CLR_GRAY}[${CLR_ORANGE}Enter${CLR_GRAY}] confirm  [${CLR_ORANGE}Esc${CLR_GRAY}] cancel${CLR_RESET}"
      ;;
  esac
  printf '%s\n' "$(_wiz_center "$footer_text")"

  # Move cursor back up: component_lines + fixed footer lines
  tput cuu $((component_lines + footer_fixed_lines))
}

# Configuration validation

# Validate config, show missing fields. Returns 0=valid, 1=missing
_validate_config() {
  # Quick check first
  _wiz_config_complete && return 0

  # Collect missing fields for display
  local missing_fields=()
  [[ -z $PVE_HOSTNAME ]] && missing_fields+=("Hostname")
  [[ -z $DOMAIN_SUFFIX ]] && missing_fields+=("Domain")
  [[ -z $EMAIL ]] && missing_fields+=("Email")
  [[ -z $NEW_ROOT_PASSWORD ]] && missing_fields+=("Root Password")
  [[ -z $ADMIN_USERNAME ]] && missing_fields+=("Admin Username")
  [[ -z $ADMIN_PASSWORD ]] && missing_fields+=("Admin Password")
  [[ -z $TIMEZONE ]] && missing_fields+=("Timezone")
  [[ -z $KEYBOARD ]] && missing_fields+=("Keyboard")
  [[ -z $COUNTRY ]] && missing_fields+=("Country")
  [[ -z $PROXMOX_ISO_VERSION ]] && missing_fields+=("Proxmox Version")
  [[ -z $PVE_REPO_TYPE ]] && missing_fields+=("Repository")
  [[ -z $INTERFACE_NAME ]] && missing_fields+=("Network Interface")
  [[ -z $MAIN_IPV4 ]] && missing_fields+=("IPv4 Address")
  [[ -z $MAIN_IPV4_GW ]] && missing_fields+=("IPv4 Gateway")
  [[ -z $BRIDGE_MODE ]] && missing_fields+=("Bridge mode")
  [[ $BRIDGE_MODE != "external" && -z $PRIVATE_SUBNET ]] && missing_fields+=("Private subnet")
  [[ -z $IPV6_MODE ]] && missing_fields+=("IPv6")
  # ZFS validation: require raid/disks only when NOT using existing pool
  if [[ $USE_EXISTING_POOL == "yes" ]]; then
    [[ -z $EXISTING_POOL_NAME ]] && missing_fields+=("Existing pool name")
  else
    [[ -z $ZFS_RAID ]] && missing_fields+=("ZFS mode")
    [[ ${#ZFS_POOL_DISKS[@]} -eq 0 ]] && missing_fields+=("Pool disks")
    validate_pool_disk_conflict && missing_fields+=("Pool disks (boot disk conflict)")
    validate_raid_disk_count && missing_fields+=("ZFS mode (requires $(get_raid_min_disks "$ZFS_RAID")+ disks)")
    _pool_disks_have_mixed_sizes && missing_fields+=("Pool disks (different sizes - use separate boot disk)")
  fi
  [[ -z $ZFS_ARC_MODE ]] && missing_fields+=("ZFS ARC")
  [[ -z $SHELL_TYPE ]] && missing_fields+=("Shell")
  [[ -z $CPU_GOVERNOR ]] && missing_fields+=("Power profile")
  [[ -z $SSH_PUBLIC_KEY ]] && missing_fields+=("SSH Key")
  [[ $INSTALL_TAILSCALE != "yes" && -z $SSL_TYPE ]] && missing_fields+=("SSL Certificate")
  [[ $FIREWALL_MODE == "stealth" && $INSTALL_TAILSCALE != "yes" ]] && missing_fields+=("Tailscale (required for Stealth firewall)")
  # Postfix requires SMTP relay settings when enabled
  if [[ $INSTALL_POSTFIX == "yes" ]]; then
    [[ -z $SMTP_RELAY_HOST || -z $SMTP_RELAY_USER || -z $SMTP_RELAY_PASSWORD ]] && missing_fields+=("Postfix SMTP relay settings")
  fi

  # Show missing fields
  if [[ ${#missing_fields[@]} -gt 0 ]]; then
    _wiz_start_edit
    _wiz_hide_cursor
    _wiz_error --bold "Configuration incomplete!"
    _wiz_blank_line
    _wiz_warn "Required fields:"
    for field in "${missing_fields[@]}"; do printf '%s\n' "  ${CLR_CYAN}•${CLR_RESET} $field"; done
    # Extra padding to prevent _wiz_confirm's tput cuu 5 from overwriting the field list
    _wiz_blank_line
    _wiz_blank_line
    _wiz_blank_line
    _wiz_show_cursor
    _wiz_confirm "Return to configuration?" --default=true || exit 1
    _wiz_hide_cursor
    return 1
  fi
  return 0
}

# Main wizard entry point

# Main entry point for the configuration wizard.
# Runs in alternate screen buffer with hidden cursor.
# Loops until all required configuration is complete.
show_gum_config_editor() {
  # Enter alternate screen buffer and hide cursor (like vim/less)
  tput smcup # alternate screen
  _wiz_hide_cursor
  # Chain with existing cleanup handler - capture exit code, restore terminal, then run global cleanup
  # shellcheck disable=SC2064,SC2154
  trap 'ec=$?; _wiz_show_cursor; tput rmcup 2>/dev/null; (exit $ec); cleanup_and_error_handler' EXIT

  # Run wizard loop until configuration is complete
  while true; do
    _wizard_main

    # Validate configuration before proceeding
    if _validate_config; then
      break
    fi
  done
}
# shellcheck shell=bash
# Configuration Wizard - Core UI Primitives
# Gum wrappers, cursor control, and basic styling functions

# Indent for notification content (SSH key info, generated passwords, etc.)
WIZ_NOTIFY_INDENT="   "

# Cursor control

# Hides terminal cursor.
_wiz_hide_cursor() { printf '\033[?25l'; }

# Shows terminal cursor.
_wiz_show_cursor() { printf '\033[?25h'; }

# Basic styling helpers

# Outputs a blank line.
_wiz_blank_line() { printf '\n'; }

# Outputs red error-styled text with notification indent and error icon.
# Supports gum style flags (e.g., --bold) before the message.
_wiz_error() {
  local flags=()
  while [[ ${1:-} == --* ]]; do
    flags+=("$1")
    shift
  done
  gum style --foreground "$HEX_RED" "${flags[@]}" "${WIZ_NOTIFY_INDENT}✗ $*"
}

# Outputs yellow warning-styled text with notification indent.
# Supports gum style flags (e.g., --bold) before the message.
_wiz_warn() {
  local flags=()
  while [[ ${1:-} == --* ]]; do
    flags+=("$1")
    shift
  done
  gum style --foreground "$HEX_YELLOW" "${flags[@]}" "${WIZ_NOTIFY_INDENT}$*"
}

# Outputs cyan info-styled text with notification indent and success icon.
# Supports gum style flags (e.g., --bold) before the message.
_wiz_info() {
  local flags=()
  while [[ ${1:-} == --* ]]; do
    flags+=("$1")
    shift
  done
  gum style --foreground "$HEX_CYAN" "${flags[@]}" "${WIZ_NOTIFY_INDENT}✓ $*"
}

# Outputs gray dimmed text with notification indent.
# Supports gum style flags (e.g., --bold) before the message.
_wiz_dim() {
  local flags=()
  while [[ ${1:-} == --* ]]; do
    flags+=("$1")
    shift
  done
  gum style --foreground "$HEX_GRAY" "${flags[@]}" "${WIZ_NOTIFY_INDENT}$*"
}

# Display description block with {{color:text}} highlight syntax. $@=lines
_wiz_description() {
  local output=""
  for line in "$@"; do
    # Replace {{color:text}} with actual color codes
    line="${line//\{\{cyan:/${CLR_CYAN}}"
    line="${line//\{\{yellow:/${CLR_YELLOW}}"
    line="${line//\{\{red:/${CLR_RED}}"
    line="${line//\{\{orange:/${CLR_ORANGE}}"
    line="${line//\}\}/${CLR_GRAY}}"
    output+="${CLR_GRAY}${line}${CLR_RESET}\n"
  done
  printf '%b' "$output"
}

# Gum wrappers

# Gum confirm with project styling, centered
_wiz_confirm() {
  local prompt="$1"
  shift

  # Center the dialog using gum's padding (top right bottom left)
  # Buttons are ~15 chars wide, use max of prompt or button width
  local content_width left_pad
  content_width="$((${#prompt} > 15 ? ${#prompt} : 15))"
  left_pad="$(((TERM_WIDTH - content_width) / 2))"
  ((left_pad < 0)) && left_pad=0

  # Custom centered footer (matching project style)
  # Print blank lines + footer, then move cursor up so gum draws above
  local footer_text
  footer_text="${CLR_GRAY}[${CLR_ORANGE}←→${CLR_GRAY}] toggle  [${CLR_ORANGE}Enter${CLR_GRAY}] submit  [${CLR_ORANGE}Y${CLR_GRAY}] yes  [${CLR_ORANGE}N${CLR_GRAY}] no${CLR_RESET}"
  _wiz_blank_line
  _wiz_blank_line
  printf '%s\n' "$(_wiz_center "$footer_text")"

  # gum confirm uses 2 lines (prompt + buttons), plus 2 blank + 1 footer = 5 lines up
  tput cuu 5

  gum confirm "$prompt" "$@" \
    --no-show-help \
    --padding "0 0 0 $left_pad" \
    --prompt.foreground "$HEX_ORANGE" \
    --selected.background "$HEX_ORANGE"
}

# Gum choose with project styling
_wiz_choose() {
  gum choose \
    --padding "0 0 0 1" \
    --header.foreground "$HEX_CYAN" \
    --cursor "${CLR_ORANGE}›${CLR_RESET} " \
    --cursor.foreground "$HEX_NONE" \
    --item.foreground "$HEX_WHITE" \
    --selected.foreground "$HEX_WHITE" \
    --no-show-help \
    "$@"
}

# Gum multi-select with checkmarks
_wiz_choose_multi() {
  gum choose \
    --no-limit \
    --padding "0 0 0 1" \
    --header.foreground "$HEX_CYAN" \
    --cursor "${CLR_ORANGE}›${CLR_RESET} " \
    --cursor.foreground "$HEX_NONE" \
    --cursor-prefix "◦ " \
    --selected.foreground "$HEX_WHITE" \
    --selected-prefix "${CLR_CYAN}✓${CLR_RESET} " \
    --unselected-prefix "◦ " \
    --no-show-help \
    "$@"
}

# Gum input with project styling
_wiz_input() {
  gum input \
    --padding "0 0 0 1" \
    --prompt.foreground "$HEX_CYAN" \
    --cursor.foreground "$HEX_ORANGE" \
    --no-show-help \
    "$@"
}

# Gum filter with project styling
_wiz_filter() {
  gum filter \
    --padding "0 0 0 1" \
    --placeholder "Type to search..." \
    --indicator "›" \
    --height 5 \
    --no-show-help \
    --prompt.foreground "$HEX_CYAN" \
    --indicator.foreground "$HEX_ORANGE" \
    --match.foreground "$HEX_ORANGE" \
    "$@"
}

# Screen helpers

# Clears screen using ANSI escape (faster than clear command).
_wiz_clear() {
  printf '\033[H\033[J'
}

# Clears screen and shows banner for edit screens.
# Common pattern used at start of field editor functions.
_wiz_start_edit() {
  _wiz_clear
  show_banner
  _wiz_blank_line
}

# Prepare input screen with optional description. $@=lines
_wiz_input_screen() {
  _wiz_start_edit
  # Show description lines if provided
  for line in "$@"; do
    _wiz_dim "$line"
  done
  [[ $# -gt 0 ]] && printf '\n'
  _show_input_footer
}

# Value formatting

# Format value or show placeholder. $1=value, $2=placeholder
_wiz_fmt() {
  local value="$1"
  local placeholder="${2:-→ set value}"
  if [[ -n $value ]]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "${CLR_GRAY}${placeholder}${CLR_RESET}"
  fi
}

# Show validation error with 3s pause. $1=message
show_validation_error() {
  local message="$1"

  # Hide cursor during error display
  _wiz_hide_cursor

  # Show error message (replaces blank line, footer stays below)
  _wiz_error "$message"
  sleep "${WIZARD_MESSAGE_DELAY:-3}"
}
# shellcheck shell=bash
# Configuration Wizard - Navigation Header and Key Reading

# Screen definitions
WIZ_SCREENS=("Basic" "Proxmox" "Network" "Storage" "Services" "Access")
WIZ_CURRENT_SCREEN=0

# Navigation column width
_NAV_COL_WIDTH=10

# Navigation header helpers

# Center text (strips ANSI for width calc). $1=text → centered text
_wiz_center() {
  local text="$1"
  local term_width
  term_width="$(tput cols 2>/dev/null || echo 80)"

  # Strip ANSI escape codes to get visible length (using $'\e' for portability)
  local visible_text
  visible_text="$(printf '%s' "$text" | sed $'s/\e\\[[0-9;]*m//g')"
  local text_len="${#visible_text}"

  # Calculate padding
  local padding="$(((term_width - text_len) / 2))"
  ((padding < 0)) && padding=0

  # Print padding + text
  printf '%*s%s' "$padding" "" "$text"
}

# Repeat character N times. $1=char, $2=count
_nav_repeat() {
  local char="$1" count="$2" i
  for ((i = 0; i < count; i++)); do
    printf '%s' "$char"
  done
}

# Get nav color for screen state. $1=screen_idx, $2=current_idx → color
_nav_color() {
  local idx="$1" current="$2"
  if [[ $idx -eq $current ]]; then
    printf '%s\n' "$CLR_ORANGE"
  elif [[ $idx -lt $current ]]; then
    printf '%s\n' "$CLR_CYAN"
  else
    printf '%s\n' "$CLR_GRAY"
  fi
}

# Get nav dot for screen state. $1=screen_idx, $2=current_idx → ◉/●/○
_nav_dot() {
  local idx="$1" current="$2"
  if [[ $idx -eq $current ]]; then
    printf '%s\n' "◉"
  elif [[ $idx -lt $current ]]; then
    printf '%s\n' "●"
  else
    printf '%s\n' "○"
  fi
}

# Get nav line style. $1=screen_idx, $2=current_idx, $3=length → ━━━/───
_nav_line() {
  local idx="$1" current="$2" len="$3"
  if [[ $idx -lt $current ]]; then
    _nav_repeat "━" "$len"
  else
    _nav_repeat "─" "$len"
  fi
}

# Renders the screen navigation header with wizard-style dots
_wiz_render_nav() {
  local current="$WIZ_CURRENT_SCREEN"
  local total="${#WIZ_SCREENS[@]}"
  local col="$_NAV_COL_WIDTH"

  # Calculate padding to center relative to terminal width
  local nav_width="$((col * total))"
  local pad_left="$(((TERM_WIDTH - nav_width) / 2))"
  local padding=""
  ((pad_left > 0)) && padding=$(printf '%*s' $pad_left '')

  # Screen names row
  local labels="$padding"
  for i in "${!WIZ_SCREENS[@]}"; do
    local name="${WIZ_SCREENS[$i]}"
    local name_len="${#name}"
    local pad_left="$(((col - name_len) / 2))"
    local pad_right="$((col - name_len - pad_left))"
    local centered
    centered=$(printf '%*s%s%*s' $pad_left '' "$name" $pad_right '')
    labels+="$(_nav_color "$i" "$current")${centered}${CLR_RESET}"
  done

  # Dots with connecting lines row
  local dots="$padding"
  local center_pad="$(((col - 1) / 2))"
  local right_pad="$((col - center_pad - 1))"

  for i in "${!WIZ_SCREENS[@]}"; do
    local color line_color dot
    color=$(_nav_color "$i" "$current")
    dot=$(_nav_dot "$i" "$current")

    if [[ $i -eq 0 ]]; then
      # First: pad + dot + line_right
      dots+=$(printf '%*s' $center_pad '')
      dots+="${color}${dot}${CLR_RESET}"
      # Line after first dot uses current dot's completion state
      local line_clr
      line_clr=$([[ $i -lt $current ]] && echo "$CLR_CYAN" || echo "$CLR_GRAY")
      dots+="${line_clr}$(_nav_line "$i" "$current" "$right_pad")${CLR_RESET}"
    elif [[ $i -eq $((total - 1)) ]]; then
      # Last: line_left + dot
      local prev_line_clr
      prev_line_clr=$([[ $((i - 1)) -lt $current ]] && echo "$CLR_CYAN" || echo "$CLR_GRAY")
      dots+="${prev_line_clr}$(_nav_line "$((i - 1))" "$current" "$center_pad")${CLR_RESET}"
      dots+="${color}${dot}${CLR_RESET}"
    else
      # Middle: line_left + dot + line_right
      local prev_line_clr
      prev_line_clr=$([[ $((i - 1)) -lt $current ]] && echo "$CLR_CYAN" || echo "$CLR_GRAY")
      dots+="${prev_line_clr}$(_nav_line "$((i - 1))" "$current" "$center_pad")${CLR_RESET}"
      dots+="${color}${dot}${CLR_RESET}"
      local next_line_clr
      next_line_clr=$([[ $i -lt $current ]] && echo "$CLR_CYAN" || echo "$CLR_GRAY")
      dots+="${next_line_clr}$(_nav_line "$i" "$current" "$right_pad")${CLR_RESET}"
    fi
  done

  printf '%s\n%s\n' "$labels" "$dots"
}

# Key reading

# Read single key press (arrow keys → WIZ_KEY: up/down/left/right/enter/quit/esc)
_wiz_read_key() {
  local key
  IFS= read -rsn1 key

  # Handle escape sequences (arrow keys)
  if [[ $key == $'\x1b' ]]; then
    read -rsn2 -t 0.5 key
    case "$key" in
      '[A') declare -g WIZ_KEY="up" ;;
      '[B') declare -g WIZ_KEY="down" ;;
      '[C') declare -g WIZ_KEY="right" ;;
      '[D') declare -g WIZ_KEY="left" ;;
      *) declare -g WIZ_KEY="esc" ;;
    esac
  elif [[ $key == "" ]]; then
    declare -g WIZ_KEY="enter"
  elif [[ $key == "q" || $key == "Q" ]]; then
    declare -g WIZ_KEY="quit"
  elif [[ $key == "s" || $key == "S" ]]; then
    declare -g WIZ_KEY="start"
  else
    declare -g WIZ_KEY="$key"
  fi
}
# shellcheck shell=bash
# Configuration Wizard - Display Value Formatters

# Display mapping table (internal value → display text)
declare -gA _DSP_MAP=(
  # Repository types
  ["repo:no-subscription"]="No-subscription (free)"
  ["repo:enterprise"]="Enterprise"
  ["repo:test"]="Test/Development"
  # IPv6 modes
  ["ipv6:auto"]="Auto"
  ["ipv6:manual"]="Manual"
  ["ipv6:disabled"]="Disabled"

  # Bridge modes
  ["bridge:external"]="External bridge"
  ["bridge:internal"]="Internal NAT"
  ["bridge:both"]="Both"

  # Firewall modes
  ["firewall:stealth"]="Stealth (Tailscale only)"
  ["firewall:strict"]="Strict (SSH only)"
  ["firewall:standard"]="Standard (SSH + Web UI)"

  # ZFS RAID
  ["zfs:single"]="Single disk"
  ["zfs:raid0"]="RAID-0 (striped)"
  ["zfs:raid1"]="RAID-1 (mirror)"
  ["zfs:raidz1"]="RAID-Z1 (parity)"
  ["zfs:raidz2"]="RAID-Z2 (double parity)"
  ["zfs:raidz3"]="RAID-Z3 (triple parity)"
  ["zfs:raid10"]="RAID-10 (striped mirrors)"

  # ZFS ARC
  ["arc:vm-focused"]="VM-focused (4GB)"
  ["arc:balanced"]="Balanced (25-40%)"
  ["arc:storage-focused"]="Storage-focused (50%)"

  # SSL types
  ["ssl:self-signed"]="Self-signed"
  ["ssl:letsencrypt"]="Let's Encrypt"

  # Shell types
  ["shell:zsh"]="ZSH"
  ["shell:bash"]="Bash"

  # CPU governors
  ["power:performance"]="Performance"
  ["power:ondemand"]="Balanced"
  ["power:powersave"]="Balanced"
  ["power:schedutil"]="Adaptive"
  ["power:conservative"]="Conservative"
)

# Display value formatters

# Lookup display value. $1=category, $2=internal_value → display_text
_dsp_lookup() {
  local key="$1:$2"
  echo "${_DSP_MAP[$key]:-$2}"
}

# Escape backslashes for safe printf %b display. $1=value
_dsp_escape() {
  printf '%s' "${1//\\/\\\\}"
}

# Formats Basic screen values: hostname, password
_dsp_basic() {
  declare -g _DSP_PASS=""
  [[ -n $NEW_ROOT_PASSWORD ]] && declare -g _DSP_PASS="********"

  declare -g _DSP_HOSTNAME=""
  if [[ -n $PVE_HOSTNAME && -n $DOMAIN_SUFFIX ]]; then
    # Escape user values to prevent printf %b interpretation
    declare -g _DSP_HOSTNAME="$(_dsp_escape "$PVE_HOSTNAME").$(_dsp_escape "$DOMAIN_SUFFIX")"
  fi
}

# Formats Proxmox screen values: repository, ISO version
_dsp_proxmox() {
  declare -g _DSP_REPO=""
  [[ -n $PVE_REPO_TYPE ]] && declare -g _DSP_REPO=$(_dsp_lookup "repo" "$PVE_REPO_TYPE")

  declare -g _DSP_ISO=""
  [[ -n $PROXMOX_ISO_VERSION ]] && declare -g _DSP_ISO=$(get_iso_version "$PROXMOX_ISO_VERSION")
}

# Formats Network screen values: IPv6, bridge, firewall, MTU
_dsp_network() {
  declare -g _DSP_IPV6=""
  if [[ -n $IPV6_MODE ]]; then
    declare -g _DSP_IPV6=$(_dsp_lookup "ipv6" "$IPV6_MODE")
    # Special case: manual mode shows address details
    if [[ $IPV6_MODE == "manual" && -n $MAIN_IPV6 ]]; then
      _DSP_IPV6+=" ($(_dsp_escape "$MAIN_IPV6"), gw: $(_dsp_escape "$IPV6_GATEWAY"))"
    fi
  fi

  declare -g _DSP_BRIDGE=""
  [[ -n $BRIDGE_MODE ]] && declare -g _DSP_BRIDGE=$(_dsp_lookup "bridge" "$BRIDGE_MODE")

  declare -g _DSP_FIREWALL=""
  if [[ -n $INSTALL_FIREWALL ]]; then
    if [[ $INSTALL_FIREWALL == "yes" ]]; then
      declare -g _DSP_FIREWALL=$(_dsp_lookup "firewall" "$FIREWALL_MODE")
    else
      declare -g _DSP_FIREWALL="Disabled"
    fi
  fi

  declare -g _DSP_MTU="${BRIDGE_MTU:-9000}"
  [[ $_DSP_MTU == "9000" ]] && declare -g _DSP_MTU="9000 (jumbo)"
}

# Formats Storage screen values: ZFS mode, ARC, boot/pool disks, existing pool
_dsp_storage() {
  # Existing pool mode
  declare -g _DSP_EXISTING_POOL=""
  if [[ $USE_EXISTING_POOL == "yes" && -n $EXISTING_POOL_NAME ]]; then
    declare -g _DSP_EXISTING_POOL="Use: $(_dsp_escape "$EXISTING_POOL_NAME") (${#EXISTING_POOL_DISKS[@]} disks)"
  else
    declare -g _DSP_EXISTING_POOL="Create new"
  fi

  declare -g _DSP_ZFS=""
  if [[ -n $ZFS_RAID ]]; then
    declare -g _DSP_ZFS=$(_dsp_lookup "zfs" "$ZFS_RAID")
  elif [[ $USE_EXISTING_POOL == "yes" ]]; then
    declare -g _DSP_ZFS="(preserved)"
  fi

  declare -g _DSP_ARC=""
  [[ -n $ZFS_ARC_MODE ]] && declare -g _DSP_ARC=$(_dsp_lookup "arc" "$ZFS_ARC_MODE")

  declare -g _DSP_BOOT="All in pool"
  if [[ -n $BOOT_DISK ]]; then
    for i in "${!DRIVES[@]}"; do
      if [[ ${DRIVES[$i]} == "$BOOT_DISK" ]]; then
        declare -g _DSP_BOOT="${DRIVE_MODELS[$i]}"
        break
      fi
    done
  fi

  if [[ $USE_EXISTING_POOL == "yes" ]]; then
    declare -g _DSP_POOL="(existing pool)"
  elif [[ ${#ZFS_POOL_DISKS[@]} -eq 0 ]]; then
    declare -g _DSP_POOL="${CLR_YELLOW}(select disks)${CLR_RESET}"
  elif _pool_disks_have_mixed_sizes; then
    declare -g _DSP_POOL="${#ZFS_POOL_DISKS[@]} disks ${CLR_YELLOW}⚠ different sizes${CLR_RESET}"
  else
    declare -g _DSP_POOL="${#ZFS_POOL_DISKS[@]} disks"
  fi

  # Wipe disks option
  declare -g _DSP_WIPE=""
  if [[ $WIPE_DISKS == "yes" ]]; then
    declare -g _DSP_WIPE="Yes (full wipe)"
  else
    declare -g _DSP_WIPE="No (keep existing)"
  fi
}

# Formats Services screen values: Tailscale, SSL, shell, power, features
_dsp_services() {
  declare -g _DSP_TAILSCALE=""
  if [[ -n $INSTALL_TAILSCALE ]]; then
    if [[ $INSTALL_TAILSCALE == "yes" ]]; then
      declare -g _DSP_TAILSCALE="Enabled + Stealth"
    else
      declare -g _DSP_TAILSCALE="Disabled"
    fi
  fi

  declare -g _DSP_SSL=""
  [[ -n $SSL_TYPE ]] && declare -g _DSP_SSL=$(_dsp_lookup "ssl" "$SSL_TYPE")

  declare -g _DSP_POSTFIX=""
  if [[ -n $INSTALL_POSTFIX ]]; then
    if [[ $INSTALL_POSTFIX == "yes" && -n $SMTP_RELAY_HOST ]]; then
      declare -g _DSP_POSTFIX="Relay: $(_dsp_escape "$SMTP_RELAY_HOST"):$(_dsp_escape "${SMTP_RELAY_PORT:-587}")"
    elif [[ $INSTALL_POSTFIX == "yes" ]]; then
      declare -g _DSP_POSTFIX="Enabled (no relay)"
    else
      declare -g _DSP_POSTFIX="Disabled"
    fi
  fi

  declare -g _DSP_SHELL=""
  [[ -n $SHELL_TYPE ]] && declare -g _DSP_SHELL=$(_dsp_lookup "shell" "$SHELL_TYPE")

  declare -g _DSP_POWER=""
  [[ -n $CPU_GOVERNOR ]] && declare -g _DSP_POWER=$(_dsp_lookup "power" "$CPU_GOVERNOR")

  # Feature lists
  declare -g _DSP_SECURITY="none"
  local sec_items=()
  [[ $INSTALL_APPARMOR == "yes" ]] && sec_items+=("apparmor")
  [[ $INSTALL_AUDITD == "yes" ]] && sec_items+=("auditd")
  [[ $INSTALL_AIDE == "yes" ]] && sec_items+=("aide")
  [[ $INSTALL_CHKROOTKIT == "yes" ]] && sec_items+=("chkrootkit")
  [[ $INSTALL_LYNIS == "yes" ]] && sec_items+=("lynis")
  [[ $INSTALL_NEEDRESTART == "yes" ]] && sec_items+=("needrestart")
  [[ ${#sec_items[@]} -gt 0 ]] && declare -g _DSP_SECURITY="${sec_items[*]}"

  declare -g _DSP_MONITORING="none"
  local mon_items=()
  [[ $INSTALL_VNSTAT == "yes" ]] && mon_items+=("vnstat")
  [[ $INSTALL_NETDATA == "yes" ]] && mon_items+=("netdata")
  [[ $INSTALL_PROMTAIL == "yes" ]] && mon_items+=("promtail")
  [[ ${#mon_items[@]} -gt 0 ]] && declare -g _DSP_MONITORING="${mon_items[*]}"

  declare -g _DSP_TOOLS="none"
  local tool_items=()
  [[ $INSTALL_YAZI == "yes" ]] && tool_items+=("yazi")
  [[ $INSTALL_NVIM == "yes" ]] && tool_items+=("nvim")
  [[ $INSTALL_RINGBUFFER == "yes" ]] && tool_items+=("ringbuffer")
  [[ ${#tool_items[@]} -gt 0 ]] && declare -g _DSP_TOOLS="${tool_items[*]}"
}

# Formats Access screen values: admin user, SSH key, API token
_dsp_access() {
  declare -g _DSP_ADMIN_USER=""
  [[ -n $ADMIN_USERNAME ]] && declare -g _DSP_ADMIN_USER="$(_dsp_escape "$ADMIN_USERNAME")"

  declare -g _DSP_ADMIN_PASS=""
  [[ -n $ADMIN_PASSWORD ]] && declare -g _DSP_ADMIN_PASS="********"

  declare -g _DSP_SSH=""
  [[ -n $SSH_PUBLIC_KEY ]] && declare -g _DSP_SSH="$(_dsp_escape "${SSH_PUBLIC_KEY:0:20}")..."

  declare -g _DSP_API=""
  if [[ -n $INSTALL_API_TOKEN ]]; then
    case "$INSTALL_API_TOKEN" in
      yes) declare -g _DSP_API="Yes ($(_dsp_escape "$API_TOKEN_NAME"))" ;;
      no) declare -g _DSP_API="No" ;;
    esac
  fi
}

# Build _DSP_* display values from current config state
_wiz_build_display_values() {
  _dsp_basic
  _dsp_proxmox
  _dsp_network
  _dsp_storage
  _dsp_services
  _dsp_access
}
# shellcheck shell=bash
# Configuration Wizard - Menu Rendering

# Check if all required config fields set. Returns 0=complete, 1=missing
_wiz_config_complete() {
  [[ -z $PVE_HOSTNAME ]] && return 1
  [[ -z $DOMAIN_SUFFIX ]] && return 1
  [[ -z $EMAIL ]] && return 1
  [[ -z $NEW_ROOT_PASSWORD ]] && return 1
  [[ -z $ADMIN_USERNAME ]] && return 1
  [[ -z $ADMIN_PASSWORD ]] && return 1
  [[ -z $TIMEZONE ]] && return 1
  [[ -z $KEYBOARD ]] && return 1
  [[ -z $COUNTRY ]] && return 1
  [[ -z $PROXMOX_ISO_VERSION ]] && return 1
  [[ -z $PVE_REPO_TYPE ]] && return 1
  [[ -z $INTERFACE_NAME ]] && return 1
  [[ -z $MAIN_IPV4 ]] && return 1
  [[ -z $MAIN_IPV4_GW ]] && return 1
  [[ -z $BRIDGE_MODE ]] && return 1
  [[ $BRIDGE_MODE != "external" && -z $PRIVATE_SUBNET ]] && return 1
  [[ -z $IPV6_MODE ]] && return 1
  # ZFS validation: require raid/disks only when NOT using existing pool
  if [[ $USE_EXISTING_POOL == "yes" ]]; then
    [[ -z $EXISTING_POOL_NAME ]] && return 1
  else
    [[ -z $ZFS_RAID ]] && return 1
    [[ ${#ZFS_POOL_DISKS[@]} -eq 0 ]] && return 1
    validate_pool_disk_conflict && return 1
    validate_raid_disk_count && return 1
    _pool_disks_have_mixed_sizes && return 1
  fi
  [[ -z $ZFS_ARC_MODE ]] && return 1
  [[ -z $SHELL_TYPE ]] && return 1
  [[ -z $CPU_GOVERNOR ]] && return 1
  [[ -z $SSH_PUBLIC_KEY ]] && return 1
  # SSL required if Tailscale disabled
  [[ $INSTALL_TAILSCALE != "yes" && -z $SSL_TYPE ]] && return 1
  # Stealth firewall requires Tailscale
  [[ $FIREWALL_MODE == "stealth" && $INSTALL_TAILSCALE != "yes" ]] && return 1
  # Postfix requires SMTP relay settings when enabled
  if [[ $INSTALL_POSTFIX == "yes" ]]; then
    [[ -z $SMTP_RELAY_HOST || -z $SMTP_RELAY_USER || -z $SMTP_RELAY_PASSWORD ]] && return 1
  fi
  return 0
}

# Field tracking
_WIZ_FIELD_COUNT=0
_WIZ_FIELD_MAP=()

# Screen content renderers

# Render fields for a screen. $1=screen_idx, $2=selection
_wiz_render_screen_content() {
  local screen="$1"
  local selection="$2"

  case $screen in
    0) # Basic
      _add_field "Hostname         " "$(_wiz_fmt "$_DSP_HOSTNAME")" "hostname"
      _add_field "Email            " "$(_wiz_fmt "$EMAIL")" "email"
      _add_field "Root Password    " "$(_wiz_fmt "$_DSP_PASS")" "password"
      _add_field "Timezone         " "$(_wiz_fmt "$TIMEZONE")" "timezone"
      _add_field "Keyboard         " "$(_wiz_fmt "$KEYBOARD")" "keyboard"
      _add_field "Country          " "$(_wiz_fmt "$COUNTRY")" "country"
      ;;
    1) # Proxmox
      _add_field "Version          " "$(_wiz_fmt "$_DSP_ISO")" "iso_version"
      _add_field "Repository       " "$(_wiz_fmt "$_DSP_REPO")" "repository"
      ;;
    2) # Network
      if [[ ${INTERFACE_COUNT:-1} -gt 1 ]]; then
        _add_field "Interface        " "$(_wiz_fmt "$INTERFACE_NAME")" "interface"
      fi
      _add_field "Bridge mode      " "$(_wiz_fmt "$_DSP_BRIDGE")" "bridge_mode"
      if [[ $BRIDGE_MODE == "internal" || $BRIDGE_MODE == "both" ]]; then
        _add_field "Private subnet   " "$(_wiz_fmt "$PRIVATE_SUBNET")" "private_subnet"
        _add_field "Bridge MTU       " "$(_wiz_fmt "$_DSP_MTU")" "bridge_mtu"
      fi
      _add_field "IPv6             " "$(_wiz_fmt "$_DSP_IPV6")" "ipv6"
      _add_field "Firewall         " "$(_wiz_fmt "$_DSP_FIREWALL")" "firewall"
      ;;
    3) # Storage
      _add_field "Wipe disks       " "$(_wiz_fmt "$_DSP_WIPE")" "wipe_disks"
      if [[ $DRIVE_COUNT -gt 1 ]]; then
        _add_field "Boot disk        " "$(_wiz_fmt "$_DSP_BOOT")" "boot_disk"
        _add_field "Pool mode        " "$(_wiz_fmt "$_DSP_EXISTING_POOL")" "existing_pool"
        # Only show pool disk options if not using existing pool
        if [[ $USE_EXISTING_POOL != "yes" ]]; then
          _add_field "Pool disks       " "$(_wiz_fmt "$_DSP_POOL")" "pool_disks"
          _add_field "ZFS mode         " "$(_wiz_fmt "$_DSP_ZFS")" "zfs_mode"
        fi
      else
        # Single disk: no pool selection needed
        _add_field "ZFS mode         " "$(_wiz_fmt "$_DSP_ZFS")" "zfs_mode"
      fi
      _add_field "ZFS ARC          " "$(_wiz_fmt "$_DSP_ARC")" "zfs_arc"
      ;;
    4) # Services
      _add_field "Tailscale        " "$(_wiz_fmt "$_DSP_TAILSCALE")" "tailscale"
      if [[ $INSTALL_TAILSCALE != "yes" ]]; then
        _add_field "SSL Certificate  " "$(_wiz_fmt "$_DSP_SSL")" "ssl"
      fi
      _add_field "Postfix          " "$(_wiz_fmt "$_DSP_POSTFIX")" "postfix"
      _add_field "Shell            " "$(_wiz_fmt "$_DSP_SHELL")" "shell"
      _add_field "Power profile    " "$(_wiz_fmt "$_DSP_POWER")" "power_profile"
      _add_field "Security         " "$(_wiz_fmt "$_DSP_SECURITY")" "security"
      _add_field "Monitoring       " "$(_wiz_fmt "$_DSP_MONITORING")" "monitoring"
      _add_field "Tools            " "$(_wiz_fmt "$_DSP_TOOLS")" "tools"
      ;;
    5) # Access
      _add_field "Admin User       " "$(_wiz_fmt "$_DSP_ADMIN_USER")" "admin_username"
      _add_field "Admin Password   " "$(_wiz_fmt "$_DSP_ADMIN_PASS")" "admin_password"
      _add_field "SSH Key          " "$(_wiz_fmt "$_DSP_SSH")" "ssh_key"
      _add_field "API Token        " "$(_wiz_fmt "$_DSP_API")" "api_token"
      ;;
  esac
}

# Render main menu with selection. $1=selection_idx
_wiz_render_menu() {
  local selection="$1"
  local output=""
  local banner_output

  # Capture banner output
  banner_output=$(show_banner)

  # Build display values
  _wiz_build_display_values

  # Start output with banner + navigation header
  output+="${banner_output}\n\n$(_wiz_render_nav)\n\n"

  # Reset field map
  declare -g -a _WIZ_FIELD_MAP=()
  local field_idx=0

  # Helper to add field (used by _wiz_render_screen_content)
  _add_field() {
    local label="$1"
    local value="$2"
    local field_name="$3"
    _WIZ_FIELD_MAP+=("$field_name")
    if [[ $field_idx -eq $selection ]]; then
      output+="${CLR_ORANGE}›${CLR_RESET} ${CLR_GRAY}${label}${CLR_RESET}${value}\n"
    else
      output+="  ${CLR_GRAY}${label}${CLR_RESET}${value}\n"
    fi
    ((field_idx++))
  }

  # Render current screen content
  _wiz_render_screen_content "$WIZ_CURRENT_SCREEN" "$selection"

  # Store total field count for this screen
  declare -g _WIZ_FIELD_COUNT="$field_idx"

  output+="\n"

  # Footer with navigation hints (centered)
  # Left/right/start hints: orange when active, gray when inactive
  local left_clr right_clr start_clr
  left_clr=$([[ $WIZ_CURRENT_SCREEN -gt 0 ]] && echo "$CLR_ORANGE" || echo "$CLR_GRAY")
  right_clr=$([[ $WIZ_CURRENT_SCREEN -lt $((${#WIZ_SCREENS[@]} - 1)) ]] && echo "$CLR_ORANGE" || echo "$CLR_GRAY")
  start_clr=$(_wiz_config_complete && echo "$CLR_ORANGE" || echo "$CLR_GRAY")

  local nav_hint=""
  nav_hint+="[${left_clr}←${CLR_GRAY}] prev  "
  nav_hint+="[${CLR_ORANGE}↑↓${CLR_GRAY}] navigate  [${CLR_ORANGE}Enter${CLR_GRAY}] edit  "
  nav_hint+="[${right_clr}→${CLR_GRAY}] next  "
  nav_hint+="[${start_clr}S${CLR_GRAY}] start  [${CLR_ORANGE}Q${CLR_GRAY}] quit"

  output+="$(_wiz_center "${CLR_GRAY}${nav_hint}${CLR_RESET}")"

  # Clear screen and output everything atomically
  _wiz_clear
  printf '%b' "$output"
}
# shellcheck shell=bash
# Configuration Wizard - Input Helpers
# Reusable input patterns, validation, and editor helpers

# Validated input helper

# Input with validation loop. $1=var, $2=validate_func, $3=error_msg, $@=gum args
_wiz_input_validated() {
  local var_name="$1"
  local validate_func="$2"
  local error_msg="$3"
  shift 3

  while true; do
    _wiz_start_edit
    _show_input_footer

    local value
    value=$(_wiz_input "$@")

    # Empty means cancelled
    [[ -z $value ]] && return 1

    if "$validate_func" "$value"; then
      declare -g "$var_name=$value"
      return 0
    fi

    show_validation_error "$error_msg"
  done
}

# Filter select helper

# Filter list and set variable. $1=var, $2=prompt, $3=data, $4=height (optional)
_wiz_filter_select() {
  local var_name="$1"
  local prompt="$2"
  local data="$3"
  local height="${4:-6}"

  _wiz_start_edit
  _show_input_footer "filter" "$height"

  local selected
  if ! selected=$(printf '%s' "$data" | _wiz_filter --prompt "$prompt"); then
    return 1
  fi

  declare -g "$var_name=$selected"
}

# Password editor helper

# Password editor (Generate/Manual). $1=var, $2=header, $3=success_msg, $4=label, $5=set_generated
_wiz_password_editor() {
  local var_name="$1"
  local header="$2"
  local success_msg="$3"
  local display_label="$4"
  local set_generated="${5:-no}"

  while true; do
    _wiz_start_edit

    # 1 header + 2 options (Manual/Generate)
    _show_input_footer "filter" 3

    local choice
    if ! choice=$(printf '%s\n' "$WIZ_PASSWORD_OPTIONS" | _wiz_choose --header="$header"); then
      return 1
    fi

    case "$choice" in
      "Generate password")
        local generated_pass
        generated_pass=$(generate_password "$DEFAULT_PASSWORD_LENGTH")

        # Set the target variable using declare -g
        declare -g "$var_name=$generated_pass"

        # Optionally set PASSWORD_GENERATED flag
        [[ $set_generated == "yes" ]] && PASSWORD_GENERATED="yes"

        _wiz_start_edit
        _wiz_hide_cursor
        _wiz_warn "Please save this password - $success_msg"
        _wiz_blank_line
        printf '%s\n' "${WIZ_NOTIFY_INDENT}${CLR_CYAN}${display_label}${CLR_RESET} ${CLR_ORANGE}${generated_pass}${CLR_RESET}"
        _wiz_blank_line
        printf '%s\n' "${WIZ_NOTIFY_INDENT}${CLR_GRAY}Press any key to continue...${CLR_RESET}"
        read -n 1 -s -r
        return 0
        ;;
      "Manual entry")
        _wiz_start_edit
        _show_input_footer

        local new_password
        new_password=$(
          _wiz_input \
            --password \
            --placeholder "Enter password" \
            --prompt "${header} "
        )

        # If empty or cancelled, continue loop
        if [[ -z $new_password ]]; then
          continue
        fi

        # Validate password
        local password_error
        password_error=$(get_password_error "$new_password")
        if [[ -n $password_error ]]; then
          show_validation_error "$password_error"
          continue
        fi

        # Password is valid - set the target variable
        declare -g "$var_name=$new_password"

        # Clear PASSWORD_GENERATED if set_generated mode
        [[ $set_generated == "yes" ]] && PASSWORD_GENERATED="no"

        return 0
        ;;
    esac
  done
}

# Choose with mapping helper

# Chooser with display→internal mapping. $1=var, $2=header, $@="Display:internal" pairs
_wiz_choose_mapped() {
  local var_name="$1"
  local header="$2"
  shift 2

  # Build mapping and options list from pairs
  local -A mapping=()
  local options=""
  for pair in "$@"; do
    local display="${pair%%:*}"
    local internal="${pair#*:}"
    mapping["$display"]="$internal"
    [[ -n $options ]] && options+=$'\n'
    options+="$display"
  done

  local selected
  if ! selected=$(printf '%s\n' "$options" | _wiz_choose --header="$header"); then
    return 1
  fi

  # Look up internal value and set variable
  local internal_value="${mapping[$selected]:-}"
  if [[ -n $internal_value ]]; then
    declare -g "$var_name=$internal_value"
  fi

  return 0
}

# Toggle (Enabled/Disabled) helper

# Toggle Enabled/Disabled. $1=var, $2=header, $3=default. Returns: 0=disabled, 1=cancel, 2=enabled
_wiz_toggle() {
  local var_name="$1"
  local header="$2"
  local default_on_cancel="${3:-no}"

  local selected
  if ! selected=$(printf '%s\n' "Enabled" "Disabled" | _wiz_choose --header="$header"); then
    declare -g "$var_name=$default_on_cancel"
    return 1
  fi

  if [[ $selected == "Enabled" ]]; then
    declare -g "$var_name=yes"
    return 2
  else
    declare -g "$var_name=no"
    return 0
  fi
}

# Feature checkbox editor helper

# Feature multi-select. $1=header, $2=footer_size, $3=options_var, $@="feature:VAR" pairs
_wiz_feature_checkbox() {
  local header="$1"
  local footer_size="$2"
  local options_var="$3"
  shift 3

  _show_input_footer "checkbox" "$footer_size"

  # Build gum args with pre-selected items
  local gum_args=(--header="$header")
  local feature_map=()

  for pair in "$@"; do
    local feature="${pair%%:*}"
    local var_name="${pair#*:}"
    feature_map+=("$feature:$var_name")

    # Check if currently selected
    local current_value
    current_value="${!var_name}"
    [[ $current_value == "yes" ]] && gum_args+=(--selected "$feature")
  done

  # Show multi-select chooser
  local selected
  if ! selected=$(printf '%s\n' "${!options_var}" | _wiz_choose_multi "${gum_args[@]}"); then
    return 1
  fi

  # Update all feature variables based on selection
  for pair in "${feature_map[@]}"; do
    local feature="${pair%%:*}"
    local var_name="${pair#*:}"

    if [[ $selected == *"$feature"* ]]; then
      declare -g "$var_name=yes"
    else
      declare -g "$var_name=no"
    fi
  done

  return 0
}
# shellcheck shell=bash
# Configuration Wizard - Locale Helpers
# Country to locale mapping

# Map country code to locale. $1=country_code → locale
_country_to_locale() {
  local country="${1:-us}"
  country="${country,,}" # lowercase

  # Common country to language mappings
  case "$country" in
    us | gb | au | nz | ca | ie) echo "en_${country^^}.UTF-8" ;;
    ru) echo "ru_RU.UTF-8" ;;
    ua) echo "uk_UA.UTF-8" ;;
    de | at) echo "de_${country^^}.UTF-8" ;;
    fr | be) echo "fr_${country^^}.UTF-8" ;;
    es | mx | ar | co | cl | pe) echo "es_${country^^}.UTF-8" ;;
    pt | br) echo "pt_${country^^}.UTF-8" ;;
    it) echo "it_IT.UTF-8" ;;
    nl) echo "nl_NL.UTF-8" ;;
    pl) echo "pl_PL.UTF-8" ;;
    cz) echo "cs_CZ.UTF-8" ;;
    sk) echo "sk_SK.UTF-8" ;;
    hu) echo "hu_HU.UTF-8" ;;
    ro) echo "ro_RO.UTF-8" ;;
    bg) echo "bg_BG.UTF-8" ;;
    hr) echo "hr_HR.UTF-8" ;;
    rs) echo "sr_RS.UTF-8" ;;
    si) echo "sl_SI.UTF-8" ;;
    se) echo "sv_SE.UTF-8" ;;
    no) echo "nb_NO.UTF-8" ;;
    dk) echo "da_DK.UTF-8" ;;
    fi) echo "fi_FI.UTF-8" ;;
    ee) echo "et_EE.UTF-8" ;;
    lv) echo "lv_LV.UTF-8" ;;
    lt) echo "lt_LT.UTF-8" ;;
    gr) echo "el_GR.UTF-8" ;;
    tr) echo "tr_TR.UTF-8" ;;
    il) echo "he_IL.UTF-8" ;;
    jp) echo "ja_JP.UTF-8" ;;
    cn) echo "zh_CN.UTF-8" ;;
    tw) echo "zh_TW.UTF-8" ;;
    kr) echo "ko_KR.UTF-8" ;;
    in) echo "hi_IN.UTF-8" ;;
    th) echo "th_TH.UTF-8" ;;
    vn) echo "vi_VN.UTF-8" ;;
    id) echo "id_ID.UTF-8" ;;
    my) echo "ms_MY.UTF-8" ;;
    ph) echo "en_PH.UTF-8" ;;
    sg) echo "en_SG.UTF-8" ;;
    za) echo "en_ZA.UTF-8" ;;
    eg) echo "ar_EG.UTF-8" ;;
    sa) echo "ar_SA.UTF-8" ;;
    ae) echo "ar_AE.UTF-8" ;;
    ir) echo "fa_IR.UTF-8" ;;
    *)
      log_warn "Unknown country code '$country', using en_US.UTF-8 fallback"
      echo "en_US.UTF-8"
      ;;
  esac
}

# Update LOCALE based on COUNTRY selection
_update_locale_from_country() {
  declare -g LOCALE
  LOCALE=$(_country_to_locale "$COUNTRY")
  log_info "Set LOCALE=$LOCALE from COUNTRY=$COUNTRY"
}
# shellcheck shell=bash
# Configuration Wizard - Basic Settings Editors
# hostname, email, password, timezone, keyboard, country

# Edits hostname and domain settings via input dialogs.
# Validates hostname format and updates PVE_HOSTNAME, DOMAIN_SUFFIX, FQDN.
_edit_hostname() {
  _wiz_input_validated "PVE_HOSTNAME" "validate_hostname" "Invalid hostname format" \
    --placeholder "e.g., pve, proxmox, node1" \
    --value "$PVE_HOSTNAME" \
    --prompt "Hostname: " || return

  # Domain input (no validation - accepts any non-empty)
  _wiz_start_edit
  _show_input_footer

  local new_domain
  new_domain=$(
    _wiz_input \
      --placeholder "e.g., local, example.com" \
      --value "$DOMAIN_SUFFIX" \
      --prompt "Domain: "
  )

  # If empty (cancelled), return to menu
  [[ -z $new_domain ]] && return

  declare -g DOMAIN_SUFFIX="$new_domain"
  [[ -n $PVE_HOSTNAME ]] && declare -g FQDN="${PVE_HOSTNAME}.${DOMAIN_SUFFIX}"
}

# Edits admin email address via input dialog.
# Validates email format and updates EMAIL global.
_edit_email() {
  _wiz_input_validated "EMAIL" "validate_email" "Invalid email format" \
    --placeholder "admin@example.com" \
    --value "$EMAIL" \
    --prompt "Email: "
}

# Edits root password via manual entry or generation.
# Shows generated password for user to save.
# Updates NEW_ROOT_PASSWORD and PASSWORD_GENERATED globals.
_edit_password() {
  _wiz_password_editor \
    "NEW_ROOT_PASSWORD" \
    "Root Password:" \
    "it will be required for login" \
    "Generated root password:" \
    "yes"
}

# Edits timezone via searchable filter list.
# Auto-selects country based on timezone if mapping exists.
# Updates TIMEZONE and optionally COUNTRY/LOCALE globals.
_edit_timezone() {
  _wiz_filter_select "TIMEZONE" "Timezone: " "$WIZ_TIMEZONES" || return

  # Auto-select country based on timezone (if mapping exists)
  local country_code="${TZ_TO_COUNTRY[$TIMEZONE]:-}"
  if [[ -n $country_code ]]; then
    declare -g COUNTRY="$country_code"
    _update_locale_from_country
  fi
}

# Edits keyboard layout via searchable filter list.
# Updates KEYBOARD global with selected layout.
_edit_keyboard() {
  _wiz_filter_select "KEYBOARD" "Keyboard: " "$WIZ_KEYBOARD_LAYOUTS"
}

# Edits country code via searchable filter list.
# Updates COUNTRY and LOCALE globals.
_edit_country() {
  _wiz_filter_select "COUNTRY" "Country: " "$WIZ_COUNTRIES" || return
  _update_locale_from_country
}
# shellcheck shell=bash
# Configuration Wizard - Proxmox Settings Editors
# iso_version, repository

# Edits Proxmox ISO version via searchable list.
# Fetches available ISOs (last 5, starting from v9) and updates PROXMOX_ISO_VERSION global.
_edit_iso_version() {
  _wiz_start_edit

  _wiz_description \
    "  Proxmox VE version to install:" \
    "" \
    "  Latest version recommended for new installations." \
    ""

  # Get available ISO versions (last 5, v9+ only, uses cached data from prefetch)
  local iso_list
  iso_list=$(get_available_proxmox_isos 5)

  if [[ -z $iso_list ]]; then
    _wiz_hide_cursor
    _wiz_error "Failed to fetch ISO list"
    _wiz_blank_line
    sleep "${RETRY_DELAY_SECONDS:-2}"
    return
  fi

  # 1 header + 5 items for gum choose
  _show_input_footer "filter" 6

  local selected
  if ! selected=$(printf '%s\n' "$iso_list" | _wiz_choose --header="Proxmox Version:"); then
    return
  fi

  declare -g PROXMOX_ISO_VERSION="$selected"
}

# Edits Proxmox package repository type.
# Prompts for subscription key if enterprise repo selected.
# Updates PVE_REPO_TYPE and PVE_SUBSCRIPTION_KEY globals.
_edit_repository() {
  _wiz_start_edit

  _wiz_description \
    "  Proxmox VE package repository:" \
    "" \
    "  {{cyan:No-subscription}}: Free updates, community tested" \
    "  {{cyan:Enterprise}}:      Stable updates, requires license" \
    "  {{cyan:Test}}:            Latest builds, may be unstable" \
    ""

  # 1 header + 3 items for gum choose
  _show_input_footer "filter" 4

  if ! _wiz_choose_mapped "PVE_REPO_TYPE" "Repository:" \
    "${WIZ_MAP_REPO_TYPE[@]}"; then
    return
  fi

  # If enterprise selected, require subscription key
  if [[ $PVE_REPO_TYPE == "enterprise" ]]; then
    _wiz_input_screen "Enter Proxmox subscription key"

    local sub_key
    sub_key=$(
      _wiz_input \
        --placeholder "pve2c-..." \
        --value "$PVE_SUBSCRIPTION_KEY" \
        --prompt "Subscription Key: "
    )

    declare -g PVE_SUBSCRIPTION_KEY="$sub_key"

    # If no key provided, fallback to no-subscription
    if [[ -z $PVE_SUBSCRIPTION_KEY ]]; then
      declare -g PVE_REPO_TYPE="no-subscription"
      _wiz_hide_cursor
      _wiz_warn "Enterprise repository requires subscription key"
      sleep "${RETRY_DELAY_SECONDS:-2}"
    fi
  else
    # Clear subscription key if not enterprise
    declare -g PVE_SUBSCRIPTION_KEY=""
  fi
}
# shellcheck shell=bash
# Configuration Wizard - Network Settings Editors (Bridge & Basic)
# interface, bridge_mode, private_subnet, bridge_mtu

# Edits primary network interface via selection list.
# Uses cached interface list from system detection.
# Updates INTERFACE_NAME global.
_edit_interface() {
  _wiz_start_edit

  # Get available interfaces (use cached value)
  local interface_count=${INTERFACE_COUNT:-1}
  local available_interfaces=${AVAILABLE_INTERFACES:-$INTERFACE_NAME}

  # Calculate footer size: 1 header + number of interfaces
  local footer_size="$((interface_count + 1))"
  _show_input_footer "filter" "$footer_size"

  local selected
  if ! selected=$(printf '%s\n' "$available_interfaces" | _wiz_choose --header="Network Interface:"); then
    return
  fi

  declare -g INTERFACE_NAME="$selected"
}

# Edits network bridge mode for VM networking.
# Options: internal (NAT), external (routed), both.
# Updates BRIDGE_MODE global.
_edit_bridge_mode() {
  _wiz_start_edit

  _wiz_description \
    "  Network bridge configuration for VMs:" \
    "" \
    "  {{cyan:Internal}}: Private network with NAT (10.x.x.x)" \
    "  {{cyan:External}}: VMs get public IPs directly (routed mode)" \
    "  {{cyan:Both}}:     Internal + External bridges" \
    ""

  # 1 header + 3 items for gum choose
  _show_input_footer "filter" 4

  _wiz_choose_mapped "BRIDGE_MODE" "Bridge mode:" \
    "${WIZ_MAP_BRIDGE_MODE[@]}"
}

# Edits private subnet for NAT bridge.
# Supports preset options or custom CIDR input.
# Updates PRIVATE_SUBNET global.
_edit_private_subnet() {
  _wiz_start_edit

  _wiz_description \
    "  Private network for VMs (NAT to internet):" \
    "" \
    "  {{cyan:10.0.0.0/24}}:    Class A private (default)" \
    "  {{cyan:192.168.1.0/24}}: Class C private (home-style)" \
    "  {{cyan:172.16.0.0/24}}:  Class B private" \
    ""

  # 1 header + 4 items for gum choose
  _show_input_footer "filter" 5

  local selected
  if ! selected=$(printf '%s\n' "$WIZ_PRIVATE_SUBNETS" | _wiz_choose --header="Private subnet:"); then
    return
  fi

  # Handle custom subnet input
  if [[ $selected == "Custom" ]]; then
    while true; do
      _wiz_input_screen \
        "Enter private subnet in CIDR notation" \
        "Example: 10.0.0.0/24"

      local new_subnet
      new_subnet=$(
        _wiz_input \
          --placeholder "e.g., 10.10.10.0/24" \
          --value "$PRIVATE_SUBNET" \
          --prompt "Private subnet: "
      )

      # If empty or cancelled, return to menu
      if [[ -z $new_subnet ]]; then
        return
      fi

      # Validate subnet
      if validate_subnet "$new_subnet"; then
        declare -g PRIVATE_SUBNET="$new_subnet"
        break
      else
        show_validation_error "Invalid subnet format. Use CIDR notation like: 10.0.0.0/24"
      fi
    done
  else
    # Use selected preset
    declare -g PRIVATE_SUBNET="$selected"
  fi
}

# Edits private bridge MTU for VM-to-VM traffic.
# Options: 9000 (jumbo frames) or 1500 (standard).
# Updates BRIDGE_MTU global.
_edit_bridge_mtu() {
  _wiz_start_edit

  _wiz_description \
    "  MTU for private bridge (VM-to-VM traffic):" \
    "" \
    "  {{cyan:9000}}:  Jumbo frames (better VM performance)" \
    "  {{cyan:1500}}:  Standard MTU (safe default)" \
    ""

  # 1 header + 2 items for gum choose
  _show_input_footer "filter" 3

  _wiz_choose_mapped "BRIDGE_MTU" "Bridge MTU:" \
    "${WIZ_MAP_BRIDGE_MTU[@]}"
}
# shellcheck shell=bash
# Configuration Wizard - Network Settings Editors (IPv6 & Firewall)
# ipv6, firewall

# Edits IPv6 configuration mode and address/gateway.
# Modes: auto (detected), manual (custom input), disabled.
# Updates IPV6_MODE, IPV6_ADDRESS, IPV6_GATEWAY, MAIN_IPV6 globals.
_edit_ipv6() {
  _wiz_start_edit

  _wiz_description \
    "  IPv6 network configuration:" \
    "" \
    "  {{cyan:Auto}}:     Use detected IPv6 from provider" \
    "  {{cyan:Manual}}:   Specify custom IPv6 address/gateway" \
    "  {{cyan:Disabled}}: IPv4 only" \
    ""

  # 1 header + 3 items for gum choose
  _show_input_footer "filter" 4

  local selected
  if ! selected=$(printf '%s\n' "$WIZ_IPV6_MODES" | _wiz_choose --header="IPv6:"); then
    return
  fi

  # Map display names to internal values
  local ipv6_mode=""
  case "$selected" in
    "Auto") ipv6_mode="auto" ;;
    "Manual") ipv6_mode="manual" ;;
    "Disabled") ipv6_mode="disabled" ;;
  esac

  declare -g IPV6_MODE="$ipv6_mode"

  # Handle manual mode - need to collect IPv6 address and gateway
  if [[ $ipv6_mode == "manual" ]]; then
    # IPv6 Address input
    while true; do
      _wiz_input_screen \
        "Enter IPv6 address in CIDR notation" \
        "Example: 2001:db8::1/64"

      local ipv6_addr
      ipv6_addr=$(
        _wiz_input \
          --placeholder "2001:db8::1/64" \
          --prompt "IPv6 Address: " \
          --value "${IPV6_ADDRESS:-${FIRST_IPV6_CIDR:-$MAIN_IPV6}}"
      )

      # If empty or cancelled, exit manual mode
      if [[ -z $ipv6_addr ]]; then
        IPV6_MODE=""
        return
      fi

      # Validate IPv6 CIDR
      if validate_ipv6_cidr "$ipv6_addr"; then
        declare -g IPV6_ADDRESS="$ipv6_addr"
        declare -g MAIN_IPV6="${ipv6_addr%/*}"
        break
      else
        show_validation_error "Invalid IPv6 CIDR notation. Use format like: 2001:db8::1/64"
      fi
    done

    # IPv6 Gateway input
    while true; do
      _wiz_input_screen \
        "Enter IPv6 gateway address" \
        "Common default: fe80::1 (link-local)"

      local ipv6_gw
      ipv6_gw=$(
        _wiz_input \
          --placeholder "fe80::1" \
          --prompt "Gateway: " \
          --value "${IPV6_GATEWAY:-$DEFAULT_IPV6_GATEWAY}"
      )

      # If empty or cancelled, use default
      if [[ -z $ipv6_gw ]]; then
        declare -g IPV6_GATEWAY="$DEFAULT_IPV6_GATEWAY"
        break
      fi

      # Validate IPv6 gateway
      if validate_ipv6_gateway "$ipv6_gw"; then
        declare -g IPV6_GATEWAY="$ipv6_gw"
        break
      else
        show_validation_error "Invalid IPv6 gateway address"
      fi
    done
  elif [[ $ipv6_mode == "disabled" ]]; then
    # Clear IPv6 settings when disabled
    declare -g MAIN_IPV6=""
    declare -g IPV6_GATEWAY=""
    declare -g FIRST_IPV6_CIDR=""
    declare -g IPV6_ADDRESS=""
  elif [[ $ipv6_mode == "auto" ]]; then
    # Auto mode - use detected values or defaults
    declare -g IPV6_GATEWAY="${IPV6_GATEWAY:-$DEFAULT_IPV6_GATEWAY}"
  fi
}

# Edits host firewall mode.
# Modes: stealth (Tailscale only), strict (SSH), standard (SSH+Web), disabled.
# Updates INSTALL_FIREWALL and FIREWALL_MODE globals.
_edit_firewall() {
  _wiz_start_edit

  _wiz_description \
    "  Host firewall (nftables):" \
    "" \
    "  {{cyan:Stealth}}:  Blocks ALL incoming (Tailscale/bridges only)" \
    "  {{cyan:Strict}}:   Allows SSH only (port 22)" \
    "  {{cyan:Standard}}: Allows SSH + Proxmox Web UI (443)" \
    "  {{cyan:Disabled}}: No firewall rules" \
    "" \
    "  Note: VMs always have full network access via bridges." \
    ""

  # 1 header + 4 items for gum choose
  _show_input_footer "filter" 5

  local selected
  if ! selected=$(printf '%s\n' "$WIZ_FIREWALL_MODES" | _wiz_choose --header="Firewall mode:"); then
    return
  fi

  case "$selected" in
    "Stealth (Tailscale only)")
      declare -g INSTALL_FIREWALL="yes"
      declare -g FIREWALL_MODE="stealth"
      ;;
    "Strict (SSH only)")
      declare -g INSTALL_FIREWALL="yes"
      declare -g FIREWALL_MODE="strict"
      ;;
    "Standard (SSH + Web UI)")
      declare -g INSTALL_FIREWALL="yes"
      declare -g FIREWALL_MODE="standard"
      ;;
    "Disabled")
      declare -g INSTALL_FIREWALL="no"
      declare -g FIREWALL_MODE=""
      ;;
  esac
}
# shellcheck shell=bash
# Configuration Wizard - Storage Settings Editors
# wipe_disks, zfs_mode, zfs_arc, existing_pool

# Edits disk wipe setting (full wipe vs keep existing).
# Updates WIPE_DISKS global. Auto-disabled when using existing pool.
_edit_wipe_disks() {
  _wiz_start_edit

  # Auto-disable if using existing pool
  if [[ $USE_EXISTING_POOL == "yes" ]]; then
    _wiz_hide_cursor
    _wiz_description \
      "  {{yellow:⚠ Disk wipe is disabled when using existing pool}}" \
      "" \
      "  Existing pool data must be preserved."
    sleep "${WIZARD_MESSAGE_DELAY:-3}"
    declare -g WIPE_DISKS="no"
    return
  fi

  _wiz_description \
    "  Clean disks before installation:" \
    "" \
    "  {{cyan:Yes}}: Wipe all selected disks (removes old partitions," \
    "       LVM, ZFS pools, mdadm arrays). Like fresh drives." \
    "  {{cyan:No}}:  Only release locks, keep existing structures." \
    "" \
    "  {{yellow:WARNING}}: Full wipe DESTROYS all data on selected disks!" \
    ""

  _show_input_footer "filter" 3

  _wiz_choose_mapped "WIPE_DISKS" "Wipe disks before install:" \
    "${WIZ_MAP_WIPE_DISKS[@]}"
}

# Edits existing pool setting (use existing vs create new).
# Updates USE_EXISTING_POOL and EXISTING_POOL_NAME globals.
# Uses DETECTED_POOLS array populated during system detection.
_edit_existing_pool() {
  _wiz_start_edit

  # Use pre-detected pools from DETECTED_POOLS (populated by _detect_pools)
  if [[ ${#DETECTED_POOLS[@]} -eq 0 ]]; then
    _wiz_hide_cursor
    _wiz_description \
      "  {{yellow:⚠ No importable ZFS pools detected}}" \
      "" \
      "  Possible causes:" \
      "    • ZFS not installed (check log for errors)" \
      "    • Pool not exported before reboot" \
      "    • Pool already imported (zpool list)" \
      "    • Pool metadata corrupted" \
      "" \
      "  Try manually: {{cyan:zpool import -d /dev}}"
    sleep "${WIZARD_MESSAGE_DELAY:-3}"
    return
  fi

  _wiz_description \
    "  Preserve existing ZFS pool during reinstall:" \
    "" \
    "  {{cyan:Create new}}: Format pool disks, create fresh ZFS pool" \
    "  {{cyan:Use existing}}: Import pool, preserve all VMs and data" \
    "" \
    "  {{yellow:WARNING}}: Using existing pool skips disk formatting." \
    "  Ensure the pool is healthy before proceeding." \
    ""

  # Build options: "Create new pool" + detected pools
  local options="Create new pool (format disks)"
  for pool_info in "${DETECTED_POOLS[@]}"; do
    local pool_name="${pool_info%%|*}"
    local rest="${pool_info#*|}"
    local pool_state="${rest%%|*}"
    options+=$'\n'"Use existing: ${pool_name} (${pool_state})"
  done

  local item_count
  item_count=$(wc -l <<<"$options")
  _show_input_footer "filter" "$((item_count + 1))"

  local selected
  if ! selected=$(printf '%s\n' "$options" | _wiz_choose --header="Pool mode:"); then
    return
  fi

  if [[ $selected == "Create new pool (format disks)" ]]; then
    declare -g USE_EXISTING_POOL=""
    declare -g EXISTING_POOL_NAME=""
    declare -g -a EXISTING_POOL_DISKS=()
  elif [[ $selected =~ ^Use\ existing:\ (.+)\ \( ]]; then
    # Check if boot disk is set - required for existing pool mode
    if [[ -z $BOOT_DISK ]]; then
      _wiz_start_edit
      _wiz_hide_cursor
      _wiz_description \
        "  {{red:✗ Cannot use existing pool without separate boot disk}}" \
        "" \
        "  Select a boot disk first, then enable existing pool." \
        "  The boot disk will be formatted for Proxmox system files."
      sleep "${WIZARD_MESSAGE_DELAY:-3}"
      return
    fi

    local pool_name="${BASH_REMATCH[1]}"

    # Get disks for this pool (comma-separated device paths)
    # Note: Linux device paths never contain commas, so simple CSV parsing is safe
    local disks_csv
    disks_csv=$(get_pool_disks "$pool_name")
    local pool_disks=()
    while IFS= read -r disk; do
      [[ -n $disk ]] && pool_disks+=("$disk")
    done < <(tr ',' '\n' <<<"$disks_csv")

    # Check if boot disk is part of this pool (would destroy the pool!)
    local boot_in_pool=false
    for disk in "${pool_disks[@]}"; do
      if [[ $disk == "$BOOT_DISK" ]]; then
        boot_in_pool=true
        break
      fi
    done

    if [[ $boot_in_pool == true ]]; then
      _wiz_start_edit
      _wiz_hide_cursor
      _wiz_description \
        "  {{red:✗ Boot disk conflict!}}" \
        "" \
        "  Boot disk $BOOT_DISK is part of pool '$pool_name'." \
        "  Installing Proxmox on this disk will DESTROY the pool!" \
        "" \
        "  Options:" \
        "    1. Select a different boot disk (not in this pool)" \
        "    2. Create a new pool instead of using existing"
      sleep "${WIZARD_MESSAGE_DELAY:-3}"
      return
    fi

    declare -g USE_EXISTING_POOL="yes"
    declare -g EXISTING_POOL_NAME="$pool_name"
    declare -g -a EXISTING_POOL_DISKS=("${pool_disks[@]}")

    # Clear pool disks since we won't be creating new pool
    declare -g -a ZFS_POOL_DISKS=()
    declare -g ZFS_RAID=""

    log_info "Selected existing pool: $EXISTING_POOL_NAME with disks: ${EXISTING_POOL_DISKS[*]}"
  fi
}

# Edits ZFS RAID level for data pool.
# Options vary based on pool disk count (single, raid0/1, raidz1/2/3, raid10).
# Updates ZFS_RAID global.
_edit_zfs_mode() {
  _wiz_start_edit

  # Require pool disks to be selected first
  if [[ ${#ZFS_POOL_DISKS[@]} -eq 0 ]]; then
    _wiz_hide_cursor
    _wiz_description "  {{yellow:⚠ No disks selected for ZFS pool}}" "" \
      "  Select pool disks first, then configure RAID level."
    sleep "${WIZARD_MESSAGE_DELAY:-3}" && return
  fi

  _wiz_description \
    "  ZFS RAID level for data pool:" \
    "" \
    "  {{cyan:RAID-0}}:  Max capacity, no redundancy (all disks)" \
    "  {{cyan:RAID-1}}:  Mirror, 50% capacity (2+ disks)" \
    "  {{cyan:RAID-Z1}}: Single parity, N-1 capacity (3+ disks)" \
    "  {{cyan:RAID-Z2}}: Double parity, N-2 capacity (4+ disks)" \
    "  {{cyan:RAID-10}}: Striped mirrors (4+ disks, even count)" \
    ""

  # Use pool disk count, not total DRIVE_COUNT
  local pool_count="${#ZFS_POOL_DISKS[@]}"

  # Build options based on pool count
  local options=""
  if [[ $pool_count -eq 1 ]]; then
    options="Single disk"
  elif [[ $pool_count -eq 2 ]]; then
    options="RAID-0 (striped)
RAID-1 (mirror)"
  elif [[ $pool_count -eq 3 ]]; then
    options="RAID-0 (striped)
RAID-1 (mirror)
RAID-Z1 (parity)"
  elif [[ $pool_count -eq 4 ]]; then
    options="RAID-0 (striped)
RAID-1 (mirror)
RAID-Z1 (parity)
RAID-Z2 (double parity)
RAID-10 (striped mirrors)"
  elif [[ $pool_count -ge 5 ]]; then
    options="RAID-0 (striped)
RAID-1 (mirror)
RAID-Z1 (parity)
RAID-Z2 (double parity)
RAID-Z3 (triple parity)
RAID-10 (striped mirrors)"
  fi

  local item_count
  item_count=$(wc -l <<<"$options")
  _show_input_footer "filter" "$((item_count + 1))"

  local selected
  if ! selected=$(printf '%s\n' "$options" | _wiz_choose --header="ZFS mode (${pool_count} disks in pool):"); then
    return
  fi

  case "$selected" in
    "Single disk") declare -g ZFS_RAID="single" ;;
    "RAID-0 (striped)") declare -g ZFS_RAID="raid0" ;;
    "RAID-1 (mirror)") declare -g ZFS_RAID="raid1" ;;
    "RAID-Z1 (parity)") declare -g ZFS_RAID="raidz1" ;;
    "RAID-Z2 (double parity)") declare -g ZFS_RAID="raidz2" ;;
    "RAID-Z3 (triple parity)") declare -g ZFS_RAID="raidz3" ;;
    "RAID-10 (striped mirrors)") declare -g ZFS_RAID="raid10" ;;
  esac
}

# Edits ZFS ARC memory allocation strategy.
# Options: vm-focused (4GB), balanced (25-40%), storage-focused (50%).
# Updates ZFS_ARC_MODE global.
_edit_zfs_arc() {
  _wiz_start_edit

  _wiz_description \
    "  ZFS Adaptive Replacement Cache (ARC) memory allocation:" \
    "" \
    "  {{cyan:VM-focused}}:      Fixed 4GB for ARC (more RAM for VMs)" \
    "  {{cyan:Balanced}}:        25-40% of RAM based on total size" \
    "  {{cyan:Storage-focused}}: 50% of RAM (maximize ZFS caching)" \
    ""

  # 1 header + 3 options
  _show_input_footer "filter" 4

  _wiz_choose_mapped "ZFS_ARC_MODE" "ZFS ARC memory strategy:" \
    "${WIZ_MAP_ZFS_ARC[@]}"
}
# shellcheck shell=bash
# Configuration Wizard - SSL Settings Editors

# Validate FQDN for Let's Encrypt. Returns 0=valid, 1=missing, 2=invalid
_ssl_validate_fqdn() {
  if [[ -z $FQDN ]]; then
    _wiz_start_edit
    _wiz_hide_cursor
    _wiz_description \
      "  {{red:✗ Hostname not configured!}}" \
      "" \
      "  Let's Encrypt requires a fully qualified domain name." \
      "  Please configure hostname first."
    sleep "${WIZARD_MESSAGE_DELAY:-3}"
    return 1
  fi

  if [[ $FQDN == *.local ]] || ! validate_fqdn "$FQDN"; then
    _wiz_start_edit
    _wiz_hide_cursor
    _wiz_description \
      "  {{red:✗ Invalid domain name!}}" \
      "" \
      "  Current hostname: {{orange:${FQDN}}}" \
      "  Let's Encrypt requires a valid public FQDN (e.g., pve.example.com)." \
      "  Domains ending with .local are not supported."
    sleep "${WIZARD_MESSAGE_DELAY:-3}"
    return 2
  fi

  return 0
}

# Run DNS validation with progress. Returns 0=ok, 1=no resolve, 2=wrong IP
_ssl_check_dns_animated() {
  _wiz_start_edit
  _wiz_hide_cursor
  _wiz_blank_line
  _wiz_dim "Domain: ${CLR_ORANGE}${FQDN}${CLR_RESET}"
  _wiz_dim "Expected IP: ${CLR_ORANGE}${MAIN_IPV4}${CLR_RESET}"
  _wiz_blank_line

  local dns_result_file=""
  dns_result_file=$(mktemp) || {
    log_error "mktemp failed for dns_result_file"
    return 1
  }
  register_temp_file "$dns_result_file"

  (
    validate_dns_resolution "$FQDN" "$MAIN_IPV4"
    local result=$?
    printf '%s\n' "$DNS_RESOLVED_IP" >"$dns_result_file"
    exit $result
  ) >/dev/null 2>&1 &

  local dns_pid="$!"

  show_progress "$dns_pid" "Validating DNS resolution" --silent
  local dns_result=$?

  read -r DNS_RESOLVED_IP <"$dns_result_file"
  rm -f "$dns_result_file"

  return "$dns_result"
}

# Show DNS error and fallback to self-signed. $1=error_type (1=no resolve, 2=wrong IP)
_ssl_show_dns_error() {
  local error_type="$1"

  _wiz_hide_cursor
  if [[ $error_type -eq 1 ]]; then
    _wiz_description \
      "  {{red:✗ Domain does not resolve to any IP address}}" \
      "" \
      "  Please configure DNS A record:" \
      "  {{orange:${FQDN}}} → {{orange:${MAIN_IPV4}}}" \
      "" \
      "  Falling back to self-signed certificate."
  else
    _wiz_description \
      "  {{red:✗ Domain resolves to wrong IP address}}" \
      "" \
      "  Current DNS: {{orange:${FQDN}}} → {{red:${DNS_RESOLVED_IP}}}" \
      "  Expected:    {{orange:${FQDN}}} → {{orange:${MAIN_IPV4}}}" \
      "" \
      "  Please update DNS A record to point to {{orange:${MAIN_IPV4}}}" \
      "" \
      "  Falling back to self-signed certificate."
  fi
  sleep "$((${WIZARD_MESSAGE_DELAY:-3} + 2))"
}

# Validate Let's Encrypt requirements. Returns 0=valid, 1=fallback to self-signed
_ssl_validate_letsencrypt() {
  _ssl_validate_fqdn || return 1

  local dns_result
  _ssl_check_dns_animated
  dns_result="$?"

  if [[ $dns_result -ne 0 ]]; then
    _ssl_show_dns_error "$dns_result"
    return 1
  fi

  _wiz_info "DNS resolution successful"
  _wiz_dim "${CLR_ORANGE}${FQDN}${CLR_RESET} → ${CLR_CYAN}${DNS_RESOLVED_IP}${CLR_RESET}"
  sleep "${WIZARD_MESSAGE_DELAY:-3}"
  return 0
}

# Edits SSL certificate type for Proxmox web interface.
# Validates FQDN and DNS resolution for Let's Encrypt.
# Updates SSL_TYPE global. Falls back to self-signed on validation failure.
_edit_ssl() {
  _wiz_start_edit

  _wiz_description \
    "  SSL certificate for Proxmox web interface:" \
    "" \
    "  {{cyan:Self-signed}}:   Works always, browser shows warning" \
    "  {{cyan:Let's Encrypt}}: Trusted cert, requires public DNS" \
    ""

  _show_input_footer "filter" 3

  if ! _wiz_choose_mapped "SSL_TYPE" "SSL Certificate:" \
    "${WIZ_MAP_SSL_TYPE[@]}"; then
    return
  fi

  # Validate Let's Encrypt requirements, fallback to self-signed if not met
  if [[ $SSL_TYPE == "letsencrypt" ]]; then
    if ! _ssl_validate_letsencrypt; then
      declare -g SSL_TYPE="self-signed"
    fi
  fi
}
# shellcheck shell=bash
# Configuration Wizard - Tailscale Settings Editors

# Prompts for Tailscale auth key with validation.
# Sets _TAILSCALE_TMP_KEY on success, clears on cancel.
_tailscale_get_auth_key() {
  declare -g _TAILSCALE_TMP_KEY=""
  _wiz_input_validated "_TAILSCALE_TMP_KEY" "validate_tailscale_key" \
    "Invalid key format. Expected: tskey-auth-xxx-xxx" \
    --placeholder "tskey-auth-..." \
    --prompt "Auth Key: "
}

# Prompt for Tailscale Web UI config. Sets TAILSCALE_WEBUI.
_tailscale_configure_webui() {
  _wiz_start_edit
  _wiz_description \
    "  Expose Proxmox Web UI via Tailscale Serve?" \
    "" \
    "  {{cyan:Enabled}}:  Access Web UI at https://<tailscale-hostname>" \
    "  {{cyan:Disabled}}: Web UI only via direct IP" \
    "" \
    "  Uses: tailscale serve --bg --https=443 https://127.0.0.1:8006" \
    ""

  _show_input_footer "filter" 3

  _wiz_toggle "TAILSCALE_WEBUI" "Tailscale Web UI:" "no"
}

# Enable Tailscale with auth key. $1=auth_key
_tailscale_enable() {
  local auth_key="$1"

  declare -g INSTALL_TAILSCALE="yes"
  declare -g TAILSCALE_AUTH_KEY="$auth_key"

  _tailscale_configure_webui

  declare -g SSL_TYPE="self-signed"
  if [[ -z $INSTALL_FIREWALL ]]; then
    declare -g INSTALL_FIREWALL="yes"
    declare -g FIREWALL_MODE="stealth"
  fi
}

# Disable Tailscale and clear related settings
_tailscale_disable() {
  declare -g INSTALL_TAILSCALE="no"
  declare -g TAILSCALE_AUTH_KEY=""
  declare -g TAILSCALE_WEBUI=""
  declare -g SSL_TYPE=""
  if [[ -z $INSTALL_FIREWALL ]]; then
    declare -g INSTALL_FIREWALL="yes"
    declare -g FIREWALL_MODE="standard"
  fi
}

# Edit Tailscale VPN configuration
_edit_tailscale() {
  _wiz_start_edit

  _wiz_description \
    "  Tailscale VPN with stealth mode:" \
    "" \
    "  {{cyan:Enabled}}:  Access via Tailscale only (blocks public SSH)" \
    "  {{cyan:Disabled}}: Standard access via public IP" \
    "" \
    "  Stealth mode blocks ALL incoming traffic on public IP." \
    ""

  _show_input_footer "filter" 3

  local result
  _wiz_toggle "INSTALL_TAILSCALE" "Tailscale:"
  result="$?"

  if [[ $result -eq 1 ]]; then
    return
  elif [[ $result -eq 2 ]]; then
    # Enabled - get auth key
    if _tailscale_get_auth_key && [[ -n $_TAILSCALE_TMP_KEY ]]; then
      _tailscale_enable "$_TAILSCALE_TMP_KEY"
    else
      _tailscale_disable
    fi
  else
    _tailscale_disable
  fi
}
# shellcheck shell=bash
# Configuration Wizard - Admin User & API Token Editors

# Edits non-root admin username for SSH and Proxmox access.
# Validates username format (lowercase, no reserved names).
# Updates ADMIN_USERNAME global.
_edit_admin_username() {
  while true; do
    _wiz_start_edit

    _wiz_description \
      "  Non-root admin username for SSH and Proxmox access:" \
      "" \
      "  Root SSH login will be {{cyan:completely disabled}}." \
      "  All SSH access must use this admin account." \
      "  The admin user will have sudo privileges." \
      ""

    _show_input_footer

    local new_username
    new_username=$(
      _wiz_input \
        --placeholder "e.g., sysadmin, deploy, operator" \
        --value "$ADMIN_USERNAME" \
        --prompt "Admin username: "
    )

    # If empty (cancelled), return to menu
    if [[ -z $new_username ]]; then
      return
    fi

    # Validate username
    if validate_admin_username "$new_username"; then
      declare -g ADMIN_USERNAME="$new_username"
      break
    else
      show_validation_error "Invalid username. Use lowercase letters/numbers, 1-32 chars. Reserved names (root, admin) not allowed."
    fi
  done
}

# Edits admin password via manual entry or generation.
# Shows generated password for user to save.
# Updates ADMIN_PASSWORD global.
_edit_admin_password() {
  _wiz_password_editor \
    "ADMIN_PASSWORD" \
    "Admin Password:" \
    "it will be required for sudo and Proxmox UI" \
    "Generated admin password:"
}

# API Token Editor

# Edits Proxmox API token creation settings.
# Prompts for token name if enabled (default: automation).
# Updates INSTALL_API_TOKEN and API_TOKEN_NAME globals.
_edit_api_token() {
  _wiz_start_edit

  _wiz_description \
    "  Proxmox API token for automation:" \
    "" \
    "  {{cyan:Enabled}}:  Create privileged token (Terraform, Ansible)" \
    "  {{cyan:Disabled}}: No API token" \
    "" \
    "  Token has full Administrator permissions, no expiration." \
    ""

  # 1 header + 2 items for gum choose
  _show_input_footer "filter" 3

  local result
  _wiz_toggle "INSTALL_API_TOKEN" "API Token (privileged, no expiration):"
  result="$?"

  [[ $result -eq 1 ]] && return
  [[ $result -ne 2 ]] && return

  # Enabled - request token name
  _wiz_input_screen "Enter API token name (default: automation)"

  local token_name
  token_name=$(_wiz_input \
    --placeholder "automation" \
    --prompt "Token name: " \
    --no-show-help \
    --value="${API_TOKEN_NAME:-automation}")

  # Validate: alphanumeric, dash, underscore only
  if [[ -n $token_name && $token_name =~ ^[a-zA-Z0-9_-]+$ ]]; then
    declare -g API_TOKEN_NAME="$token_name"
  else
    declare -g API_TOKEN_NAME="automation"
  fi
}
# shellcheck shell=bash
# Configuration Wizard - SSH Key Editor

# Edits SSH public key for admin user access.
# Auto-detects key from Rescue System if available.
# Validates key format using ssh-keygen. Updates SSH_PUBLIC_KEY global.
_edit_ssh_key() {
  while true; do
    _wiz_start_edit

    # Detect SSH key from Rescue System
    local detected_key
    detected_key=$(get_rescue_ssh_key)

    # If key detected, show menu with auto-detect option
    if [[ -n $detected_key ]]; then
      # Parse detected key for display
      parse_ssh_key "$detected_key"

      _wiz_hide_cursor
      _wiz_warn "Detected SSH key from Rescue System:"
      _wiz_blank_line
      printf '%s\n' "${WIZ_NOTIFY_INDENT}${CLR_GRAY}Type:${CLR_RESET}    ${SSH_KEY_TYPE}"
      printf '%s\n' "${WIZ_NOTIFY_INDENT}${CLR_GRAY}Key:${CLR_RESET}     ${SSH_KEY_SHORT}"
      [[ -n $SSH_KEY_COMMENT ]] && printf '%s\n' "${WIZ_NOTIFY_INDENT}${CLR_GRAY}Comment:${CLR_RESET} ${SSH_KEY_COMMENT}"
      _wiz_blank_line

      # 1 header + 2 options
      _show_input_footer "filter" 3

      local choice
      choice=$(
        printf '%s\n' "$WIZ_SSH_KEY_OPTIONS" | _wiz_choose \
          --header="SSH Key:"
      )

      # If user cancelled (Esc)
      if [[ -z $choice ]]; then
        return
      fi

      case "$choice" in
        "Use detected key")
          declare -g SSH_PUBLIC_KEY="$detected_key"
          break
          ;;
        "Enter different key")
          # Fall through to manual entry below
          ;;
      esac
    fi

    # Manual entry
    _wiz_input_screen "Paste your SSH public key (ssh-rsa, ssh-ed25519, etc.)"

    local new_key
    new_key=$(
      _wiz_input \
        --placeholder "ssh-ed25519 AAAA... user@host" \
        --value "$SSH_PUBLIC_KEY" \
        --prompt "SSH Key: "
    )

    # If empty or cancelled, check if we had detected key
    if [[ -z $new_key ]]; then
      # If we had a detected key, return to menu
      if [[ -n $detected_key ]]; then
        continue
      else
        # No detected key, just return
        return
      fi
    fi

    # Validate the entered key (secure validation with ssh-keygen)
    if validate_ssh_key_secure "$new_key"; then
      declare -g SSH_PUBLIC_KEY="$new_key"
      break
    else
      show_validation_error "Invalid SSH key. Must be ED25519, RSA/ECDSA ≥2048 bits"
      # If we had a detected key, return to menu, otherwise retry manual entry
      if [[ -n $detected_key ]]; then
        continue
      fi
    fi
  done
}
# shellcheck shell=bash
# Configuration Wizard - Disk Selection
# boot_disk, pool_disks

# Edits boot disk selection for ext4 system partition.
# Options: none (all in rpool) or select specific disk.
# Updates BOOT_DISK global and rebuilds pool disk list.
_edit_boot_disk() {
  _wiz_start_edit

  # Show description about boot disk modes
  _wiz_description \
    "  Separate boot disk selection (auto-detected by disk size):" \
    "" \
    "  {{cyan:None}}: All disks in ZFS rpool (system + VMs)" \
    "  {{cyan:Disk}}: Boot disk uses ext4 (system + ISO/templates)" \
    "       Pool disks use ZFS tank (VMs only)" \
    ""

  # Options: "None (all in pool)" + all drives
  local options="None (all in pool)"
  for i in "${!DRIVES[@]}"; do
    local disk_name="${DRIVE_NAMES[$i]}"
    local disk_size="${DRIVE_SIZES[$i]}"
    local disk_model="${DRIVE_MODELS[$i]:0:25}"
    options+=$'\n'"${disk_name} - ${disk_size}  ${disk_model}"
  done

  _show_input_footer "filter" "$((DRIVE_COUNT + 2))"

  local selected
  if ! selected=$(printf '%s\n' "$options" | _wiz_choose --header="Boot disk:"); then
    return
  fi

  if [[ -n $selected ]]; then
    if [[ $selected == "None (all in pool)" ]]; then
      declare -g BOOT_DISK=""
    else
      local disk_name="${selected%% -*}"
      declare -g BOOT_DISK="/dev/${disk_name}"
    fi
    _rebuild_pool_disks
  fi
}

# Check if ZFS_POOL_DISKS have mixed sizes (>10% difference). Returns 0=mixed, 1=same
_pool_disks_have_mixed_sizes() {
  [[ ${#ZFS_POOL_DISKS[@]} -lt 2 ]] && return 1

  # Build lookup from pool disks to drive indices
  local -A pool_disk_indices=()
  for pool_disk in "${ZFS_POOL_DISKS[@]}"; do
    for i in "${!DRIVES[@]}"; do
      [[ ${DRIVES[$i]} == "$pool_disk" ]] && pool_disk_indices[$i]=1
    done
  done

  # Parse sizes to bytes for comparison
  local -a size_bytes=()
  for i in "${!pool_disk_indices[@]}"; do
    local size_str="${DRIVE_SIZES[$i]}"
    local num="${size_str%[TGMK]*}"
    local unit="${size_str##*[0-9.]}"
    case "$unit" in
      T) size_bytes+=("$(echo "$num * 1099511627776" | bc | cut -d. -f1)") ;;
      G) size_bytes+=("$(echo "$num * 1073741824" | bc | cut -d. -f1)") ;;
      M) size_bytes+=("$(echo "$num * 1048576" | bc | cut -d. -f1)") ;;
      *) size_bytes+=("$num") ;;
    esac
  done

  # Find min/max
  local min_size="${size_bytes[0]}" max_size="${size_bytes[0]}"
  for size in "${size_bytes[@]}"; do
    ((size < min_size)) && min_size="$size"
    ((size > max_size)) && max_size="$size"
  done

  local size_diff="$((max_size - min_size))"
  local threshold="$((min_size / 10))"
  ((size_diff > threshold))
}

# Edits ZFS pool disk selection via multi-select checkbox.
# Excludes boot disk if set. Requires at least one disk.
# Updates ZFS_POOL_DISKS array and adjusts ZFS_RAID if needed.
_edit_pool_disks() {
  # Pool disk selection with retry loop (like other editors)
  while true; do
    _wiz_start_edit

    _wiz_description \
      "  Select disks for ZFS storage pool:" \
      "" \
      "  These disks will store VMs, containers, and data." \
      "  RAID level is auto-selected based on disk count." \
      ""

    # Build options (exclude boot if set) and preselected items
    local options=""
    local preselected=()

    # Build lookup set from current pool disks for O(1) membership check
    local -A pool_disk_set=()
    for pool_disk in "${ZFS_POOL_DISKS[@]}"; do
      pool_disk_set["$pool_disk"]=1
    done

    for i in "${!DRIVES[@]}"; do
      if [[ -z $BOOT_DISK || ${DRIVES[$i]} != "$BOOT_DISK" ]]; then
        local disk_name="${DRIVE_NAMES[$i]}"
        local disk_size="${DRIVE_SIZES[$i]}"
        local disk_model="${DRIVE_MODELS[$i]:0:25}"
        local disk_label="${disk_name} - ${disk_size}  ${disk_model}"
        [[ -n $options ]] && options+=$'\n'
        options+="${disk_label}"

        # O(1) lookup instead of O(n) inner loop
        [[ -v pool_disk_set["/dev/${disk_name}"] ]] && preselected+=("$disk_label")
      fi
    done

    local available_count
    if [[ -n $BOOT_DISK ]]; then
      available_count="$((DRIVE_COUNT - 1))"
    else
      available_count="$DRIVE_COUNT"
    fi
    _show_input_footer "checkbox" "$((available_count + 1))"

    local gum_args=(--header="ZFS pool disks (min 1):")
    for item in "${preselected[@]}"; do
      gum_args+=(--selected "$item")
    done

    local selected
    local gum_exit_code=0
    selected=$(printf '%s\n' "$options" | _wiz_choose_multi "${gum_args[@]}") || gum_exit_code="$?"

    # ESC/cancel (any non-zero exit) - keep existing selection
    if [[ $gum_exit_code -ne 0 ]]; then
      return 0
    fi

    # User pressed Enter with nothing selected - show error only if no existing selection
    if [[ -z $selected ]]; then
      if [[ ${#ZFS_POOL_DISKS[@]} -gt 0 ]]; then
        # Has existing selection, treat as cancel
        return 0
      fi
      show_validation_error "✗ At least one disk must be selected for ZFS pool"
      continue
    fi

    # Valid selection - update and exit
    declare -g -a ZFS_POOL_DISKS=()
    while IFS= read -r line; do
      local disk_name="${line%% -*}"
      ZFS_POOL_DISKS+=("/dev/${disk_name}")
    done <<<"$selected"
    _update_zfs_mode_options
    break
  done
}

# Removes boot disk from ZFS_POOL_DISKS if present. Does not auto-populate.
_rebuild_pool_disks() {
  # Only remove boot disk from current selection, don't auto-populate
  if [[ -n $BOOT_DISK ]]; then
    local -a new_pool=()
    for disk in "${ZFS_POOL_DISKS[@]}"; do
      [[ $disk != "$BOOT_DISK" ]] && new_pool+=("$disk")
    done
    declare -g -a ZFS_POOL_DISKS=("${new_pool[@]}")
  fi
  _update_zfs_mode_options
}

# Resets ZFS_RAID if current mode is incompatible with pool disk count.
# Update ZFS RAID options after pool disk changes
_update_zfs_mode_options() {
  local pool_count="${#ZFS_POOL_DISKS[@]}"
  # Reset ZFS_RAID if incompatible
  case "$ZFS_RAID" in
    single) [[ $pool_count -ne 1 ]] && declare -g ZFS_RAID="" ;;
    raid1 | raid0) [[ $pool_count -lt 2 ]] && declare -g ZFS_RAID="" ;;
    raidz1) [[ $pool_count -lt 3 ]] && declare -g ZFS_RAID="" ;;
    raid10 | raidz2) [[ $pool_count -lt 4 ]] && declare -g ZFS_RAID="" ;;
    raidz3) [[ $pool_count -lt 5 ]] && declare -g ZFS_RAID="" ;;
  esac
}
# shellcheck shell=bash
# Configuration Wizard - Shell, Power, and Features Editors
# shell, power_profile, features (security, monitoring, tools)

# Edits default shell for root user.
# Options: zsh (with gentoo) or bash.
# Updates SHELL_TYPE global.
_edit_shell() {
  _wiz_start_edit

  _wiz_description \
    "  Default shell for root user:" \
    "" \
    "  {{cyan:ZSH}}:  Modern shell with gentoo prompt" \
    "  {{cyan:Bash}}: Standard shell (minimal changes)" \
    ""

  # 1 header + 2 items for gum choose
  _show_input_footer "filter" 3

  _wiz_choose_mapped "SHELL_TYPE" "Shell:" \
    "${WIZ_MAP_SHELL[@]}"
}

# Edits CPU frequency scaling governor.
# Dynamically detects available governors from sysfs.
# Updates CPU_GOVERNOR global.
_edit_power_profile() {
  _wiz_start_edit

  # Detect available governors from sysfs
  local avail_governors=""
  if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ]]; then
    avail_governors=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)
  fi

  # Cache governor availability (single parse instead of repeated grep calls)
  local has_performance=false has_ondemand=false has_powersave=false
  local has_schedutil=false has_conservative=false
  if [[ -n $avail_governors ]]; then
    for gov in $avail_governors; do
      case "$gov" in
        performance) has_performance=true ;;
        ondemand) has_ondemand=true ;;
        powersave) has_powersave=true ;;
        schedutil) has_schedutil=true ;;
        conservative) has_conservative=true ;;
      esac
    done
  fi

  # Build dynamic options based on available governors
  local options=()
  local descriptions=()

  # Always show Performance if available
  if [[ -z $avail_governors ]] || $has_performance; then
    options+=("Performance")
    descriptions+=("  {{cyan:Performance}}:  Max frequency (highest power)")
  fi

  # Show governor-specific options
  if $has_ondemand; then
    options+=("Balanced")
    descriptions+=("  {{cyan:Balanced}}:     Scale based on load")
  elif $has_powersave; then
    # intel_pstate powersave is actually dynamic scaling
    options+=("Balanced")
    descriptions+=("  {{cyan:Balanced}}:     Dynamic scaling (power efficient)")
  fi

  if $has_schedutil; then
    options+=("Adaptive")
    descriptions+=("  {{cyan:Adaptive}}:     Kernel-managed scaling")
  fi

  if $has_conservative; then
    options+=("Conservative")
    descriptions+=("  {{cyan:Conservative}}: Gradual frequency changes")
  fi

  # Fallback if no governors detected
  if [[ ${#options[@]} -eq 0 ]]; then
    options=("Performance" "Balanced")
    descriptions=(
      "  {{cyan:Performance}}:  Max frequency (highest power)"
      "  {{cyan:Balanced}}:     Dynamic scaling (power efficient)"
    )
  fi

  _wiz_description \
    "  CPU frequency scaling governor:" \
    "" \
    "${descriptions[@]}" \
    ""

  # 1 header + N items for gum choose
  _show_input_footer "filter" $((${#options[@]} + 1))

  local options_str
  options_str=$(printf '%s\n' "${options[@]}")

  local selected
  if ! selected=$(printf '%s\n' "$options_str" | _wiz_choose --header="Power profile:"); then
    return
  fi

  case "$selected" in
    "Performance") declare -g CPU_GOVERNOR="performance" ;;
    "Balanced")
      # Use ondemand if available, otherwise powersave
      if $has_ondemand; then
        declare -g CPU_GOVERNOR="ondemand"
      else
        declare -g CPU_GOVERNOR="powersave"
      fi
      ;;
    "Adaptive") declare -g CPU_GOVERNOR="schedutil" ;;
    "Conservative") declare -g CPU_GOVERNOR="conservative" ;;
  esac
}

# Features - Security

# Edits security feature toggles via multi-select checkbox.
# Options: apparmor, auditd, aide, chkrootkit, lynis, needrestart.
# Updates corresponding INSTALL_* globals.
_edit_features_security() {
  _wiz_start_edit

  _wiz_description \
    "  Security features (use Space to toggle):" \
    "" \
    "  {{cyan:apparmor}}:    Mandatory access control (MAC)" \
    "  {{cyan:auditd}}:      Security audit logging" \
    "  {{cyan:aide}}:        File integrity monitoring (daily)" \
    "  {{cyan:chkrootkit}}:  Rootkit scanning (weekly)" \
    "  {{cyan:lynis}}:       Security auditing (weekly)" \
    "  {{cyan:needrestart}}: Auto-restart services after updates" \
    ""

  _wiz_feature_checkbox "Security:" 7 "WIZ_FEATURES_SECURITY" \
    "apparmor:INSTALL_APPARMOR" \
    "auditd:INSTALL_AUDITD" \
    "aide:INSTALL_AIDE" \
    "chkrootkit:INSTALL_CHKROOTKIT" \
    "lynis:INSTALL_LYNIS" \
    "needrestart:INSTALL_NEEDRESTART"
}

# Features - Monitoring

# Edits monitoring feature toggles via multi-select checkbox.
# Options: vnstat, netdata, promtail.
# Updates corresponding INSTALL_* globals.
_edit_features_monitoring() {
  _wiz_start_edit

  _wiz_description \
    "  Monitoring features (use Space to toggle):" \
    "" \
    "  {{cyan:vnstat}}:   Network traffic monitoring" \
    "  {{cyan:netdata}}:  Real-time monitoring (port 19999)" \
    "  {{cyan:promtail}}: Log collector for Loki" \
    ""

  _wiz_feature_checkbox "Monitoring:" 4 "WIZ_FEATURES_MONITORING" \
    "vnstat:INSTALL_VNSTAT" \
    "netdata:INSTALL_NETDATA" \
    "promtail:INSTALL_PROMTAIL"
}

# Features - Tools

# Edits tools feature toggles via multi-select checkbox.
# Options: yazi (file manager), nvim (editor), ringbuffer (network tuning).
# Updates corresponding INSTALL_* globals.
_edit_features_tools() {
  _wiz_start_edit

  _wiz_description \
    "  Tools (use Space to toggle):" \
    "" \
    "  {{cyan:yazi}}:       Terminal file manager (Tokyo Night theme)" \
    "  {{cyan:nvim}}:       Neovim as default editor" \
    "  {{cyan:ringbuffer}}: Network ring buffer tuning" \
    ""

  _wiz_feature_checkbox "Tools:" 4 "WIZ_FEATURES_TOOLS" \
    "yazi:INSTALL_YAZI" \
    "nvim:INSTALL_NVIM" \
    "ringbuffer:INSTALL_RINGBUFFER"
}
# shellcheck shell=bash
# Configuration Wizard - Postfix Mail Settings Editor

# Prompts for SMTP relay configuration. Sets SMTP_RELAY_* variables.
_postfix_configure_relay() {
  _wiz_start_edit

  _wiz_description \
    "  SMTP Relay Configuration:" \
    "" \
    "  Configure external SMTP server for sending mail." \
    "  Common providers: Gmail, Mailgun, SendGrid, AWS SES" \
    ""

  # SMTP Host
  _wiz_input_validated "SMTP_RELAY_HOST" "validate_smtp_host" \
    "Invalid host. Enter hostname, FQDN, or IP address." \
    --placeholder "smtp.example.com" \
    --value "${SMTP_RELAY_HOST:-smtp.gmail.com}" \
    --prompt "SMTP Host: " || return 1

  # SMTP Port
  _wiz_input_validated "SMTP_RELAY_PORT" "validate_smtp_port" \
    "Invalid port. Enter a number between 1 and 65535." \
    --placeholder "587" \
    --value "${SMTP_RELAY_PORT:-587}" \
    --prompt "SMTP Port: " || return 1

  # Username (email format)
  _wiz_input_validated "SMTP_RELAY_USER" "validate_email" \
    "Invalid email format." \
    --placeholder "user@example.com" \
    --value "${SMTP_RELAY_USER}" \
    --prompt "Username: " || return 1

  # Password (non-empty)
  _wiz_input_validated "SMTP_RELAY_PASSWORD" "validate_not_empty" \
    "Password cannot be empty." \
    --password \
    --placeholder "App password or API key" \
    --value "${SMTP_RELAY_PASSWORD}" \
    --prompt "Password: " || return 1

  return 0
}

# Enable Postfix with relay configuration
_postfix_enable() {
  declare -g INSTALL_POSTFIX="yes"
  _postfix_configure_relay || {
    declare -g INSTALL_POSTFIX="no"
    declare -g SMTP_RELAY_HOST=""
    declare -g SMTP_RELAY_PORT=""
    declare -g SMTP_RELAY_USER=""
    declare -g SMTP_RELAY_PASSWORD=""
  }
}

# Disable Postfix and clear settings
_postfix_disable() {
  declare -g INSTALL_POSTFIX="no"
  declare -g SMTP_RELAY_HOST=""
  declare -g SMTP_RELAY_PORT=""
  declare -g SMTP_RELAY_USER=""
  declare -g SMTP_RELAY_PASSWORD=""
}

# Edit Postfix mail configuration
_edit_postfix() {
  _wiz_start_edit

  _wiz_description \
    "  Postfix Mail Relay:" \
    "" \
    "  {{cyan:Enabled}}:  Send mail via external SMTP relay (port 587)" \
    "  {{cyan:Disabled}}: Disable Postfix service completely" \
    "" \
    "  Note: Most hosting providers block port 25." \
    "  Use relay with port 587 for outgoing mail." \
    ""

  _show_input_footer "filter" 3

  local result
  _wiz_toggle "INSTALL_POSTFIX" "Postfix:"
  result="$?"

  if [[ $result -eq 1 ]]; then
    return
  elif [[ $result -eq 2 ]]; then
    # Enabled - configure relay
    _postfix_enable
  else
    _postfix_disable
  fi
}
# shellcheck shell=bash
# Package preparation for Proxmox installation

# Prepare system packages (Proxmox repo, GPG key, packages)
prepare_packages() {
  log_info "Starting package preparation"

  log_info "Adding Proxmox repository"
  printf '%s\n' "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" >/etc/apt/sources.list.d/pve.list

  # Download Proxmox GPG key
  log_info "Downloading Proxmox GPG key"
  curl -fsSL -o /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg >>"$LOG_FILE" 2>&1 &
  local bg_pid="$!"
  if [[ -z $bg_pid || ! $bg_pid =~ ^[0-9]+$ ]]; then
    log_error "Failed to start background job for GPG key download"
    print_error "Failed to start download process"
    exit 1
  fi
  show_progress "$bg_pid" "Adding Proxmox repository" "Proxmox repository added"
  wait "$bg_pid"
  local exit_code="$?"
  if [[ $exit_code -ne 0 ]]; then
    log_error "Failed to download Proxmox GPG key"
    print_error "Cannot reach Proxmox repository"
    exit 1
  fi
  log_info "Proxmox GPG key downloaded successfully"

  # Add live log subtask after completion
  if type live_log_subtask &>/dev/null 2>&1; then
    live_log_subtask "Configuring APT sources"
  fi

  # Update package lists
  log_info "Updating package lists"
  apt-get clean >>"$LOG_FILE" 2>&1
  apt-get update >>"$LOG_FILE" 2>&1 &
  bg_pid="$!"
  if [[ -z $bg_pid || ! $bg_pid =~ ^[0-9]+$ ]]; then
    log_error "Failed to start background job for package list update"
    exit 1
  fi
  show_progress "$bg_pid" "Updating package lists" "Package lists updated"
  wait "$bg_pid"
  exit_code="$?"
  if [[ $exit_code -ne 0 ]]; then
    log_error "Failed to update package lists"
    exit 1
  fi
  log_info "Package lists updated successfully"

  # Add live log subtask after completion
  if type live_log_subtask &>/dev/null 2>&1; then
    live_log_subtask "Downloading package lists"
  fi

  # Install packages
  log_info "Installing required packages: proxmox-auto-install-assistant xorriso ovmf wget sshpass"
  apt-get install -yq proxmox-auto-install-assistant xorriso ovmf wget sshpass >>"$LOG_FILE" 2>&1 &
  bg_pid="$!"
  if [[ -z $bg_pid || ! $bg_pid =~ ^[0-9]+$ ]]; then
    log_error "Failed to start background job for package installation"
    exit 1
  fi
  show_progress "$bg_pid" "Installing required packages" "Required packages installed"
  wait "$bg_pid"
  exit_code="$?"
  if [[ $exit_code -ne 0 ]]; then
    log_error "Failed to install required packages"
    exit 1
  fi
  log_info "Required packages installed successfully"

  # Add live log subtasks after completion
  if type live_log_subtask &>/dev/null 2>&1; then
    live_log_subtask "Installing proxmox-auto-install-assistant"
    live_log_subtask "Installing xorriso and ovmf"
  fi
}
# shellcheck shell=bash
# QEMU configuration

# Check if UEFI mode. Returns 0=UEFI, 1=BIOS
is_uefi_mode() {
  [[ -d /sys/firmware/efi ]]
}

# Configure QEMU settings. Sets UEFI_OPTS, KVM_OPTS, QEMU_CORES/RAM, DRIVE_ARGS.
setup_qemu_config() {
  log_info "Setting up QEMU configuration"

  # UEFI configuration
  if is_uefi_mode; then
    declare -g UEFI_OPTS="-bios /usr/share/ovmf/OVMF.fd"
    log_info "UEFI mode detected"
  else
    declare -g UEFI_OPTS=""
    log_info "Legacy BIOS mode"
  fi

  # KVM acceleration
  declare -g KVM_OPTS="-enable-kvm"
  declare -g CPU_OPTS="-cpu host"
  log_info "Using KVM acceleration"

  # CPU and RAM configuration
  local available_cores available_ram_mb
  available_cores=$(nproc)
  available_ram_mb=$(free -m | awk '/^Mem:/{print $2}')
  log_info "Available cores: $available_cores, Available RAM: ${available_ram_mb}MB"

  # Use override values if provided, otherwise auto-detect
  if [[ -n $QEMU_CORES_OVERRIDE ]]; then
    declare -g QEMU_CORES="$QEMU_CORES_OVERRIDE"
    log_info "Using user-specified cores: $QEMU_CORES"
  else
    # Use all available cores for QEMU
    declare -g QEMU_CORES="$available_cores"
    [[ $QEMU_CORES -lt $MIN_CPU_CORES ]] && declare -g QEMU_CORES="$MIN_CPU_CORES"
  fi

  if [[ -n $QEMU_RAM_OVERRIDE ]]; then
    declare -g QEMU_RAM="$QEMU_RAM_OVERRIDE"
    log_info "Using user-specified RAM: ${QEMU_RAM}MB"
    # Warn if requested RAM exceeds available
    if [[ $QEMU_RAM -gt $((available_ram_mb - QEMU_MIN_RAM_RESERVE)) ]]; then
      print_warning "Requested QEMU RAM (${QEMU_RAM}MB) may exceed safe limits (available: ${available_ram_mb}MB)"
    fi
  else
    # Use all available RAM minus reserve for host
    declare -g QEMU_RAM="$((available_ram_mb - QEMU_MIN_RAM_RESERVE))"
    [[ $QEMU_RAM -lt $MIN_QEMU_RAM ]] && declare -g QEMU_RAM="$MIN_QEMU_RAM"
  fi

  log_info "QEMU config: $QEMU_CORES vCPUs, ${QEMU_RAM}MB RAM"

  # Load virtio mapping (created by make_answer_toml)
  if ! load_virtio_mapping; then
    log_error "Failed to load virtio mapping"
    return 1
  fi

  # Validate VIRTIO_MAP is not empty before proceeding
  if [[ ${#VIRTIO_MAP[@]} -eq 0 ]]; then
    log_error "VIRTIO_MAP is empty - no disks mapped for QEMU"
    print_error "No disk-to-virtio mappings found. Ensure ZFS pool disks were selected in wizard storage configuration."
    return 1
  fi

  # Build DRIVE_ARGS from virtio mapping in correct order (vda, vdb, vdc, ...)
  # CRITICAL: QEMU assigns virtio devices in order of -drive arguments!
  # We must iterate by virtio name (sorted) to match the mapping.
  declare -g DRIVE_ARGS=""

  # Build reverse map: virtio_device -> physical_disk
  declare -A REVERSE_MAP
  local disk vdev
  for disk in "${!VIRTIO_MAP[@]}"; do
    vdev="${VIRTIO_MAP[$disk]}"
    REVERSE_MAP["$vdev"]="$disk"
  done

  # Iterate virtio devices in sorted order (vda, vdb, vdc, ...)
  local sorted_vdevs
  sorted_vdevs=$(printf '%s\n' "${!REVERSE_MAP[@]}" | sort)

  for vdev in $sorted_vdevs; do
    disk="${REVERSE_MAP[$vdev]}"
    # Validate disk exists before adding to QEMU args
    if [[ ! -b $disk ]]; then
      log_error "Disk $disk does not exist or is not a block device"
      return 1
    fi
    log_info "QEMU drive order: $vdev -> $disk"
    declare -g DRIVE_ARGS="$DRIVE_ARGS -drive file=$disk,format=raw,media=disk,if=virtio"
  done

  if [[ -z $DRIVE_ARGS ]]; then
    log_error "No drive arguments built - QEMU would start without disks"
    return 1
  fi

  log_info "Drive args: $DRIVE_ARGS"
}
# shellcheck shell=bash
# Drive release functions for QEMU

# Send signal to process if running. $1=pid, $2=signal, $3=log_msg
_signal_process() {
  local pid="$1"
  local signal="$2"
  local message="$3"

  if kill -0 "$pid" 2>/dev/null; then
    log_info "$message"
    kill "-$signal" "$pid" 2>/dev/null || true
  fi
}

# Kill processes by pattern. $1=pattern
_kill_processes_by_pattern() {
  local pattern="$1"
  local pids

  pids=$(pgrep -f "$pattern" 2>/dev/null || true)
  if [[ -n $pids ]]; then
    log_info "Found processes matching '$pattern': $pids"

    # Graceful shutdown first (SIGTERM)
    for pid in $pids; do
      _signal_process "$pid" "TERM" "Sending TERM to process $pid"
    done
    sleep "${WIZARD_MESSAGE_DELAY:-3}"

    # Force kill if still running (SIGKILL)
    for pid in $pids; do
      _signal_process "$pid" "9" "Force killing process $pid"
    done
    sleep "${PROCESS_KILL_WAIT:-1}"
  fi

  # Also try pkill as fallback (use -f to match full command line)
  pkill -f -TERM "$pattern" 2>/dev/null || true
  sleep "${PROCESS_KILL_WAIT:-1}"
  pkill -f -9 "$pattern" 2>/dev/null || true
}

# Stops all mdadm RAID arrays to release drive locks.
# Iterates over /dev/md* devices if mdadm is available.
_stop_mdadm_arrays() {
  if ! cmd_exists mdadm; then
    return 0
  fi

  log_info "Stopping mdadm arrays..."
  mdadm --stop --scan 2>/dev/null || true

  # Stop specific arrays if found
  for md in /dev/md*; do
    if [[ -b $md ]]; then
      mdadm --stop "$md" 2>/dev/null || true
    fi
  done
}

# Deactivates all LVM volume groups to release drive locks.
# Uses vgchange -an to deactivate all VGs.
_deactivate_lvm() {
  if ! cmd_exists pvs; then
    return 0
  fi

  log_info "Deactivating LVM volume groups..."
  vgchange -an &>/dev/null || true

  # Deactivate specific VGs by name if vgs is available
  if cmd_exists vgs; then
    while IFS= read -r vg; do
      if [[ -n $vg ]]; then vgchange -an "$vg" &>/dev/null || true; fi
    done < <(vgs --noheadings -o vg_name 2>/dev/null)
  fi
}

# Unmounts all filesystems on target drives (DRIVES global).
# Uses findmnt for efficient mount point detection.
_unmount_drive_filesystems() {
  [[ -z ${DRIVES[*]} ]] && return 0

  log_info "Unmounting filesystems on target drives..."
  for drive in "${DRIVES[@]}"; do
    # Use findmnt for efficient mount point detection (faster and more reliable)
    if cmd_exists findmnt; then
      while IFS= read -r mountpoint; do
        [[ -z $mountpoint ]] && continue
        log_info "Unmounting $mountpoint"
        umount -f "$mountpoint" 2>/dev/null || true
      done < <(findmnt -rn -o TARGET "$drive"* 2>/dev/null)
    else
      # Fallback to mount | grep
      local drive_name
      drive_name=$(basename "$drive")
      while IFS= read -r mountpoint; do
        [[ -z $mountpoint ]] && continue
        log_info "Unmounting $mountpoint"
        umount -f "$mountpoint" 2>/dev/null || true
      done < <(mount | grep -E "(^|/)$drive_name" | awk '{print $3}')
    fi
  done
}

# Kills processes holding drives open using lsof/fuser.
# Iterates over DRIVES global array.
_kill_drive_holders() {
  [[ -z ${DRIVES[*]} ]] && return 0

  log_info "Checking for processes using drives..."
  for drive in "${DRIVES[@]}"; do
    # Use lsof if available
    if cmd_exists lsof; then
      while IFS= read -r pid; do
        [[ -z $pid ]] && continue
        _signal_process "$pid" "9" "Killing process $pid using $drive"
      done < <(lsof "$drive" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u)
    fi

    # Use fuser as alternative
    if cmd_exists fuser; then
      fuser -k "$drive" 2>/dev/null || true
    fi
  done
}

# Main drive release function

# Release drives from locks (RAID, LVM, mounts, holders) before QEMU
release_drives() {
  log_info "Releasing drives from locks..."

  # Kill QEMU processes (use full binary name to avoid matching unintended processes)
  _kill_processes_by_pattern "qemu-system-x86_64"

  # Stop RAID arrays
  _stop_mdadm_arrays

  # Deactivate LVM
  _deactivate_lvm

  # Unmount filesystems
  _unmount_drive_filesystems

  # Additional pause for locks to release
  sleep "${RETRY_DELAY_SECONDS:-2}"

  # Kill any remaining processes holding drives
  _kill_drive_holders

  log_info "Drives released"
}
# shellcheck shell=bash
# Template preparation and download

# Applies variable substitution to all template files.
# Handles hosts, resolv.conf, cpupower, locale templates.
# Interfaces is generated via heredoc (039-network-helpers.sh).
_modify_template_files() {
  log_info "Starting template modification"
  apply_common_template_vars "./templates/hosts" || return 1
  # Add IPv6 hosts entry only if IPv6 is configured (prevents invalid empty IP line)
  if [[ ${IPV6_MODE:-} != "disabled" && -n ${MAIN_IPV6:-} ]]; then
    printf '%s %s %s\n' "$MAIN_IPV6" "$FQDN" "$PVE_HOSTNAME" >>"./templates/hosts"
  fi
  generate_interfaces_file "./templates/interfaces" || return 1
  apply_common_template_vars "./templates/resolv.conf" || return 1
  # Add IPv6 DNS entries only if IPv6 is configured (prevents invalid nameserver lines)
  if [[ ${IPV6_MODE:-} != "disabled" ]]; then
    printf 'nameserver %s\n' "${DNS6_PRIMARY:-2606:4700:4700::1111}" >>"./templates/resolv.conf"
    printf 'nameserver %s\n' "${DNS6_SECONDARY:-2606:4700:4700::1001}" >>"./templates/resolv.conf"
  fi
  apply_template_vars "./templates/cpupower.service" "CPU_GOVERNOR=${CPU_GOVERNOR:-performance}" || return 1
  # Locale templates - substitute {{LOCALE}} with actual locale value
  apply_common_template_vars "./templates/locale.sh" || return 1
  apply_common_template_vars "./templates/default-locale" || return 1
  apply_common_template_vars "./templates/environment" || return 1
  log_info "Template modification complete"
}

# Download templates in parallel (aria2c→wget fallback). $@="path:name" pairs
_download_templates_parallel() {
  local -a templates=("$@")
  local input_file=""
  input_file=$(mktemp) || {
    log_error "mktemp failed for aria2c input file"
    return 1
  }
  register_temp_file "$input_file"

  # Build aria2c input file
  for entry in "${templates[@]}"; do
    local local_path="${entry%%:*}"
    local remote_name="${entry#*:}"
    local url="${GITHUB_BASE_URL}/templates/${remote_name}.tmpl"
    printf '%s\n' "$url"
    printf '%s\n' "  out=$local_path"
  done >"$input_file"

  log_info "Downloading ${#templates[@]} templates in parallel"

  # Use aria2c for parallel download if available
  if cmd_exists aria2c; then
    if aria2c -q \
      -j 16 \
      --max-connection-per-server=4 \
      --file-allocation=none \
      --max-tries=3 \
      --retry-wait=2 \
      --timeout=30 \
      --connect-timeout=10 \
      -i "$input_file" \
      >>"$LOG_FILE" 2>&1; then
      rm -f "$input_file"
      # Validate all downloaded templates (aria2c doesn't validate content)
      for entry in "${templates[@]}"; do
        local local_path="${entry%%:*}"
        if [[ ! -s $local_path ]]; then
          log_error "Template $local_path is empty after aria2c download"
          return 1
        fi
      done
      return 0
    fi
    log_warn "aria2c failed, falling back to sequential download"
  fi

  rm -f "$input_file"

  # Fallback: sequential download with wget
  for entry in "${templates[@]}"; do
    local local_path="${entry%%:*}"
    local remote_name="${entry#*:}"
    if ! download_template "$local_path" "$remote_name"; then
      return 1
    fi
  done
  return 0
}

# Download and prepare all template files for Proxmox configuration
make_templates() {
  log_info "Starting template preparation"
  mkdir -p ./templates
  log_info "Using bridge mode: ${BRIDGE_MODE:-internal}"

  # Select Proxmox repository template based on PVE_REPO_TYPE
  local proxmox_sources_template="proxmox.sources"
  case "${PVE_REPO_TYPE:-no-subscription}" in
    enterprise) proxmox_sources_template="proxmox-enterprise.sources" ;;
    test) proxmox_sources_template="proxmox-test.sources" ;;
  esac
  log_info "Using repository template: $proxmox_sources_template"

  # Build list of ALL templates: "local_path:remote_name"
  # All templates are pre-downloaded, used as needed
  local -a template_list=(
    # System base
    "./templates/99-proxmox.conf:99-proxmox.conf"
    "./templates/99-limits.conf:99-limits.conf"
    "./templates/hosts:hosts"
    "./templates/debian.sources:debian.sources"
    "./templates/proxmox.sources:${proxmox_sources_template}"
    "./templates/sshd_config:sshd_config"
    "./templates/resolv.conf:resolv.conf"
    "./templates/journald.conf:journald.conf"
    # Locale
    "./templates/locale.sh:locale.sh"
    "./templates/default-locale:default-locale"
    "./templates/environment:environment"
    # Shell
    "./templates/zshrc:zshrc"
    "./templates/fastfetch.sh:fastfetch.sh"
    "./templates/bat-config:bat-config"
    # System services
    "./templates/chrony:chrony"
    "./templates/50unattended-upgrades:50unattended-upgrades"
    "./templates/20auto-upgrades:20auto-upgrades"
    "./templates/cpupower.service:cpupower.service"
    "./templates/60-io-scheduler.rules:60-io-scheduler.rules"
    "./templates/remove-subscription-nag.sh:remove-subscription-nag.sh"
    # ZFS
    "./templates/zfs-scrub.service:zfs-scrub.service"
    "./templates/zfs-scrub.timer:zfs-scrub.timer"
    "./templates/zfs-import-cache.service.d-override.conf:zfs-import-cache.service.d-override.conf"
    "./templates/zfs-cachefile-initramfs-hook:zfs-cachefile-initramfs-hook"
    # Let's Encrypt
    "./templates/letsencrypt-deploy-hook.sh:letsencrypt-deploy-hook.sh"
    "./templates/letsencrypt-firstboot.sh:letsencrypt-firstboot.sh"
    "./templates/letsencrypt-firstboot.service:letsencrypt-firstboot.service"
    # Tailscale
    "./templates/disable-openssh.service:disable-openssh.service"
    # Security - Fail2Ban
    "./templates/fail2ban-jail.local:fail2ban-jail.local"
    "./templates/fail2ban-proxmox.conf:fail2ban-proxmox.conf"
    # Security - AppArmor
    "./templates/apparmor-grub.cfg:apparmor-grub.cfg"
    # Security - Auditd
    "./templates/auditd-rules:auditd-rules"
    # Security - AIDE
    "./templates/aide-check.service:aide-check.service"
    "./templates/aide-check.timer:aide-check.timer"
    # Security - chkrootkit
    "./templates/chkrootkit-scan.service:chkrootkit-scan.service"
    "./templates/chkrootkit-scan.timer:chkrootkit-scan.timer"
    # Security - Lynis
    "./templates/lynis-audit.service:lynis-audit.service"
    "./templates/lynis-audit.timer:lynis-audit.timer"
    # Security - needrestart
    "./templates/needrestart.conf:needrestart.conf"
    # Monitoring - vnStat
    "./templates/vnstat.conf:vnstat.conf"
    # Monitoring - Netdata
    "./templates/netdata.conf:netdata.conf"
    "./templates/journald-netdata.conf:journald-netdata.conf"
    # Monitoring - Promtail
    "./templates/promtail.yml:promtail.yml"
    "./templates/promtail.service:promtail.service"
    # Mail - Postfix
    "./templates/postfix-main.cf:postfix-main.cf"
    # Tools - Yazi
    "./templates/yazi.toml:yazi.toml"
    "./templates/yazi-theme.toml:yazi-theme.toml"
    "./templates/yazi-init.lua:yazi-init.lua"
    "./templates/yazi-keymap.toml:yazi-keymap.toml"
    # Network tuning
    "./templates/network-ringbuffer.service:network-ringbuffer.service"
    "./templates/network-ringbuffer.sh:network-ringbuffer.sh"
    # Validation
    "./templates/validation.sh:validation.sh"
  )

  # Download all templates in parallel
  if ! run_with_progress "Downloading template files" "Template files downloaded" \
    _download_templates_parallel "${template_list[@]}"; then
    log_error "Failed to download template files"
    exit 1
  fi

  # Derive PRIVATE_IP_CIDR from PRIVATE_SUBNET (e.g., 10.0.0.0/24 → 10.0.0.1/24)
  if [[ -n ${PRIVATE_SUBNET:-} && $BRIDGE_MODE != "external" ]]; then
    if validate_subnet "$PRIVATE_SUBNET"; then
      declare -g PRIVATE_IP_CIDR="${PRIVATE_SUBNET%.*}.1/${PRIVATE_SUBNET#*/}"
      export PRIVATE_IP_CIDR
      log_info "Derived PRIVATE_IP_CIDR=$PRIVATE_IP_CIDR from PRIVATE_SUBNET=$PRIVATE_SUBNET"
    else
      log_error "Invalid PRIVATE_SUBNET format: $PRIVATE_SUBNET (expected CIDR like 10.0.0.0/24)"
      return 1
    fi
  fi

  # Modify template files in background with progress
  if ! run_with_progress "Modifying template files" "Template files modified" _modify_template_files; then
    log_error "Template modification failed"
    return 1
  fi
}
# shellcheck shell=bash
# Proxmox ISO download methods
# Fallback chain: aria2c → curl → wget

# Download ISO via curl. $1=url, $2=output
_download_iso_curl() {
  local url="$1"
  local output="$2"
  local max_retries="${DOWNLOAD_RETRY_COUNT:-3}"
  local retry_delay="${DOWNLOAD_RETRY_DELAY:-5}"

  log_info "Downloading with curl (single connection, resume-enabled)"
  curl -fSL \
    --retry "$max_retries" \
    --retry-delay "$retry_delay" \
    --retry-connrefused \
    -C - \
    -o "$output" \
    "$url" >>"$LOG_FILE" 2>&1
}

# Download ISO via wget. $1=url, $2=output
_download_iso_wget() {
  local url="$1"
  local output="$2"
  local max_retries="${DOWNLOAD_RETRY_COUNT:-3}"

  log_info "Downloading with wget (single connection, resume-enabled)"
  wget -q \
    --tries="$max_retries" \
    --continue \
    --timeout=60 \
    --waitretry=5 \
    -O "$output" \
    "$url" >>"$LOG_FILE" 2>&1
}

# Download ISO via aria2c. $1=url, $2=output, $3=checksum (optional)
_download_iso_aria2c() {
  local url="$1"
  local output="$2"
  local checksum="$3"
  local max_retries="${DOWNLOAD_RETRY_COUNT:-3}"

  log_info "Downloading with aria2c (4 connections, with retries)"
  local aria2_args=(
    -x 4  # 4 connections (optimal for Proxmox server)
    -s 4  # 4 splits
    -k 4M # 4MB minimum split size
    --max-tries="$max_retries"
    --retry-wait=5
    --timeout=60
    --connect-timeout=30
    --max-connection-per-server=4
    --allow-overwrite=true
    --auto-file-renaming=false
    -o "$output"
    --console-log-level=error
    --summary-interval=0
  )

  # Add checksum verification if available
  if [[ -n $checksum ]]; then
    aria2_args+=(--checksum=sha-256="$checksum")
    log_info "aria2c will verify checksum automatically"
  fi

  aria2c "${aria2_args[@]}" "$url" >>"$LOG_FILE" 2>&1
}

# Download ISO with fallback (aria2c→curl→wget). $1=url, $2=output, $3=checksum, $4=method_file
_download_iso_with_fallback() {
  local url="$1"
  local output="$2"
  local checksum="$3"
  local method_file="${4:-}"

  # Try aria2c first (fastest - uses parallel connections)
  if cmd_exists aria2c; then
    log_info "Trying aria2c (parallel download)..."
    if _download_iso_aria2c "$url" "$output" "$checksum" && [[ -s "$output" ]]; then
      [[ -n $method_file ]] && printf '%s\n' "aria2c" >"$method_file"
      return 0
    fi
    log_info "aria2c failed, trying fallback..."
    rm -f "$output" 2>/dev/null
  fi

  # Fallback to curl
  log_info "Trying curl..."
  if _download_iso_curl "$url" "$output" && [[ -s "$output" ]]; then
    [[ -n $method_file ]] && printf '%s\n' "curl" >"$method_file"
    return 0
  fi
  log_info "curl failed, trying fallback..."
  rm -f "$output" 2>/dev/null

  # Fallback to wget
  if cmd_exists wget; then
    log_info "Trying wget..."
    if _download_iso_wget "$url" "$output" && [[ -s "$output" ]]; then
      [[ -n $method_file ]] && printf '%s\n' "wget" >"$method_file"
      return 0
    fi
    rm -f "$output" 2>/dev/null
  fi

  log_info "All download methods failed"
  return 1
}
# shellcheck shell=bash
# Proxmox ISO download and version management

# Cache for ISO list (populated by prefetch_proxmox_iso_info)
_ISO_LIST_CACHE=""

# Cache for SHA256SUMS content
_CHECKSUM_CACHE=""

# Prefetch ISO list and checksums to cache
prefetch_proxmox_iso_info() {
  declare -g _ISO_LIST_CACHE
  declare -g _CHECKSUM_CACHE
  _ISO_LIST_CACHE="$(curl -s "$PROXMOX_ISO_BASE_URL" 2>/dev/null | grep -oE 'proxmox-ve_[0-9]+\.[0-9]+-[0-9]+\.iso' | sort -uV)" || true
  _CHECKSUM_CACHE="$(curl -s "$PROXMOX_CHECKSUM_URL" 2>/dev/null)" || true
}

# Get available Proxmox ISOs (v9+). $1=count (default 5) → stdout
get_available_proxmox_isos() {
  local count="${1:-5}"
  # Filter to versions 9+ (matches 9, 10, 11, etc.)
  printf '%s\n' "$_ISO_LIST_CACHE" | grep -E '^proxmox-ve_(9|[1-9][0-9]+)\.' | tail -n "$count" | tac
}

# Get full ISO URL. $1=filename → stdout
get_proxmox_iso_url() {
  local iso_filename="$1"
  printf '%s\n' "${PROXMOX_ISO_BASE_URL}${iso_filename}"
}

# Extract version from ISO filename. $1=filename → stdout
get_iso_version() {
  local iso_filename="$1"
  printf '%s\n' "$iso_filename" | sed -E 's/proxmox-ve_([0-9]+\.[0-9]+-[0-9]+)\.iso/\1/'
}

# Internal: Download and verify ISO (silent, for parallel execution)
_download_iso() {
  log_info "Starting Proxmox ISO download"

  if [[ -f "pve.iso" ]]; then
    log_info "Proxmox ISO already exists, skipping download"
    return 0
  fi

  if [[ -z $PROXMOX_ISO_VERSION ]]; then
    log_error "PROXMOX_ISO_VERSION not set"
    return 1
  fi

  log_info "Using selected ISO: $PROXMOX_ISO_VERSION"
  declare -g PROXMOX_ISO_URL
  PROXMOX_ISO_URL="$(get_proxmox_iso_url "$PROXMOX_ISO_VERSION")"
  log_info "Found ISO URL: $PROXMOX_ISO_URL"

  declare -g ISO_FILENAME
  ISO_FILENAME="$(basename "$PROXMOX_ISO_URL")"

  # Get checksum from cache (populated by prefetch_proxmox_iso_info)
  local expected_checksum=""
  if [[ -n $_CHECKSUM_CACHE ]]; then
    expected_checksum="$(printf '%s\n' "$_CHECKSUM_CACHE" | grep "$ISO_FILENAME" | awk '{print $1}')"
  fi
  log_info "Expected checksum: ${expected_checksum:-not available}"

  # Download with fallback chain: aria2c → curl → wget
  log_info "Downloading ISO: $ISO_FILENAME"
  local method_file=""
  method_file=$(mktemp) || {
    log_error "mktemp failed for method_file"
    return 1
  }
  register_temp_file "$method_file"

  _download_iso_with_fallback "$PROXMOX_ISO_URL" "pve.iso" "$expected_checksum" "$method_file"
  local exit_code="$?"
  declare -g DOWNLOAD_METHOD
  DOWNLOAD_METHOD="$(cat "$method_file" 2>/dev/null)"
  rm -f "$method_file"

  if [[ $exit_code -ne 0 ]] || [[ ! -s "pve.iso" ]]; then
    log_error "All download methods failed for Proxmox ISO"
    rm -f pve.iso
    return 1
  fi

  log_info "Download successful via $DOWNLOAD_METHOD"

  local iso_size
  iso_size="$(stat -c%s pve.iso 2>/dev/null)" || iso_size=0
  log_info "ISO file size: $(printf '%s\n' "$iso_size" | awk '{printf "%.1fG", $1/1024/1024/1024}')"

  # Verify checksum (if not already verified by aria2c)
  if [[ -n $expected_checksum ]]; then
    if [[ $DOWNLOAD_METHOD == "aria2c" ]]; then
      log_info "Checksum already verified by aria2c"
    else
      log_info "Verifying ISO checksum"
      local actual_checksum
      actual_checksum=$(sha256sum pve.iso | awk '{print $1}')
      if [[ $actual_checksum != "$expected_checksum" ]]; then
        log_error "Checksum mismatch! Expected: $expected_checksum, Got: $actual_checksum"
        rm -f pve.iso
        return 1
      fi
      log_info "Checksum verification passed"
    fi
  else
    log_warn "Could not find checksum for $ISO_FILENAME"
  fi

  # Clean up /tmp to free memory (rescue system uses tmpfs)
  # IMPORTANT: Do NOT delete /tmp/tmp.* - mktemp directories may be in use by parallel_group
  log_info "Cleaning up temporary files in /tmp"
  rm -rf /tmp/pve-* /tmp/aria2-* 2>/dev/null || true
  log_info "Temporary files cleaned"
}

# Parallel wrapper for run_parallel_group
_parallel_download_iso() {
  _download_iso || return 1
  parallel_mark_configured "ISO downloaded"
}
# shellcheck shell=bash
# Autoinstall ISO creation for Proxmox

# Validate answer.toml format. $1=file_path
validate_answer_toml() {
  local file="$1"

  # Basic field validation
  # Note: Use kebab-case keys (root-password, not root_password)
  local required_fields=("fqdn" "mailto" "timezone" "root-password")
  for field in "${required_fields[@]}"; do
    if ! grep -q "^\s*${field}\s*=" "$file" 2>/dev/null; then
      log_error "Missing required field in answer.toml: $field"
      return 1
    fi
  done

  if ! grep -q "\[global\]" "$file" 2>/dev/null; then
    log_error "Missing [global] section in answer.toml"
    return 1
  fi

  # Validate using Proxmox auto-install assistant if available
  if cmd_exists proxmox-auto-install-assistant; then
    log_info "Validating answer.toml with proxmox-auto-install-assistant"
    if ! proxmox-auto-install-assistant validate-answer "$file" >>"$LOG_FILE" 2>&1; then
      log_error "answer.toml validation failed"
      # Show validation errors in log
      proxmox-auto-install-assistant validate-answer "$file" >>"$LOG_FILE" 2>&1 || true
      return 1
    fi
    log_info "answer.toml validation passed"
  else
    log_warn "proxmox-auto-install-assistant not found, skipping advanced validation"
  fi

  return 0
}

# Internal: Create answer.toml (silent, for parallel execution)
_make_answer_toml() {
  log_info "Creating answer.toml for autoinstall"
  log_debug "ZFS_RAID=$ZFS_RAID, BOOT_DISK=$BOOT_DISK"
  log_debug "ZFS_POOL_DISKS=(${ZFS_POOL_DISKS[*]})"
  log_debug "USE_EXISTING_POOL=$USE_EXISTING_POOL, EXISTING_POOL_NAME=$EXISTING_POOL_NAME"
  log_debug "EXISTING_POOL_DISKS=(${EXISTING_POOL_DISKS[*]})"

  # Determine which disks to pass to QEMU
  # - For existing pool: pass existing pool disks (needed for zpool import)
  # - For new pool: pass ZFS_POOL_DISKS
  # Note: These disks are passed to QEMU but NOT included in answer.toml disk-list,
  #       so the installer won't format them - only the boot disk gets formatted
  local virtio_pool_disks=()
  if [[ $USE_EXISTING_POOL == "yes" ]]; then
    log_info "Using existing pool mode - existing pool disks will be passed to QEMU for import"
    # Filter to only include disks that actually exist on the host
    # (pool metadata may contain stale virtio device names from previous installations)
    for disk in "${EXISTING_POOL_DISKS[@]}"; do
      if [[ -b $disk ]]; then
        virtio_pool_disks+=("$disk")
      else
        log_warn "Pool disk $disk does not exist on host, skipping"
      fi
    done
  else
    virtio_pool_disks=("${ZFS_POOL_DISKS[@]}")
  fi

  # Create virtio mapping (synchronous for parallel execution)
  log_info "Creating virtio disk mapping"
  create_virtio_mapping "$BOOT_DISK" "${virtio_pool_disks[@]}" || {
    log_error "Failed to create virtio mapping"
    return 1
  }

  # Load mapping into current shell
  load_virtio_mapping || {
    log_error "Failed to load virtio mapping"
    return 1
  }

  # Determine filesystem and disk list based on BOOT_DISK mode:
  # - BOOT_DISK set: ext4 on boot disk only, ZFS pool created post-install
  # - BOOT_DISK empty: ZFS on all disks (existing behavior)
  local FILESYSTEM
  local all_disks=()

  if [[ -n $BOOT_DISK ]]; then
    # Separate boot disk mode: ext4 on boot disk, ZFS pool created/imported later
    FILESYSTEM="ext4"
    all_disks=("$BOOT_DISK")

    if [[ $USE_EXISTING_POOL == "yes" ]]; then
      # Validate existing pool name is set
      if [[ -z $EXISTING_POOL_NAME ]]; then
        log_error "USE_EXISTING_POOL=yes but EXISTING_POOL_NAME is empty"
        return 1
      fi
      log_info "Boot disk mode: ext4 on boot disk, existing pool '$EXISTING_POOL_NAME' will be imported"
    else
      # Pool disks are optional - if empty, local storage uses all boot disk space
      if [[ ${#ZFS_POOL_DISKS[@]} -eq 0 ]]; then
        log_info "Boot disk mode: ext4 on boot disk only, no separate ZFS pool"
      else
        log_info "Boot disk mode: ext4 on boot disk, ZFS 'tank' pool will be created from ${#ZFS_POOL_DISKS[@]} pool disk(s)"
      fi
    fi
  else
    # All-ZFS mode: all disks in ZFS rpool
    FILESYSTEM="zfs"
    all_disks=("${ZFS_POOL_DISKS[@]}")

    log_info "All-ZFS mode: ${#all_disks[@]} disk(s) in ZFS rpool (${ZFS_RAID})"
  fi

  # Build DISK_LIST from all_disks using virtio mapping
  declare -g DISK_LIST
  DISK_LIST=$(map_disks_to_virtio "toml_array" "${all_disks[@]}")
  if [[ -z $DISK_LIST ]]; then
    log_error "Failed to map disks to virtio devices"
    return 1
  fi

  log_debug "FILESYSTEM=$FILESYSTEM, DISK_LIST=$DISK_LIST"

  # Generate answer.toml dynamically based on filesystem type
  # This allows conditional sections (ZFS vs LVM parameters)
  log_info "Generating answer.toml for autoinstall"

  # NOTE: SSH key is NOT added to answer.toml anymore.
  # SSH key is deployed directly to the admin user in 302-configure-admin.sh
  # Root login is disabled for both SSH and Proxmox UI.

  # Escape password for TOML basic string. Reject unsupported control chars first.
  local escaped_password="$NEW_ROOT_PASSWORD" test_pwd="$NEW_ROOT_PASSWORD"
  for c in $'\t' $'\n' $'\r' $'\b' $'\f'; do test_pwd="${test_pwd//$c/}"; done
  # shellcheck disable=SC2076
  [[ "$test_pwd" =~ [[:cntrl:]] ]] && {
    log_error "Password has unsupported control chars"
    return 1
  }

  # CRITICAL: Backslashes must be escaped first to avoid double-escaping other sequences
  escaped_password="${escaped_password//\\/\\\\}"
  escaped_password="${escaped_password//\"/\\\"}"
  escaped_password="${escaped_password//$'\t'/\\t}"
  escaped_password="${escaped_password//$'\n'/\\n}"
  escaped_password="${escaped_password//$'\r'/\\r}"
  escaped_password="${escaped_password//$'\b'/\\b}"
  escaped_password="${escaped_password//$'\f'/\\f}"

  # Generate [global] section
  # IMPORTANT: Use kebab-case for all keys (root-password, reboot-on-error)
  cat >./answer.toml <<EOF
[global]
    keyboard = "$KEYBOARD"
    country = "$COUNTRY"
    fqdn = "$FQDN"
    mailto = "$EMAIL"
    timezone = "$TIMEZONE"
    root-password = "$escaped_password"
    reboot-on-error = false

[network]
    source = "from-dhcp"

[disk-setup]
    filesystem = "$FILESYSTEM"
    disk-list = $DISK_LIST
EOF

  # Add filesystem-specific parameters
  if [[ $FILESYSTEM == "zfs" ]]; then
    # Map ZFS_RAID to answer.toml format
    local zfs_raid_value
    zfs_raid_value=$(map_raid_to_toml "$ZFS_RAID")
    log_info "Using ZFS raid: $zfs_raid_value"

    # Add ZFS parameters
    cat >>./answer.toml <<EOF
    zfs.raid = "$zfs_raid_value"
    zfs.compress = "lz4"
    zfs.checksum = "on"
EOF
  elif [[ $FILESYSTEM == "ext4" ]] || [[ $FILESYSTEM == "xfs" ]]; then
    # Add LVM parameters for ext4/xfs
    # swapsize: 0 = no swap (rely on zswap for memory compression)
    # maxroot: 0 = unlimited root size (use all available space)
    # maxvz: 0 = no separate data LV, no local-lvm storage
    cat >>./answer.toml <<EOF
    lvm.swapsize = 0
    lvm.maxroot = 0
    lvm.maxvz = 0
EOF
  fi

  # Validate the generated file
  if ! validate_answer_toml "./answer.toml"; then
    log_error "answer.toml validation failed"
    return 1
  fi

  log_info "answer.toml created and validated:"
  # Redact password before logging to prevent credential exposure
  sed 's/^\([[:space:]]*root-password[[:space:]]*=[[:space:]]*\).*/\1"[REDACTED]"/' answer.toml >>"$LOG_FILE"
}

# Parallel wrapper for run_parallel_group
_parallel_make_toml() {
  _make_answer_toml || return 1
  parallel_mark_configured "answer.toml created"
}

# Create autoinstall ISO from Proxmox ISO and answer.toml
make_autoinstall_iso() {
  log_info "Creating autoinstall ISO"
  log_info "Input: pve.iso exists: $(test -f pve.iso && echo 'yes' || echo 'no')"
  log_info "Input: answer.toml exists: $(test -f answer.toml && echo 'yes' || echo 'no')"
  log_info "Current directory: $(pwd)"

  # Run ISO creation with full logging
  proxmox-auto-install-assistant prepare-iso pve.iso --fetch-from iso --answer-file answer.toml --output pve-autoinstall.iso >>"$LOG_FILE" 2>&1 &
  show_progress "$!" "Creating autoinstall ISO" "Autoinstall ISO created"
  local exit_code="$?"
  if [[ $exit_code -ne 0 ]]; then
    log_warn "proxmox-auto-install-assistant exited with code $exit_code"
  fi

  # Verify ISO was created
  if [[ ! -f "./pve-autoinstall.iso" ]]; then
    log_error "Autoinstall ISO not found after creation attempt"
    exit 1
  fi

  log_info "Autoinstall ISO created successfully: $(stat -c%s pve-autoinstall.iso 2>/dev/null | awk '{printf "%.1fM", $1/1024/1024}')"

  # Add live log subtasks after completion
  if type live_log_subtask &>/dev/null 2>&1; then
    live_log_subtask "Packed ISO with xorriso"
  fi

  # Remove original ISO to save disk space (only autoinstall ISO is needed)
  log_info "Removing original ISO to save disk space"
  rm -f pve.iso
}
# shellcheck shell=bash
# QEMU installation and boot functions

# Install Proxmox via QEMU with autoinstall ISO
install_proxmox() {
  # Run preparation in background to show progress immediately
  local qemu_config_file
  qemu_config_file=$(mktemp) || {
    log_error "Failed to create temp file for QEMU config"
    exit 1
  }
  register_temp_file "$qemu_config_file"

  (
    # Setup QEMU configuration - exit on failure
    if ! setup_qemu_config; then
      log_error "QEMU configuration failed"
      exit 1
    fi

    # Save config for parent shell (including all QEMU variables)
    cat >"$qemu_config_file" <<EOF
QEMU_CORES=$QEMU_CORES
QEMU_RAM=$QEMU_RAM
UEFI_MODE=$(is_uefi_mode && echo "yes" || echo "no")
KVM_OPTS='$KVM_OPTS'
UEFI_OPTS='$UEFI_OPTS'
CPU_OPTS='$CPU_OPTS'
DRIVE_ARGS='$DRIVE_ARGS'
EOF

    # Verify ISO exists
    if [[ ! -f "./pve-autoinstall.iso" ]]; then
      print_error "Autoinstall ISO not found!"
      exit 1
    fi

    # Release any locks on drives before QEMU starts
    release_drives
  ) &
  local prep_pid="$!"

  # Wait for config file to be ready
  local timeout=10
  while [[ ! -s $qemu_config_file ]] && ((timeout > 0)); do
    sleep 0.1
    ((timeout--))
  done

  # Load QEMU configuration
  if [[ -s $qemu_config_file ]]; then
    # Validate file contains only expected QEMU config variables (defense in depth)
    if grep -qvE '^(QEMU_CORES|QEMU_RAM|UEFI_MODE|KVM_OPTS|UEFI_OPTS|CPU_OPTS|DRIVE_ARGS)=' "$qemu_config_file"; then
      log_error "QEMU config file contains unexpected content"
      rm -f "$qemu_config_file"
      exit 1
    fi
    # shellcheck disable=SC1090
    source "$qemu_config_file"
    rm -f "$qemu_config_file"
  fi

  show_progress "$prep_pid" "Starting QEMU (${QEMU_CORES} vCPUs, ${QEMU_RAM}MB RAM)" "QEMU started (${QEMU_CORES} vCPUs, ${QEMU_RAM}MB RAM)"

  # Add subtasks after preparation completes
  if [[ $UEFI_MODE == "yes" ]]; then
    live_log_subtask "UEFI mode detected"
  else
    live_log_subtask "Legacy BIOS mode"
  fi
  live_log_subtask "KVM acceleration enabled"
  live_log_subtask "Configured ${QEMU_CORES} vCPUs, ${QEMU_RAM}MB RAM"

  # Now start QEMU in parent process (not in subshell) - this is KEY!
  # shellcheck disable=SC2086
  qemu-system-x86_64 $KVM_OPTS $UEFI_OPTS \
    $CPU_OPTS -smp "$QEMU_CORES" -m "$QEMU_RAM" \
    -boot d -cdrom ./pve-autoinstall.iso \
    $DRIVE_ARGS -no-reboot -display none >qemu_install.log 2>&1 &

  local qemu_pid="$!"

  # Give QEMU a moment to start or fail
  sleep "${RETRY_DELAY_SECONDS:-2}"

  # Check if QEMU is still running
  if ! kill -0 "$qemu_pid" 2>/dev/null; then
    log_error "QEMU failed to start"
    log_info "QEMU install log:"
    cat qemu_install.log >>"$LOG_FILE" 2>&1
    exit 1
  fi

  # Wait for QEMU with timeout (kills QEMU if installation hangs)
  local install_timeout="${QEMU_INSTALL_TIMEOUT:-300}"
  local check_interval=5
  (
    elapsed=0
    while kill -0 "$qemu_pid" 2>/dev/null && ((elapsed < install_timeout)); do
      sleep "$check_interval"
      ((elapsed += check_interval))
    done
    # If QEMU still running after timeout, kill it
    if kill -0 "$qemu_pid" 2>/dev/null; then
      log_error "Installation timeout after ${install_timeout}s - killing QEMU"
      kill -TERM "$qemu_pid" 2>/dev/null
      sleep 2
      kill -KILL "$qemu_pid" 2>/dev/null
      exit 1
    fi
    exit 0
  ) &
  local wait_pid="$!"

  show_progress "$wait_pid" "Installing Proxmox VE" "Proxmox VE installed"
  local exit_code="$?"

  # Verify installation completed (QEMU exited cleanly)
  if [[ $exit_code -ne 0 ]]; then
    log_error "QEMU installation failed (timeout or error)"
    log_info "QEMU install log:"
    cat qemu_install.log >>"$LOG_FILE" 2>&1
    exit 1
  fi
}

# Boot Proxmox with SSH port forwarding. Sets QEMU_PID.
boot_proxmox_with_port_forwarding() {
  # Deactivate any LVM auto-activated by udev after install
  _deactivate_lvm

  if ! setup_qemu_config; then
    log_error "QEMU configuration failed in boot_proxmox_with_port_forwarding"
    return 1
  fi

  # Check if port is already in use
  if ! check_port_available "$SSH_PORT"; then
    print_error "Port $SSH_PORT is already in use"
    log_error "Port $SSH_PORT is already in use"
    exit 1
  fi

  # shellcheck disable=SC2086
  nohup qemu-system-x86_64 $KVM_OPTS $UEFI_OPTS \
    $CPU_OPTS -device e1000,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::${SSH_PORT_QEMU}-:22 \
    -smp "$QEMU_CORES" -m "$QEMU_RAM" \
    $DRIVE_ARGS -display none \
    >qemu_output.log 2>&1 &

  declare -g QEMU_PID="$!"

  # Wait for port to be open first (in background for show_progress)
  local timeout="${QEMU_BOOT_TIMEOUT:-300}"
  local check_interval="${QEMU_PORT_CHECK_INTERVAL:-3}"
  (
    elapsed=0
    while ((elapsed < timeout)); do
      # Suppress all connection errors by redirecting to /dev/null
      if exec 3<>/dev/tcp/localhost/"${SSH_PORT_QEMU}" 2>/dev/null; then
        exec 3<&- # Close the file descriptor
        exit 0
      fi
      sleep "$check_interval"
      ((elapsed += check_interval))
    done
    exit 1
  ) 2>/dev/null &
  local wait_pid="$!"

  show_progress "$wait_pid" "Booting installed Proxmox" "Proxmox booted"
  local exit_code="$?"

  if [[ $exit_code -ne 0 ]]; then
    log_error "Timeout waiting for SSH port"
    log_info "QEMU output log:"
    cat qemu_output.log >>"$LOG_FILE" 2>&1
    return 1
  fi

  # Wait for SSH to be fully ready (handles key exchange timing)
  wait_for_ssh_ready "${QEMU_SSH_READY_TIMEOUT:-120}" || {
    log_error "SSH connection failed"
    log_info "QEMU output log:"
    cat qemu_output.log >>"$LOG_FILE" 2>&1
    return 1
  }
}
# shellcheck shell=bash
# Disk wipe functions - clean disks before installation

# Escape string for use in regex patterns. $1=string
_escape_regex() {
  # shellcheck disable=SC2016 # \& is literal sed replacement, not expansion
  printf '%s' "$1" | sed 's/[[\.*^$(){}?+|]/\\&/g'
}

# Get disks to wipe based on installation mode.
# - USE_EXISTING_POOL=yes: only boot disk (preserve pool)
# - BOOT_DISK set + new pool: boot + pool disks
# - BOOT_DISK empty (rpool mode): all disks in pool
_get_disks_to_wipe() {
  local disks=()
  local -A seen=()

  if [[ $USE_EXISTING_POOL == "yes" ]]; then
    # Existing pool mode: wipe only boot disk (pool disks preserved)
    [[ -n $BOOT_DISK ]] && disks+=("$BOOT_DISK")
  else
    # New pool mode: wipe boot + pool disks (deduplicated via associative array)
    if [[ -n $BOOT_DISK ]]; then
      disks+=("$BOOT_DISK")
      seen["$BOOT_DISK"]=1
    fi
    for disk in "${ZFS_POOL_DISKS[@]}"; do
      [[ -z ${seen["$disk"]+x} ]] && disks+=("$disk") && seen["$disk"]=1
    done
  fi

  printf '%s\n' "${disks[@]}"
}

# Destroy ZFS pools on disk. $1=disk
_wipe_zfs_on_disk() {
  local disk="$1"
  local disk_name escaped_disk_name
  disk_name=$(basename "$disk")
  escaped_disk_name=$(_escape_regex "$disk_name")

  cmd_exists zpool || return 0

  # Find pools using this disk (check both imported and importable)
  local pools_to_destroy=()

  # Check imported pools first
  while IFS= read -r pool; do
    [[ -z $pool ]] && continue
    # Check if pool uses this disk
    if zpool status "$pool" 2>/dev/null | grep -qE "(^|[[:space:]])${escaped_disk_name}([p0-9]*)?([[:space:]]|$)"; then
      pools_to_destroy+=("$pool")
    fi
  done < <(zpool list -H -o name 2>/dev/null)

  # Also check importable pools from zpool import output
  local import_output
  import_output=$(zpool import 2>&1) || true
  if [[ -n $import_output && $import_output != *"no pools available"* ]]; then
    local current_pool=""
    local pool_has_disk=false
    while IFS= read -r line; do
      if [[ $line =~ ^[[:space:]]*pool:[[:space:]]*(.+)$ ]]; then
        # Save previous pool if it had our disk
        if [[ $pool_has_disk == true && -n $current_pool ]]; then
          # Check not already in list
          local already=false
          for p in "${pools_to_destroy[@]}"; do
            [[ $p == "$current_pool" ]] && already=true && break
          done
          [[ $already == false ]] && pools_to_destroy+=("$current_pool")
        fi
        current_pool="${BASH_REMATCH[1]}"
        pool_has_disk=false
      elif [[ $line =~ $escaped_disk_name ]]; then
        pool_has_disk=true
      fi
    done <<<"$import_output"
    # Don't forget last pool
    if [[ $pool_has_disk == true && -n $current_pool ]]; then
      local already=false
      for p in "${pools_to_destroy[@]}"; do
        [[ $p == "$current_pool" ]] && already=true && break
      done
      [[ $already == false ]] && pools_to_destroy+=("$current_pool")
    fi
  fi

  # Destroy each pool
  for pool in "${pools_to_destroy[@]}"; do
    log_info "Destroying ZFS pool: $pool (contains $disk)"
    # Try export first (safer), then force destroy
    zpool export -f "$pool" 2>/dev/null || true
    zpool destroy -f "$pool" 2>/dev/null || true
  done

  # Clear ZFS labels from disk and partitions
  for part in "${disk}"*; do
    # shellcheck disable=SC2015 # || true is fallback, not else branch
    [[ -b $part ]] && zpool labelclear -f "$part" 2>/dev/null || true
  done
}

# Remove LVM on disk. $1=disk
_wipe_lvm_on_disk() {
  local disk="$1"

  cmd_exists pvs || return 0

  # Find PVs on this disk (including partitions)
  local pvs_on_disk=()
  while IFS= read -r pv; do
    [[ -z $pv ]] && continue
    [[ $pv == "${disk}"* ]] && pvs_on_disk+=("$pv")
  done < <(pvs --noheadings -o pv_name 2>/dev/null | tr -d ' ')

  for pv in "${pvs_on_disk[@]}"; do
    # Get VG name for this PV
    local vg
    vg=$(pvs --noheadings -o vg_name "$pv" 2>/dev/null | tr -d ' ')

    if [[ -n $vg ]]; then
      log_info "Removing LVM VG: $vg (on $pv)"
      # Deactivate all LVs in VG
      vgchange -an "$vg" 2>/dev/null || true
      # Remove VG (also removes LVs)
      vgremove -f "$vg" 2>/dev/null || true
    fi

    # Remove PV
    log_info "Removing LVM PV: $pv"
    pvremove -f "$pv" 2>/dev/null || true
  done
}

# Stop mdadm arrays on disk. $1=disk
_wipe_mdadm_on_disk() {
  local disk="$1"
  local disk_name escaped_disk_name
  disk_name=$(basename "$disk")
  escaped_disk_name=$(_escape_regex "$disk_name")

  cmd_exists mdadm || return 0

  # Find arrays using this disk
  while IFS= read -r md; do
    [[ -z $md ]] && continue
    if mdadm --detail "$md" 2>/dev/null | grep -q "$escaped_disk_name"; then
      log_info "Stopping mdadm array: $md (contains $disk)"
      mdadm --stop "$md" 2>/dev/null || true
    fi
  done < <(ls /dev/md* 2>/dev/null)

  # Zero superblocks on disk and partitions
  for part in "${disk}"*; do
    # shellcheck disable=SC2015 # || true is fallback, not else branch
    [[ -b $part ]] && mdadm --zero-superblock "$part" 2>/dev/null || true
  done
}

# Wipe partition table and signatures. $1=disk
_wipe_partition_table() {
  local disk="$1"

  log_info "Wiping partition table: $disk"

  # wipefs removes all filesystem/raid/partition signatures
  if cmd_exists wipefs; then
    wipefs -a -f "$disk" 2>/dev/null || true
  fi

  # sgdisk --zap-all destroys GPT and MBR structures
  if cmd_exists sgdisk; then
    sgdisk --zap-all "$disk" 2>/dev/null || true
  fi

  # Zero first and last 1MB (catches MBR, GPT headers, backup GPT)
  dd if=/dev/zero of="$disk" bs=1M count=1 conv=notrunc 2>/dev/null || true
  local disk_size
  disk_size=$(blockdev --getsize64 "$disk" 2>/dev/null || echo 0)
  if [[ $disk_size -gt 1048576 ]]; then
    dd if=/dev/zero of="$disk" bs=1M count=1 seek=$((disk_size / 1048576 - 1)) conv=notrunc 2>/dev/null || true
  fi

  # Inform kernel of partition table changes
  partprobe "$disk" 2>/dev/null || true
  blockdev --rereadpt "$disk" 2>/dev/null || true
}

# Wipe single disk completely. $1=disk
_wipe_disk() {
  local disk="$1"

  [[ ! -b $disk ]] && {
    log_warn "Disk not found: $disk"
    return 0
  }

  log_info "Wiping disk: $disk"

  # Order matters: remove higher-level structures first
  _wipe_zfs_on_disk "$disk"
  _wipe_lvm_on_disk "$disk"
  _wipe_mdadm_on_disk "$disk"
  _wipe_partition_table "$disk"
}

# Main wipe function - wipes disks based on installation mode
wipe_installation_disks() {
  [[ $WIPE_DISKS != "yes" ]] && {
    log_info "Disk wipe disabled, skipping"
    return 0
  }

  local disks
  mapfile -t disks < <(_get_disks_to_wipe)

  if [[ ${#disks[@]} -eq 0 ]]; then
    log_warn "No disks to wipe"
    return 0
  fi

  if [[ $USE_EXISTING_POOL == "yes" ]]; then
    log_info "Wiping boot disk only (preserving existing pool): ${disks[*]}"
  else
    log_info "Wiping ${#disks[@]} disk(s): ${disks[*]}"
  fi

  for disk in "${disks[@]}"; do
    _wipe_disk "$disk"
  done

  # Sync and wait for kernel to process changes
  sync
  sleep 1

  log_info "Disk wipe complete"
}
# shellcheck shell=bash
# Base system configuration via SSH

# Copy config files to remote (hosts, interfaces, sysctl, sources, resolv, journald, pveproxy)
_copy_config_files() {
  # Create journald config directory if it doesn't exist
  remote_exec "mkdir -p /etc/systemd/journald.conf.d" || return 1

  run_batch_copies \
    "templates/hosts:/etc/hosts" \
    "templates/interfaces:/etc/network/interfaces" \
    "templates/99-proxmox.conf:/etc/sysctl.d/99-proxmox.conf" \
    "templates/debian.sources:/etc/apt/sources.list.d/debian.sources" \
    "templates/proxmox.sources:/etc/apt/sources.list.d/proxmox.sources" \
    "templates/resolv.conf:/etc/resolv.conf" \
    "templates/journald.conf:/etc/systemd/journald.conf.d/00-proxmox.conf"
}

# Apply basic system settings (backup sources, set hostname, disable unused services)
_apply_basic_settings() {
  remote_exec "[ -f /etc/apt/sources.list ] && mv /etc/apt/sources.list /etc/apt/sources.list.bak" || return 1
  remote_exec "echo '$PVE_HOSTNAME' > /etc/hostname" || return 1
  # Disable NFS-related services (not needed on typical Proxmox install)
  # rpcbind: NFS RPC portmapper
  # nfs-blkmap: pNFS block layout mapper (causes "open pipe file failed" errors)
  remote_exec "systemctl disable --now rpcbind rpcbind.socket nfs-blkmap.service 2>/dev/null" || {
    log_warn "Failed to disable rpcbind/nfs-blkmap"
  }
  # Mask nfs-blkmap to prevent it from starting on boot
  remote_exec "systemctl mask nfs-blkmap.service 2>/dev/null" || true
}

# Main base system configuration implementation
_config_base_system() {
  # Copy template files to VM (parallel for better performance)
  run_with_progress "Copying configuration files" "Configuration files copied" _copy_config_files

  # Apply sysctl settings to running kernel
  run_with_progress "Applying sysctl settings" "Sysctl settings applied" remote_exec "sysctl --system"

  # Basic system configuration
  run_with_progress "Applying basic system settings" "Basic system settings applied" _apply_basic_settings

  # Configure Proxmox repository
  log_debug "configure_base_system: PVE_REPO_TYPE=${PVE_REPO_TYPE:-no-subscription}"
  if [[ ${PVE_REPO_TYPE:-no-subscription} == "enterprise" ]]; then
    log_info "configure_base_system: configuring enterprise repository"
    # Enterprise: disable default no-subscription repo (template already has enterprise)
    # shellcheck disable=SC2016 # Single quotes intentional - executed on remote system
    remote_run "Configuring enterprise repository" '
            for repo_file in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
                [[ -f "$repo_file" ]] || continue
                if grep -q "pve-no-subscription\|pvetest" "$repo_file" 2>/dev/null; then
                    mv "$repo_file" "${repo_file}.disabled"
                fi
            done
        ' "Enterprise repository configured"

    # Register subscription key if provided
    if [[ -n $PVE_SUBSCRIPTION_KEY ]]; then
      log_info "configure_base_system: registering subscription key"
      remote_run "Registering subscription key" \
        "pvesubscription set '${PVE_SUBSCRIPTION_KEY}' 2>/dev/null || true" \
        "Subscription key registered"
    fi
  else
    # No-subscription or test: disable enterprise repo
    log_info "configure_base_system: configuring ${PVE_REPO_TYPE:-no-subscription} repository"
    # shellcheck disable=SC2016 # Single quotes intentional - executed on remote system
    remote_run "Configuring ${PVE_REPO_TYPE:-no-subscription} repository" '
            for repo_file in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
                [[ -f "$repo_file" ]] || continue
                if grep -q "enterprise.proxmox.com" "$repo_file" 2>/dev/null; then
                    mv "$repo_file" "${repo_file}.disabled"
                fi
            done

            if [[ -f /etc/apt/sources.list ]] && grep -q "enterprise.proxmox.com" /etc/apt/sources.list 2>/dev/null; then
                sed -i "s|^deb.*enterprise.proxmox.com|# &|g" /etc/apt/sources.list
            fi
        ' "Repository configured"
  fi

  # Install all base system packages in one batch (includes dist-upgrade)
  install_base_packages

  # Configure UTF-8 locales using template files
  # Generate the user's selected locale plus common fallbacks
  # Note: locales package already installed via install_base_packages()
  local locale_name="${LOCALE%%.UTF-8}" # Remove .UTF-8 suffix for sed pattern
  # Enable user's selected locale + en_US as fallback (many tools expect it)
  remote_run "Configuring UTF-8 locales" "
        set -e
        sed -i 's/# ${locale_name}.UTF-8/${locale_name}.UTF-8/' /etc/locale.gen
        sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
        locale-gen
        update-locale LANG=${LOCALE} LC_ALL=${LOCALE}
    " "UTF-8 locales configured"

  # Copy locale template files
  run_with_progress "Installing locale configuration files" "Locale files installed" _install_locale_files

  # Configure fastfetch to run on shell login
  run_with_progress "Configuring fastfetch" "Fastfetch configured" _configure_fastfetch

  # Configure bat with Visual Studio Dark+ theme
  # Note: Debian packages bat as 'batcat', create symlink for 'bat' command
  run_with_progress "Configuring bat" "Bat configured" _configure_bat
}

# Configure base system via SSH into QEMU VM
configure_base_system() {
  _config_base_system
}
# shellcheck shell=bash
# Locale and environment configuration

# Copy locale files (locale.sh, default-locale, environment)
_install_locale_files() {
  remote_copy "templates/locale.sh" "/etc/profile.d/locale.sh" || return 1
  remote_exec "chmod +x /etc/profile.d/locale.sh" || return 1
  remote_copy "templates/default-locale" "/etc/default/locale" || return 1
  remote_copy "templates/environment" "/etc/environment" || return 1
  # Also source locale from bash.bashrc for non-login interactive shells
  remote_exec "grep -q 'profile.d/locale.sh' /etc/bash.bashrc || echo '[ -f /etc/profile.d/locale.sh ] && . /etc/profile.d/locale.sh' >> /etc/bash.bashrc" || return 1
}
# shellcheck shell=bash
# Tailscale VPN configuration

# Private implementation - configures Tailscale VPN
# Called by configure_tailscale() public wrapper
_config_tailscale() {

  # Start tailscaled and wait for socket (up to 3s)
  remote_run "Starting Tailscale" '
        set -e
        systemctl daemon-reload
        systemctl enable --now tailscaled
        systemctl start tailscaled
        for i in {1..3}; do tailscale status &>/dev/null && break; sleep 1; done
        true
    ' "Tailscale started"

  # If auth key is provided, authenticate Tailscale
  if [[ -n $TAILSCALE_AUTH_KEY ]]; then
    # Use unique temporary files to avoid race conditions
    local tmp_ip="" tmp_hostname="" tmp_result=""
    tmp_ip=$(mktemp) || {
      log_error "mktemp failed for tmp_ip"
      return 1
    }
    tmp_hostname=$(mktemp) || {
      rm -f "$tmp_ip"
      log_error "mktemp failed for tmp_hostname"
      return 1
    }
    tmp_result=$(mktemp) || {
      rm -f "$tmp_ip" "$tmp_hostname"
      log_error "mktemp failed for tmp_result"
      return 1
    }

    # Ensure cleanup on function exit (handles errors too)
    # shellcheck disable=SC2064
    trap "rm -f '$tmp_ip' '$tmp_hostname' '$tmp_result'" RETURN

    # Build and execute tailscale up command (SSH always enabled)
    (
      # Run tailscale up with auth key
      if remote_exec "tailscale up --authkey='$TAILSCALE_AUTH_KEY' --ssh"; then
        echo "success" >"$tmp_result"
        # Get IP and hostname in one call using tailscale status --json
        remote_exec "tailscale status --json | jq -r '[(.Self.TailscaleIPs[0] // \"pending\"), (.Self.DNSName // \"\" | rtrimstr(\".\"))] | @tsv'" | {
          IFS=$'\t' read -r ip hostname
          echo "$ip" >"$tmp_ip"
          echo "$hostname" >"$tmp_hostname"
        } || true
      else
        echo "failed" >"$tmp_result"
        log_error "tailscale up command failed"
      fi
    ) >/dev/null 2>&1 &
    show_progress "$!" "Authenticating Tailscale"

    # Check if authentication succeeded
    local auth_result
    auth_result=$(cat "$tmp_result" 2>/dev/null || echo "failed")

    if [[ $auth_result == "success" ]]; then
      # Get Tailscale IP and hostname for display
      declare -g TAILSCALE_IP
      TAILSCALE_IP=$(cat "$tmp_ip" 2>/dev/null || echo "pending")
      declare -g TAILSCALE_HOSTNAME
      TAILSCALE_HOSTNAME=$(cat "$tmp_hostname" 2>/dev/null || printf '\n')

      # Update log with IP info
      complete_task "$TASK_INDEX" "${TREE_BRANCH} Tailscale authenticated. IP: ${TAILSCALE_IP}"

      # Configure Tailscale Serve for Proxmox Web UI (only if auth succeeded)
      # pveproxy listens on port 8006 (hardcoded), Tailscale Serve proxies 443→8006
      if [[ $TAILSCALE_WEBUI == "yes" ]]; then
        remote_run "Configuring Tailscale Serve" \
          'tailscale serve --bg --https=443 https://127.0.0.1:8006' \
          "Proxmox Web UI available via Tailscale Serve"
      fi

      # Deploy OpenSSH disable service when firewall is in stealth mode
      # In stealth mode, all public ports are blocked - SSH access is only via Tailscale
      # Only deploy if Tailscale auth succeeded (otherwise we'd lock ourselves out!)
      if [[ ${FIREWALL_MODE:-standard} == "stealth" ]]; then
        log_info "Deploying disable-openssh.service (FIREWALL_MODE=$FIREWALL_MODE)"
        (
          log_info "Using pre-downloaded disable-openssh.service, size: $(wc -c <./templates/disable-openssh.service 2>/dev/null || echo 'failed')"
          remote_copy "templates/disable-openssh.service" "/etc/systemd/system/disable-openssh.service" || exit 1
          remote_exec "chmod 644 /etc/systemd/system/disable-openssh.service" || exit 1
          log_info "Copied disable-openssh.service to VM"
          remote_exec "systemctl daemon-reload && systemctl enable disable-openssh.service" >/dev/null || exit 1
          log_info "Enabled disable-openssh.service"
        ) &
        show_progress "$!" "Configuring OpenSSH disable on boot" "OpenSSH disable configured"
      else
        log_info "Skipping disable-openssh.service (FIREWALL_MODE=${FIREWALL_MODE:-standard})"
      fi
    else
      declare -g TAILSCALE_IP="auth failed"
      declare -g TAILSCALE_HOSTNAME=""
      complete_task "$TASK_INDEX" "${TREE_BRANCH} ${CLR_YELLOW}Tailscale auth failed - check auth key${CLR_RESET}" "warning"
      log_warn "Tailscale authentication failed. Auth key may be invalid or expired."

      # In stealth mode with failed Tailscale auth, warn but DON'T disable SSH
      # This prevents locking out the user
      if [[ ${FIREWALL_MODE:-standard} == "stealth" ]]; then
        add_log "${TREE_VERT}   ${CLR_YELLOW}SSH will remain enabled (Tailscale auth failed)${CLR_RESET}"
        log_warn "Stealth mode requested but Tailscale auth failed - SSH will remain enabled to prevent lockout"
      fi
    fi

    # Note: Firewall is now configured separately via 310-configure-firewall.sh
  else
    declare -g TAILSCALE_IP="not authenticated"
    declare -g TAILSCALE_HOSTNAME=""
    add_log "${TREE_BRANCH} ${CLR_YELLOW}⚠️${CLR_RESET} Tailscale installed but not authenticated"
    add_subtask_log "After reboot: tailscale up --ssh"
  fi
}

# Public wrapper

# Configures Tailscale VPN with SSH and Web UI access.
# Configure Tailscale with optional auth key and stealth mode
configure_tailscale() {
  [[ $INSTALL_TAILSCALE != "yes" ]] && return 0
  _config_tailscale
}
# shellcheck shell=bash
# Configure non-root admin user
# Creates admin user with sudo privileges, deploys SSH key directly from wizard
# Grants Proxmox Administrator role and disables root@pam
# Root access is blocked for both SSH and Proxmox UI
# SSH key is NOT in answer.toml - it's deployed here directly to admin user

# Creates admin user with full privileges on remote system.
# Sets up: home dir, password, SSH key, passwordless sudo, Proxmox role.
# Disables root@pam in Proxmox UI for security.
# Uses globals: ADMIN_USERNAME, ADMIN_PASSWORD, SSH_PUBLIC_KEY
_config_admin_user() {
  require_admin_username "create admin user" || return 1

  # Create user with home directory and bash shell, add to sudo group
  # shellcheck disable=SC2016
  remote_exec 'useradd -m -s /bin/bash -G sudo '"$ADMIN_USERNAME"'' || return 1

  # Set admin password using base64 to safely handle special chars
  # chpasswd expects "user:password" format - colons/quotes in password would break it
  # Use tr -d '\n' to ensure single-line output (GNU base64 wraps at 76 chars)
  local encoded_creds
  encoded_creds=$(printf '%s:%s' "$ADMIN_USERNAME" "$ADMIN_PASSWORD" | base64 | tr -d '\n')
  remote_exec "echo '${encoded_creds}' | base64 -d | chpasswd" || return 1

  # Set up SSH directory for admin
  remote_exec "mkdir -p /home/${ADMIN_USERNAME}/.ssh && chmod 700 /home/${ADMIN_USERNAME}/.ssh" || return 1

  # Deploy SSH key directly to admin user (not copied from root - root has no SSH access)
  # Escape single quotes in the key for shell safety
  local escaped_key="${SSH_PUBLIC_KEY//\'/\'\\\'\'}"
  remote_exec "echo '${escaped_key}' > /home/${ADMIN_USERNAME}/.ssh/authorized_keys" || return 1

  # Set correct permissions and ownership
  remote_exec "chmod 600 /home/${ADMIN_USERNAME}/.ssh/authorized_keys" || return 1
  remote_exec "chown -R ${ADMIN_USERNAME}:${ADMIN_USERNAME} /home/${ADMIN_USERNAME}/.ssh" || return 1

  # Configure passwordless sudo for admin
  remote_exec "echo '${ADMIN_USERNAME} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${ADMIN_USERNAME}" || return 1
  remote_exec "chmod 440 /etc/sudoers.d/${ADMIN_USERNAME}" || return 1

  # Grant Proxmox UI access to admin user
  # Create PAM user in Proxmox (will auth against Linux PAM)
  # Using grep to check if user exists, avoiding || true which hides real errors
  remote_exec "pveum user list 2>/dev/null | grep -q '${ADMIN_USERNAME}@pam' || pveum user add '${ADMIN_USERNAME}@pam'"

  # Grant Administrator role to admin user
  remote_exec "pveum acl modify / -user '${ADMIN_USERNAME}@pam' -role Administrator" || {
    log_warn "Failed to grant Proxmox Administrator role"
  }

  # Disable root login in Proxmox UI (admin user is now the only way in)
  remote_exec "pveum user modify root@pam -enable 0" || {
    log_warn "Failed to disable root user in Proxmox UI"
  }
}

# Create admin user with sudo and deploy SSH key (before SSH hardening)
configure_admin_user() {
  log_info "Creating admin user: $ADMIN_USERNAME"
  if ! run_with_progress "Creating admin user" "Admin user created" _config_admin_user; then
    log_error "Failed to create admin user"
    return 1
  fi
  log_info "Admin user ${ADMIN_USERNAME} created successfully"
  return 0
}
# shellcheck shell=bash
# System services configuration via SSH

# Helper functions

# Configure chrony NTP with custom config
_configure_chrony() {
  remote_exec "systemctl stop chrony" || true
  remote_copy "templates/chrony" "/etc/chrony/chrony.conf" || return 1
  remote_exec "systemctl enable --now chrony" || return 1
}

# Configure unattended-upgrades for automatic security updates
_configure_unattended_upgrades() {
  remote_copy "templates/50unattended-upgrades" "/etc/apt/apt.conf.d/50unattended-upgrades" || return 1
  remote_copy "templates/20auto-upgrades" "/etc/apt/apt.conf.d/20auto-upgrades" || return 1
  remote_exec "systemctl enable --now unattended-upgrades" || return 1
}

# Configure CPU governor via systemd (uses CPU_GOVERNOR global)
_configure_cpu_governor() {
  local governor="${CPU_GOVERNOR:-performance}"
  remote_copy "templates/cpupower.service" "/etc/systemd/system/cpupower.service" || return 1
  remote_exec "chmod 644 /etc/systemd/system/cpupower.service" || return 1
  remote_exec "
    systemctl daemon-reload
    systemctl enable --now cpupower.service
    cpupower frequency-set -g \"$governor\" 2>/dev/null || true
  " || return 1
}

# Configure I/O scheduler via udev (none/mq-deadline/bfq)
_configure_io_scheduler() {
  remote_copy "templates/60-io-scheduler.rules" "/etc/udev/rules.d/60-io-scheduler.rules" || return 1
  remote_exec "udevadm control --reload-rules && udevadm trigger" || return 1
}

# Remove Proxmox subscription notice (non-enterprise only)
_remove_subscription_notice() {
  remote_copy "templates/remove-subscription-nag.sh" "/tmp/remove-subscription-nag.sh" || return 1
  remote_exec "chmod +x /tmp/remove-subscription-nag.sh && /tmp/remove-subscription-nag.sh && rm -f /tmp/remove-subscription-nag.sh" || return 1
}

# Private implementation

# Configure system services (chrony, upgrades, CPU governor)
# Designed for parallel execution - uses direct calls, no progress display
_config_system_services() {
  # Configure NTP time synchronization with chrony (package already installed)
  log_info "Configuring chrony"
  _configure_chrony || {
    log_error "Failed to configure chrony"
    return 1
  }

  # Configure Unattended Upgrades (package already installed)
  log_info "Configuring unattended-upgrades"
  _configure_unattended_upgrades || {
    log_error "Failed to configure unattended-upgrades"
    return 1
  }

  # Configure kernel modules (nf_conntrack, tcp_bbr)
  log_info "Configuring kernel modules"
  # shellcheck disable=SC2016 # Single quotes intentional - executed on remote
  remote_exec '
    for mod in nf_conntrack tcp_bbr; do
      if ! grep -q "^${mod}$" /etc/modules 2>/dev/null; then
        echo "$mod" >> /etc/modules
      fi
    done
    modprobe tcp_bbr 2>/dev/null || true
  ' >>"$LOG_FILE" 2>&1 || {
    log_error "Failed to configure kernel modules"
    return 1
  }

  # Configure system limits (nofile for containers/monitoring)
  log_info "Configuring system limits"
  remote_copy "templates/99-limits.conf" "/etc/security/limits.d/99-proxmox.conf" || {
    log_error "Failed to configure system limits"
    return 1
  }

  # Disable APT translations (saves disk/bandwidth on servers)
  log_info "Optimizing APT configuration"
  remote_exec 'echo "Acquire::Languages \"none\";" > /etc/apt/apt.conf.d/99-disable-translations' \
    >>"$LOG_FILE" 2>&1 || {
    log_error "Failed to optimize APT configuration"
    return 1
  }

  # Configure CPU governor using linux-cpupower
  # Governor already validated by wizard (only shows available options)
  local governor="${CPU_GOVERNOR:-performance}"
  log_info "Configuring CPU governor (${governor})"
  _configure_cpu_governor || {
    log_error "Failed to configure CPU governor"
    return 1
  }

  # Configure I/O scheduler udev rules (NVMe: none, SSD: mq-deadline, HDD: bfq)
  log_info "Configuring I/O scheduler"
  _configure_io_scheduler || {
    log_error "Failed to configure I/O scheduler"
    return 1
  }

  # Remove Proxmox subscription notice (only for non-enterprise)
  if [[ ${PVE_REPO_TYPE:-no-subscription} != "enterprise" ]]; then
    log_info "Removing Proxmox subscription notice (non-enterprise)"
    _remove_subscription_notice || {
      log_error "Failed to remove subscription notice"
      return 1
    }
  fi

  parallel_mark_configured "services"
}

# Public wrapper

# Configure system services (NTP, upgrades, CPU governor, I/O scheduler)
configure_system_services() {
  _config_system_services
}
# shellcheck shell=bash
# nftables Firewall rule generators
# Returns nftables rule text via stdout

# Generates port accept rules based on firewall mode
# Note: pveproxy listens on 8006 (hardcoded), DNAT redirects 443→8006
_generate_port_rules() {
  local mode="${1:-standard}"
  local ssh="${PORT_SSH:-22}"

  case "$mode" in
    stealth)
      cat <<'EOF'
        # Stealth mode: all public ports blocked
        # Access only via Tailscale VPN or VM bridges
EOF
      ;;
    strict)
      cat <<EOF
        # SSH access (port $ssh)
        tcp dport $ssh ct state new accept
EOF
      ;;
    standard | *)
      cat <<EOF
        # SSH access (port $ssh)
        tcp dport $ssh ct state new accept

        # Proxmox Web UI (port 8006, after DNAT from 443)
        tcp dport 8006 ct state new accept
EOF
      ;;
  esac

  # Add port 80 for Let's Encrypt HTTP challenge (initial + renewals)
  if [[ $SSL_TYPE == "letsencrypt" && $mode != "stealth" ]]; then
    cat <<'EOF'

        # HTTP for Let's Encrypt ACME challenge
        tcp dport 80 ct state new accept
EOF
  fi
}

# Generates bridge interface rules for input chain
_generate_bridge_input_rules() {
  local mode="${BRIDGE_MODE:-internal}"

  case "$mode" in
    internal)
      cat <<'EOF'
        # Allow traffic from vmbr0 (private NAT network)
        iifname "vmbr0" accept
EOF
      ;;
    external)
      cat <<'EOF'
        # Allow traffic from vmbr1 (external bridge)
        iifname "vmbr1" accept
EOF
      ;;
    both)
      cat <<'EOF'
        # Allow traffic from vmbr0 (private NAT network)
        iifname "vmbr0" accept

        # Allow traffic from vmbr1 (public IPs)
        iifname "vmbr1" accept
EOF
      ;;
  esac
}

# Generates bridge interface rules for forward chain
_generate_bridge_forward_rules() {
  local mode="${BRIDGE_MODE:-internal}"

  case "$mode" in
    internal)
      cat <<'EOF'
        # Allow forwarding for vmbr0 (private NAT network)
        iifname "vmbr0" accept
        oifname "vmbr0" accept
EOF
      ;;
    external)
      cat <<'EOF'
        # Allow forwarding for vmbr1 (external bridge)
        iifname "vmbr1" accept
        oifname "vmbr1" accept
EOF
      ;;
    both)
      cat <<'EOF'
        # Allow forwarding for vmbr0 (private NAT network)
        iifname "vmbr0" accept
        oifname "vmbr0" accept

        # Allow forwarding for vmbr1 (public IPs)
        iifname "vmbr1" accept
        oifname "vmbr1" accept
EOF
      ;;
  esac
}

# Generates Tailscale interface rules if enabled
_generate_tailscale_rules() {
  if [[ $INSTALL_TAILSCALE == "yes" ]]; then
    cat <<'EOF'
        # Allow Tailscale VPN interface (traffic already on tunnel)
        iifname "tailscale0" accept

        # Allow incoming WireGuard UDP for direct peer connections
        # Required for NAT hole-punching and peer-to-peer connectivity
        udp dport 41641 accept
EOF
  else
    echo "        # Tailscale not installed"
  fi
}

# Generates NAT masquerade rules for private subnet
_generate_nat_rules() {
  local mode="${BRIDGE_MODE:-internal}"
  local subnet="${PRIVATE_SUBNET:-10.0.0.0/24}"

  case "$mode" in
    internal | both)
      cat <<EOF
        # Masquerade traffic from private subnet to internet
        oifname != "lo" ip saddr $subnet masquerade
EOF
      ;;
    external)
      echo "        # External mode: no NAT needed (VMs have public IPs)"
      ;;
  esac
}

# Generates DNAT prerouting rules for port redirection
# pveproxy is hardcoded to listen on 8006, redirect 443→8006 for convenience
_generate_prerouting_rules() {
  local mode="${1:-standard}"
  local webui="${PORT_PROXMOX_UI:-443}"

  case "$mode" in
    stealth)
      echo "        # Stealth mode: no public port redirects"
      ;;
    strict)
      echo "        # Strict mode: no web UI redirect"
      ;;
    standard | *)
      cat <<EOF
        # Redirect HTTPS (port $webui) to pveproxy (port 8006)
        tcp dport $webui redirect to :8006
EOF
      ;;
  esac
}
# shellcheck shell=bash
# nftables Firewall configuration
# Modern replacement for iptables with unified IPv4/IPv6 rules
# Package installed via batch_install_packages() in 037-parallel-helpers.sh

# Generates complete nftables.conf content
_generate_nftables_conf() {
  cat <<EOF
#!/usr/sbin/nft -f
# nftables firewall configuration for Proxmox VE
# Generated by proxmox-installer
# Bridge mode: ${BRIDGE_MODE:-internal}
# Firewall mode: ${FIREWALL_MODE:-standard}

flush ruleset

# Main filter table for IPv4/IPv6
table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;

        # Allow established and related connections (stateful firewall)
        ct state established,related accept

        # Drop invalid packets
        ct state invalid drop

        # Allow loopback interface (required for local services)
        iifname "lo" accept

$(_generate_bridge_input_rules)

$(_generate_tailscale_rules)

        # ICMPv4: allow essential types with rate limiting
        ip protocol icmp icmp type { echo-request, echo-reply, destination-unreachable, time-exceeded } limit rate 10/second accept

        # ICMPv6: allow essential types (required for IPv6 to work properly)
        ip6 nexthdr icmpv6 icmpv6 type { echo-request, echo-reply, destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } limit rate 10/second accept

$(_generate_port_rules "$FIREWALL_MODE")

        # Everything else is dropped (default policy)
    }

    chain forward {
        type filter hook forward priority filter; policy accept;

$(_generate_bridge_forward_rules)

        # Allow established/related
        ct state established,related accept

        # Drop invalid packets
        ct state invalid drop
    }

    chain output {
        type filter hook output priority filter; policy accept;
        # Allow all outbound traffic
    }
}

# NAT table for VM internet access and port redirection
table inet nat {
    chain prerouting {
        type nat hook prerouting priority dstnat;

$(_generate_prerouting_rules "$FIREWALL_MODE")
    }

    chain postrouting {
        type nat hook postrouting priority srcnat;

$(_generate_nat_rules)
    }
}
EOF
}

# Main implementation for nftables configuration
_config_nftables() {
  # Set up iptables-nft compatibility layer
  log_info "Setting up iptables-nft compatibility layer"
  remote_exec '
    update-alternatives --set iptables /usr/sbin/iptables-nft
    update-alternatives --set ip6tables /usr/sbin/ip6tables-nft
  ' >>"$LOG_FILE" 2>&1 || log_warn "Could not set iptables-nft alternatives"

  # Generate complete config
  local config_file="./templates/nftables.conf.generated"
  if ! _generate_nftables_conf >"$config_file"; then
    log_error "Failed to generate nftables config"
    return 1
  fi

  log_info "Generated nftables config (mode: $FIREWALL_MODE, bridge: $BRIDGE_MODE)"

  # Deploy to VM
  remote_copy "$config_file" "/etc/nftables.conf" || {
    log_error "Failed to deploy nftables config"
    rm -f "$config_file"
    return 1
  }

  # Validate syntax
  remote_exec "nft -c -f /etc/nftables.conf" || {
    log_error "nftables config syntax validation failed"
    rm -f "$config_file"
    return 1
  }

  # Enable service
  remote_exec "systemctl enable --now nftables" || {
    log_error "Failed to enable nftables"
    rm -f "$config_file"
    return 1
  }

  rm -f "$config_file"
}

# Public function: configures nftables firewall
# Modes: stealth (VPN only), strict (SSH only), standard (SSH + Web UI)
configure_firewall() {
  if [[ $INSTALL_FIREWALL != "yes" ]]; then
    log_info "Skipping firewall configuration (INSTALL_FIREWALL=$INSTALL_FIREWALL)"
    return 0
  fi

  log_info "Configuring nftables firewall (mode: $FIREWALL_MODE, bridge: $BRIDGE_MODE)"

  local mode_display=""
  case "$FIREWALL_MODE" in
    stealth) mode_display="stealth (Tailscale only)" ;;
    strict) mode_display="strict (SSH only)" ;;
    standard) mode_display="standard (SSH + Web UI)" ;;
    *) mode_display="$FIREWALL_MODE" ;;
  esac

  if ! run_with_progress "Configuring nftables firewall" "Firewall configured ($mode_display)" _config_nftables; then
    log_warn "Firewall setup failed"
  fi
  return 0
}
# shellcheck shell=bash
# Fail2Ban configuration for brute-force protection
# Protects SSH and Proxmox API from brute-force attacks
# Package installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for Fail2Ban
# Deploys jail config and Proxmox filter, enables service
_config_fail2ban() {
  deploy_template "templates/fail2ban-jail.local" "/etc/fail2ban/jail.local" \
    "EMAIL=${EMAIL}" "HOSTNAME=${PVE_HOSTNAME}" || return 1

  remote_copy "templates/fail2ban-proxmox.conf" "/etc/fail2ban/filter.d/proxmox.conf" || {
    log_error "Failed to deploy fail2ban filter"
    return 1
  }

  remote_enable_services "fail2ban" || return 1
  parallel_mark_configured "fail2ban"
}

# Public wrapper

# Public wrapper for Fail2Ban configuration
configure_fail2ban() {
  # Requires firewall and not stealth mode
  [[ ${INSTALL_FIREWALL:-} != "yes" || ${FIREWALL_MODE:-standard} == "stealth" ]] && return 0
  _config_fail2ban
}
# shellcheck shell=bash
# AppArmor configuration for Proxmox VE
# Provides mandatory access control (MAC) for LXC containers and system services
# Package installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for AppArmor
# Configures GRUB for kernel parameters and enables service
_config_apparmor() {
  # Copy GRUB config (deploy_template creates parent dirs automatically)
  deploy_template "templates/apparmor-grub.cfg" "/etc/default/grub.d/apparmor.cfg"

  # Update boot config and enable AppArmor service (activates after reboot)
  log_info "Updating boot configuration and enabling AppArmor"
  remote_exec '
    if proxmox-boot-tool status &>/dev/null; then
      proxmox-boot-tool refresh
    else
      update-grub
    fi
    systemctl enable --now apparmor.service
  ' >>"$LOG_FILE" 2>&1 || {
    log_error "Failed to configure AppArmor"
    return 1
  }

  parallel_mark_configured "apparmor"
}

# Public wrapper (generated via factory)
make_feature_wrapper "apparmor" "INSTALL_APPARMOR"
# shellcheck shell=bash
# Auditd configuration for administrative action logging
# Provides audit trail for security compliance and forensics
# Package installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for auditd
# Deploys audit rules and configures log retention
_config_auditd() {
  deploy_template "templates/auditd-rules" "/etc/audit/rules.d/proxmox.rules" \
    "ADMIN_USERNAME=${ADMIN_USERNAME}" || {
    log_error "Failed to deploy auditd rules"
    return 1
  }

  # Configure auditd log settings (50MB files, 10 max, rotate)
  # Remove other rules FIRST to avoid "failure 1" duplicate warnings during augenrules --load
  # Stop auditd before modifying rules to prevent conflicts
  # shellcheck disable=SC2016
  remote_exec '
    mkdir -p /var/log/audit
    # Create directories that audit rules will watch (rules fail if paths dont exist)
    mkdir -p /etc/ssh/sshd_config.d /root/.ssh /etc/network/interfaces.d
    mkdir -p /etc/modprobe.d /etc/cron.d /etc/cron.daily /etc/cron.hourly
    mkdir -p /etc/cron.monthly /etc/cron.weekly /var/spool/cron/crontabs
    mkdir -p /etc/sudoers.d /etc/pam.d /etc/security /etc/init.d
    mkdir -p /etc/systemd/system /etc/fail2ban
    mkdir -p /home/'"${ADMIN_USERNAME}"'/.ssh
    chmod 700 /root/.ssh /home/'"${ADMIN_USERNAME}"'/.ssh
    # audit-rules.service must start AFTER pve-cluster mounts /etc/pve (FUSE filesystem)
    mkdir -p /etc/systemd/system/audit-rules.service.d
    cat > /etc/systemd/system/audit-rules.service.d/after-pve.conf << "DROPIN"
[Unit]
After=pve-cluster.service
Wants=pve-cluster.service
DROPIN
    # Remove ALL default/conflicting rules before our rules
    find /etc/audit/rules.d -name "*.rules" ! -name "proxmox.rules" -delete 2>/dev/null || true
    rm -f /etc/audit/audit.rules 2>/dev/null || true
    # Configure auditd settings
    sed -i "s/^max_log_file = .*/max_log_file = 50/" /etc/audit/auditd.conf
    sed -i "s/^num_logs = .*/num_logs = 10/" /etc/audit/auditd.conf
    sed -i "s/^max_log_file_action = .*/max_log_file_action = ROTATE/" /etc/audit/auditd.conf
    # Enable auditd for boot (dont start yet)
    systemctl daemon-reload
    systemctl enable auditd
    # Stop auditd, load new rules, then restart
    # auditd requires special handling - use service command for stop/start
    service auditd stop 2>/dev/null || true
    sleep 1
    auditctl -D 2>/dev/null || true
    augenrules --load 2>/dev/null || true
    # Start with retry - audit subsystem may need time to stabilize
    for i in 1 2 3; do
      service auditd start 2>/dev/null && break
      sleep 2
    done
  ' || {
    log_error "Failed to configure auditd"
    return 1
  }
  parallel_mark_configured "auditd"
}

# Public wrapper (generated via factory)
make_feature_wrapper "auditd" "INSTALL_AUDITD"
# shellcheck shell=bash
# AIDE (Advanced Intrusion Detection Environment) configuration
# File integrity monitoring for detecting unauthorized changes
# Package installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for AIDE
# Initializes database and sets up daily checks via systemd timer
_config_aide() {
  # Deploy systemd timer for daily checks
  deploy_systemd_timer "aide-check" || return 1

  # Initialize AIDE database and move to active location
  remote_exec '
    aideinit -y -f
    [[ -f /var/lib/aide/aide.db.new ]] && mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
  ' || {
    log_error "Failed to initialize AIDE"
    return 1
  }

  parallel_mark_configured "aide"
}

# Public wrapper (generated via factory)
make_feature_wrapper "aide" "INSTALL_AIDE"
# shellcheck shell=bash
# chkrootkit - Rootkit detection scanner
# Weekly scheduled scans with logging
# Package installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for chkrootkit
# Sets up weekly scans via systemd timer with logging
_config_chkrootkit() {
  deploy_timer_with_logdir "chkrootkit-scan" "/var/log/chkrootkit" || return 1
  parallel_mark_configured "chkrootkit"
}

# Public wrapper (generated via factory)
make_feature_wrapper "chkrootkit" "INSTALL_CHKROOTKIT"
# shellcheck shell=bash
# Lynis - Security auditing and hardening tool
# Weekly scheduled scans with logging
# Package installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for lynis
# Sets up weekly scans via systemd timer with logging
_config_lynis() {
  deploy_timer_with_logdir "lynis-audit" "/var/log/lynis" || return 1
  parallel_mark_configured "lynis"
}

# Public wrapper (generated via factory)
make_feature_wrapper "lynis" "INSTALL_LYNIS"
# shellcheck shell=bash
# needrestart - Checks which services need restart after library upgrades
# Automatically restarts services when libraries are updated
# Package installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for needrestart
# Deploys configuration for automatic restarts
_config_needrestart() {
  deploy_template "templates/needrestart.conf" "/etc/needrestart/conf.d/50-autorestart.conf" || {
    log_error "Failed to deploy needrestart config"
    return 1
  }

  parallel_mark_configured "needrestart"
}

# Public wrapper (generated via factory)
make_feature_wrapper "needrestart" "INSTALL_NEEDRESTART"
# shellcheck shell=bash
# vnstat - Network traffic monitoring
# Lightweight daemon for monitoring network bandwidth usage
# Package installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for vnstat
# Deploys config and initializes database for network interfaces
_config_vnstat() {
  local iface="${INTERFACE_NAME:-eth0}"

  deploy_template "templates/vnstat.conf" "/etc/vnstat.conf" "INTERFACE_NAME=${iface}" || return 1

  # Add main interface and bridge interfaces to vnstat monitoring
  remote_exec "
    mkdir -p /var/lib/vnstat
    vnstat --add -i '${iface}'
    for bridge in vmbr0 vmbr1; do
      ip link show \"\$bridge\" &>/dev/null && vnstat --add -i \"\$bridge\"
    done
    systemctl enable --now vnstat
  " || {
    log_error "Failed to configure vnstat"
    return 1
  }

  parallel_mark_configured "vnstat"
}

# Public wrapper (generated via factory)
# Called via run_parallel_group() in parallel execution
make_feature_wrapper "vnstat" "INSTALL_VNSTAT"
# shellcheck shell=bash
# Promtail - Log collector for Grafana Loki
# Collects system, auth, and Proxmox logs
# Package installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for promtail
_config_promtail() {
  # Deploy configuration with hostname (deploy_template creates parent dirs)
  deploy_template "templates/promtail.yml" "/etc/promtail/promtail.yml" \
    "HOSTNAME=${PVE_HOSTNAME}" || return 1

  # Deploy systemd service
  deploy_template "templates/promtail.service" "/etc/systemd/system/promtail.service" || return 1

  # Create positions directory (not handled by deploy_template - different path)
  remote_exec 'mkdir -p /var/lib/promtail' || return 1

  # Enable and start service
  remote_enable_services "promtail" || return 1
  parallel_mark_configured "promtail"
}

# Public wrapper (generated via factory)
# Collects logs from: /var/log/syslog, auth.log, pve*.log, kernel, journal
# Loki URL must be configured post-installation in /etc/promtail/promtail.yml
make_feature_wrapper "promtail" "INSTALL_PROMTAIL"
# shellcheck shell=bash
# Netdata - Real-time performance and health monitoring
# Provides web dashboard on port 19999
# Package installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for netdata
_config_netdata() {
  # Determine bind address based on Tailscale
  local bind_to="127.0.0.1"
  if [[ $INSTALL_TAILSCALE == "yes" ]]; then
    bind_to="127.0.0.1 100.*"
  fi

  deploy_template "templates/netdata.conf" "/etc/netdata/netdata.conf" \
    "NETDATA_BIND_TO=${bind_to}" || return 1

  # Configure journald namespace for netdata to prevent corruption on unclean shutdown
  deploy_template "templates/journald-netdata.conf" \
    "/etc/systemd/journald@netdata.conf" || return 1

  remote_enable_services "netdata" || return 1
  parallel_mark_configured "netdata"
}

# Public wrapper (generated via factory)
# Provides web dashboard on port 19999.
# If Tailscale enabled: accessible via Tailscale network
# Otherwise: localhost only (use reverse proxy for external access)
make_feature_wrapper "netdata" "INSTALL_NETDATA"
# shellcheck shell=bash
# Postfix mail relay configuration

# Private implementation - configures Postfix SMTP relay
_config_postfix_relay() {
  local relay_host="${SMTP_RELAY_HOST}"
  local relay_port="${SMTP_RELAY_PORT:-587}"
  local relay_user="${SMTP_RELAY_USER}"
  local relay_pass="${SMTP_RELAY_PASSWORD}"

  # Deploy main.cf configuration
  deploy_template "templates/postfix-main.cf" "/etc/postfix/main.cf" \
    "SMTP_RELAY_HOST=${relay_host}" \
    "SMTP_RELAY_PORT=${relay_port}" \
    "HOSTNAME=${PVE_HOSTNAME}" \
    "DOMAIN_SUFFIX=${DOMAIN_SUFFIX}" || return 1

  # Create SASL password file (use temp file + copy to handle special chars safely)
  local tmp_passwd
  tmp_passwd=$(mktemp) || return 1
  printf '[%s]:%s %s:%s\n' "$relay_host" "$relay_port" "$relay_user" "$relay_pass" >"$tmp_passwd"

  remote_copy "$tmp_passwd" "/etc/postfix/sasl_passwd" || {
    rm -f "$tmp_passwd"
    return 1
  }
  rm -f "$tmp_passwd"

  # Secure password file and generate hash (set umask to prevent any readable window)
  remote_exec '
    umask 077
    chmod 600 /etc/postfix/sasl_passwd
    chown root:root /etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd
    chmod 600 /etc/postfix/sasl_passwd.db
    chown root:root /etc/postfix/sasl_passwd.db
  ' || return 1

  # Restart Postfix
  remote_run "Restarting Postfix" \
    'systemctl restart postfix' \
    "Postfix relay configured"

  parallel_mark_configured "postfix"
}

# Private implementation - disables Postfix service
_config_postfix_disable() {
  remote_exec 'systemctl stop postfix 2>/dev/null; systemctl disable postfix 2>/dev/null' || true
  log_info "Postfix disabled"
  parallel_mark_configured "postfix disabled"
}

# Public wrapper - configures or disables Postfix based on INSTALL_POSTFIX
configure_postfix() {
  if [[ $INSTALL_POSTFIX == "yes" ]]; then
    if [[ -n $SMTP_RELAY_HOST && -n $SMTP_RELAY_USER && -n $SMTP_RELAY_PASSWORD ]]; then
      _config_postfix_relay
    else
      log_warn "Postfix enabled but SMTP relay not configured, skipping"
    fi
  elif [[ $INSTALL_POSTFIX == "no" ]]; then
    _config_postfix_disable
  fi
  # If INSTALL_POSTFIX is empty, leave Postfix as default (no changes)
}
# shellcheck shell=bash
# Network Ring Buffer Tuning
# Increases ring buffer size for better throughput and reduced packet drops
# Package (ethtool) installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for ring buffer tuning
# Deploys systemd service and script to maximize RX/TX ring buffer size
_config_ringbuffer() {
  # Deploy the script (auto-detects physical interfaces at runtime)
  remote_copy "templates/network-ringbuffer.sh" "/usr/local/bin/network-ringbuffer.sh" || return 1
  remote_exec "chmod +x /usr/local/bin/network-ringbuffer.sh" || return 1

  deploy_systemd_service "network-ringbuffer" || return 1
  parallel_mark_configured "ringbuffer"
}

# Public wrapper (generated via factory)
make_feature_wrapper "ringbuffer" "INSTALL_RINGBUFFER"
# shellcheck shell=bash
# Yazi file manager configuration
# Modern terminal file manager with image preview support
# Package and dependencies installed via batch_install_packages() in 033-parallel-helpers.sh
# Config is deployed to admin user's home directory (not root)

# Configuration function for yazi - deploys theme and plugins
_config_yazi() {

  # Install flavor and plugins as admin user
  # Note: ya pkg may fail if network is unavailable - log warning but don't fail
  # Yazi still works without plugins, user can install later
  # shellcheck disable=SC2016
  remote_exec 'su - '"${ADMIN_USERNAME}"' -c "
    ya pkg add kalidyasin/yazi-flavors:tokyonight-night || echo \"WARNING: Failed to install yazi flavor\" >&2
    ya pkg add yazi-rs/plugins:chmod || echo \"WARNING: Failed to install chmod plugin\" >&2
    ya pkg add yazi-rs/plugins:smart-enter || echo \"WARNING: Failed to install smart-enter plugin\" >&2
    ya pkg add yazi-rs/plugins:smart-filter || echo \"WARNING: Failed to install smart-filter plugin\" >&2
    ya pkg add yazi-rs/plugins:full-border || echo \"WARNING: Failed to install full-border plugin\" >&2
  "' || {
    log_warn "Failed to install some yazi plugins (yazi will still work)"
  }

  deploy_user_configs \
    "templates/yazi.toml:.config/yazi/yazi.toml" \
    "templates/yazi-theme.toml:.config/yazi/theme.toml" \
    "templates/yazi-init.lua:.config/yazi/init.lua" \
    "templates/yazi-keymap.toml:.config/yazi/keymap.toml" || {
    log_error "Failed to deploy yazi configs"
    return 1
  }

  parallel_mark_configured "yazi"
}

# Public wrapper (generated via factory)
# Installs yazi file manager with Tokyo Night theme
make_feature_wrapper "yazi" "INSTALL_YAZI"
# shellcheck shell=bash
# Neovim configuration
# Modern extensible text editor
# Package installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for neovim
# Creates vi/vim aliases via update-alternatives
_config_nvim() {
  # Install nvim as vi/vim/editor alternatives and set as default
  remote_exec '
    update-alternatives --install /usr/bin/vi vi /usr/bin/nvim 60
    update-alternatives --install /usr/bin/vim vim /usr/bin/nvim 60
    update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 60
    update-alternatives --set vi /usr/bin/nvim
    update-alternatives --set vim /usr/bin/nvim
    update-alternatives --set editor /usr/bin/nvim
  ' || {
    log_error "Failed to configure nvim alternatives"
    return 1
  }

  parallel_mark_configured "nvim"
}

# Public wrapper (generated via factory)
make_feature_wrapper "nvim" "INSTALL_NVIM"
# shellcheck shell=bash
# Fastfetch shell integration

# Configure fastfetch shell integration
_configure_fastfetch() {
  remote_copy "templates/fastfetch.sh" "/etc/profile.d/fastfetch.sh" || return 1
  remote_exec "chmod +x /etc/profile.d/fastfetch.sh" || return 1
}
# shellcheck shell=bash
# Bat syntax highlighting configuration

# Configure bat with theme and symlink
_configure_bat() {
  remote_exec "ln -sf /usr/bin/batcat /usr/local/bin/bat" || return 1
  deploy_user_config "templates/bat-config" ".config/bat/config" || return 1
}
# shellcheck shell=bash
# Shell configuration (ZSH with Oh-My-Zsh)

# Configure ZSH with .zshrc
_configure_zsh_files() {
  require_admin_username "configure ZSH files" || return 1
  deploy_user_config "templates/zshrc" ".zshrc" "LOCALE=${LOCALE}" || return 1
  remote_exec "chsh -s /bin/zsh ${ADMIN_USERNAME}" || return 1
}

# Configure admin shell (installs Oh-My-Zsh if ZSH)
# Designed for parallel execution - uses direct remote_exec, no progress display
_config_shell() {
  # Configure default shell for admin user (root login is disabled)
  if [[ $SHELL_TYPE == "zsh" ]]; then
    require_admin_username "configure shell" || return 1

    # Install Oh-My-Zsh for admin user
    log_info "Installing Oh-My-Zsh for ${ADMIN_USERNAME}"
    # shellcheck disable=SC2016 # Single quotes intentional - executed on remote system
    remote_exec '
      set -e
      export RUNZSH=no
      export CHSH=no
      export HOME=/home/'"$ADMIN_USERNAME"'
      su - '"$ADMIN_USERNAME"' -c "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended"
    ' >>"$LOG_FILE" 2>&1 || {
      log_error "Failed to install Oh-My-Zsh"
      return 1
    }

    # Parallel git clones for theme and plugins (all independent after Oh-My-Zsh)
    log_info "Installing ZSH plugins"
    # shellcheck disable=SC2016 # $pid vars expand on remote; ADMIN_USERNAME uses quote concatenation
    remote_exec '
      set -e
      git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions /home/'"$ADMIN_USERNAME"'/.oh-my-zsh/custom/plugins/zsh-autosuggestions &
      pid1=$!
      git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting /home/'"$ADMIN_USERNAME"'/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting &
      pid2=$!
      # Wait and check exit codes (set -e doesnt catch background failures)
      failed=0
      wait "$pid1" || failed=1
      wait "$pid2" || failed=1
      if [[ $failed -eq 1 ]]; then
        echo "ERROR: Failed to clone ZSH plugins" >&2
        exit 1
      fi
      # Validate directories exist
      for dir in plugins/zsh-autosuggestions plugins/zsh-syntax-highlighting; do
        if [[ ! -d "/home/'"$ADMIN_USERNAME"'/.oh-my-zsh/custom/$dir" ]]; then
          echo "ERROR: ZSH plugin directory missing: $dir" >&2
          exit 1
        fi
      done
      chown -R '"$ADMIN_USERNAME"':'"$ADMIN_USERNAME"' /home/'"$ADMIN_USERNAME"'/.oh-my-zsh
    ' >>"$LOG_FILE" 2>&1 || {
      log_error "Failed to install ZSH plugins"
      return 1
    }

    # Configure ZSH with .zshrc
    _configure_zsh_files || {
      log_error "Failed to configure ZSH files"
      return 1
    }
    parallel_mark_configured "zsh"
  else
    parallel_mark_configured "bash"
  fi
}

# Configure default shell (ZSH with Oh-My-Zsh if selected)
configure_shell() {
  _config_shell
}
# shellcheck shell=bash
# SSL certificate configuration via SSH

# Private implementation - configures SSL certificates
# Called by configure_ssl() public wrapper
# Designed for parallel execution (uses remote_exec, not remote_run)
_config_ssl() {
  log_debug "_config_ssl: SSL_TYPE=$SSL_TYPE"

  # Build FQDN if not set
  local cert_domain="${FQDN:-$PVE_HOSTNAME.$DOMAIN_SUFFIX}"
  log_debug "_config_ssl: domain=$cert_domain, email=$EMAIL"

  # Deploy Let's Encrypt templates to /tmp
  deploy_template "templates/letsencrypt-firstboot.sh" "/tmp/letsencrypt-firstboot.sh" \
    "CERT_DOMAIN=${cert_domain}" "CERT_EMAIL=${EMAIL}" || return 1

  remote_copy "templates/letsencrypt-deploy-hook.sh" "/tmp/letsencrypt-deploy-hook.sh" || return 1
  remote_copy "templates/letsencrypt-firstboot.service" "/tmp/letsencrypt-firstboot.service" || return 1

  # Install deploy hook, first-boot script, and systemd service
  log_info "Configuring Let's Encrypt first-boot service"
  remote_exec '
    set -e
    mkdir -p /etc/letsencrypt/renewal-hooks/deploy
    mv /tmp/letsencrypt-deploy-hook.sh /etc/letsencrypt/renewal-hooks/deploy/proxmox.sh
    chmod +x /etc/letsencrypt/renewal-hooks/deploy/proxmox.sh
    mv /tmp/letsencrypt-firstboot.sh /usr/local/bin/obtain-letsencrypt-cert.sh
    chmod +x /usr/local/bin/obtain-letsencrypt-cert.sh
    mv /tmp/letsencrypt-firstboot.service /etc/systemd/system/letsencrypt-firstboot.service
    systemctl daemon-reload
    systemctl enable letsencrypt-firstboot.service
  ' >>"$LOG_FILE" 2>&1 || {
    log_error "Failed to configure Let's Encrypt"
    return 1
  }

  # Store the domain for summary
  declare -g LETSENCRYPT_DOMAIN="$cert_domain"
  declare -g LETSENCRYPT_FIRSTBOOT=true

  parallel_mark_configured "ssl"
}

# Public wrapper (generated via factory)
# Configures SSL certificates for Proxmox Web UI.
# For Let's Encrypt, sets up first-boot certificate acquisition.
# Certbot package installed via batch_install_packages() in 037-parallel-helpers.sh
make_condition_wrapper "ssl" "SSL_TYPE" "letsencrypt"
# shellcheck shell=bash
# Configure Proxmox API Token

# Create Proxmox API token for automation (Terraform, Ansible)
_config_api_token() {
  log_info "Creating Proxmox API token for ${ADMIN_USERNAME}: ${API_TOKEN_NAME}"

  # Note: PAM user and Administrator role are set up in 302-configure-admin.sh

  # Check if token already exists and remove
  local existing
  existing=$(remote_exec "pveum user token list '${ADMIN_USERNAME}@pam' 2>/dev/null | grep -q '${API_TOKEN_NAME}' && echo 'exists' || echo ''")

  if [[ $existing == "exists" ]]; then
    log_warn "Token ${API_TOKEN_NAME} exists, removing first"
    remote_exec "pveum user token remove '${ADMIN_USERNAME}@pam' '${API_TOKEN_NAME}'" || {
      log_error "Failed to remove existing token"
      return 1
    }
  fi

  # Create privileged token without expiration using JSON output
  local output
  output=$(remote_exec "pveum user token add '${ADMIN_USERNAME}@pam' '${API_TOKEN_NAME}' --privsep 0 --expire 0 --output-format json 2>&1")

  if [[ -z $output ]]; then
    log_error "Failed to create API token - empty output"
    return 1
  fi

  # Extract token value from JSON output, skipping any non-JSON lines (perl warnings, etc.)
  # jq's try/fromjson handles invalid JSON gracefully
  local token_value
  token_value=$(printf '%s\n' "$output" | jq -R 'try (fromjson | .value) // empty' 2>/dev/null | grep -v '^$' | head -1)

  if [[ -z $token_value ]]; then
    log_error "Failed to extract token value from pveum output"
    log_debug "pveum output: $output"
    return 1
  fi

  # Store for final display
  declare -g API_TOKEN_VALUE="$token_value"
  declare -g API_TOKEN_ID="${ADMIN_USERNAME}@pam!${API_TOKEN_NAME}"

  # Save to temp file for display after installation (restricted permissions)
  # Uses centralized path constant from 003-init.sh, registered for cleanup
  (
    umask 0077
    cat >"$_TEMP_API_TOKEN_FILE" <<EOF
API_TOKEN_VALUE=$token_value
API_TOKEN_ID=$API_TOKEN_ID
API_TOKEN_NAME=$API_TOKEN_NAME
EOF
  )
  register_temp_file "$_TEMP_API_TOKEN_FILE"

  log_info "API token created successfully: ${API_TOKEN_ID}"
  parallel_mark_configured "api-token"
  return 0
}

# Public wrapper (generated via factory)
make_feature_wrapper "api_token" "INSTALL_API_TOKEN"
# shellcheck shell=bash
# Configure ZFS ARC memory allocation

# Private implementation - configures ZFS ARC memory
_config_zfs_arc() {
  log_info "Configuring ZFS ARC memory allocation (mode: $ZFS_ARC_MODE)"

  # Calculate ARC size locally (we know RAM from rescue system)
  local total_ram_mb
  total_ram_mb=$(free -m | awk 'NR==2 {print $2}')

  # Validate numeric before arithmetic
  if [[ ! $total_ram_mb =~ ^[0-9]+$ ]] || [[ $total_ram_mb -eq 0 ]]; then
    log_error "Failed to detect RAM size (got: '$total_ram_mb')"
    return 1
  fi

  local arc_max_mb
  case "$ZFS_ARC_MODE" in
    vm-focused)
      # Fixed 4GB for servers where VMs are primary workload
      arc_max_mb=4096
      ;;
    balanced)
      # Conservative ARC sizing based on RAM:
      # < 16GB: 25% of RAM
      # 16-64GB: 40% of RAM
      # > 64GB: 50% of RAM
      if [[ $total_ram_mb -lt 16384 ]]; then
        arc_max_mb="$((total_ram_mb * 25 / 100))"
      elif [[ $total_ram_mb -lt 65536 ]]; then
        arc_max_mb="$((total_ram_mb * 40 / 100))"
      else
        arc_max_mb="$((total_ram_mb / 2))"
      fi
      ;;
    storage-focused)
      # Use 50% of RAM (ZFS default behavior)
      arc_max_mb="$((total_ram_mb / 2))"
      ;;
    *)
      log_error "Invalid ZFS_ARC_MODE: $ZFS_ARC_MODE"
      return 1
      ;;
  esac

  local arc_max_bytes="$((arc_max_mb * 1024 * 1024))"

  log_info "ZFS ARC: ${arc_max_mb}MB (Total RAM: ${total_ram_mb}MB, Mode: $ZFS_ARC_MODE)"

  # Set ZFS ARC limit in modprobe config (persistent) and apply to running kernel
  remote_run "Configuring ZFS ARC memory" "
    echo 'options zfs zfs_arc_max=$arc_max_bytes' >/etc/modprobe.d/zfs.conf
    if [[ -f /sys/module/zfs/parameters/zfs_arc_max ]]; then
      echo '$arc_max_bytes' >/sys/module/zfs/parameters/zfs_arc_max 2>/dev/null || true
    fi
  "

  log_info "ZFS ARC memory limit configured: ${arc_max_mb}MB"
}

# Fix ZFS cachefile import issues during boot

# Private implementation - fixes cachefile import failures
_config_zfs_cachefile() {
  log_info "Configuring ZFS cachefile import fixes"

  # 1. Create systemd drop-in to ensure devices are ready before import
  remote_run "Creating systemd drop-in for zfs-import-cache.service" "
    mkdir -p /etc/systemd/system/zfs-import-cache.service.d
  " || return 1

  deploy_template "templates/zfs-import-cache.service.d-override.conf" \
    "/etc/systemd/system/zfs-import-cache.service.d/override.conf" || return 1

  # 2. Install initramfs hook to include cachefile in initramfs
  deploy_template "templates/zfs-cachefile-initramfs-hook" \
    "/etc/initramfs-tools/hooks/zfs-cachefile" || return 1

  remote_exec "chmod +x /etc/initramfs-tools/hooks/zfs-cachefile" || {
    log_error "Failed to make initramfs hook executable"
    return 1
  }

  # 3. Regenerate cachefile for all existing pools
  remote_run "Regenerating ZFS cachefile" "
    rm -f /etc/zfs/zpool.cache
    for pool in \$(zpool list -H -o name 2>/dev/null); do
      zpool set cachefile=/etc/zfs/zpool.cache \"\$pool\"
    done
  " "ZFS cachefile regenerated"

  log_info "ZFS cachefile import fixes configured"
}

# Configure ZFS scrub scheduling

# Private implementation - configures ZFS scrub timers
_config_zfs_scrub() {
  log_info "Configuring ZFS scrub schedule"

  # Deploy systemd service and timer templates
  remote_copy "templates/zfs-scrub.service" "/etc/systemd/system/zfs-scrub@.service" || {
    log_error "Failed to deploy ZFS scrub service"
    return 1
  }
  remote_exec "chmod 644 /etc/systemd/system/zfs-scrub@.service" || return 1
  remote_copy "templates/zfs-scrub.timer" "/etc/systemd/system/zfs-scrub@.timer" || {
    log_error "Failed to deploy ZFS scrub timer"
    return 1
  }
  remote_exec "chmod 644 /etc/systemd/system/zfs-scrub@.timer" || return 1

  # Determine data pool name: existing pool name or "tank"
  local data_pool="tank"
  if [[ $USE_EXISTING_POOL == "yes" && -n $EXISTING_POOL_NAME ]]; then
    data_pool="$EXISTING_POOL_NAME"
  fi

  log_info "Enabling scrub timers for pools: rpool (if exists), $data_pool"

  # Enable scrub timers for all detected pools
  remote_run "Enabling ZFS scrub timers" "
    systemctl daemon-reload
    for pool in \$(zpool list -H -o name 2>/dev/null); do
      systemctl enable --now zfs-scrub@\$pool.timer 2>/dev/null || true
    done
  "

  log_info "ZFS scrub schedule configured (monthly, 1st Sunday at 2:00 AM)"
}

# Public wrappers

# Public wrapper for ZFS ARC configuration
configure_zfs_arc() {
  _config_zfs_arc
  parallel_mark_configured "ZFS ARC ${ZFS_ARC_MODE}"
}

# Public wrapper for ZFS cachefile import fixes
configure_zfs_cachefile() {
  _config_zfs_cachefile
}

# Public wrapper for ZFS scrub scheduling
configure_zfs_scrub() {
  _config_zfs_scrub
}
# shellcheck shell=bash
# Configure separate ZFS pool for VMs

# Imports existing ZFS pool and configures Proxmox storage.
# Uses EXISTING_POOL_NAME global variable.
# Import existing ZFS pool, find/create vm-disks dataset
_config_import_existing_pool() {
  local pool_name="$EXISTING_POOL_NAME"
  log_info "Importing existing ZFS pool '$pool_name'"

  # Import pool with force flag (may have been used by different system)
  if ! remote_run "Importing ZFS pool '$pool_name'" \
    "zpool import -f '$pool_name' 2>/dev/null || zpool import -f -d /dev '$pool_name'" \
    "ZFS pool '$pool_name' imported"; then
    log_error "Failed to import ZFS pool '$pool_name'"
    return 1
  fi

  # Configure Proxmox storage - find or create vm-disks dataset
  if ! remote_run "Configuring Proxmox storage for '$pool_name'" "
    if zfs list '${pool_name}/vm-disks' >/dev/null 2>&1; then
      ds='${pool_name}/vm-disks'
    else
      ds=\$(zfs list -H -o name -r '${pool_name}' 2>/dev/null | grep -v '^${pool_name}\$' | head -1)
      [[ -z \$ds ]] && { zfs create '${pool_name}/vm-disks'; ds='${pool_name}/vm-disks'; }
    fi
    pvesm status '${pool_name}' >/dev/null 2>&1 || pvesm add zfspool '${pool_name}' --pool \"\$ds\" --content images,rootdir
    pvesm set local --content iso,vztmpl,backup,snippets
  " "Proxmox storage configured for '$pool_name'"; then
    log_error "Failed to configure Proxmox storage for '$pool_name'"
    return 1
  fi

  log_info "Existing ZFS pool '$pool_name' imported and configured"
  return 0
}

# Creates new ZFS pool from ZFS_POOL_DISKS using DEFAULT_ZFS_POOL_NAME.
# Uses ZFS_RAID global for RAID configuration.
# Create new ZFS pool with optimal settings
_config_create_new_pool() {
  local pool_name="$DEFAULT_ZFS_POOL_NAME"
  log_info "Creating separate ZFS pool '$pool_name' from pool disks"
  log_info "ZFS_POOL_DISKS=(${ZFS_POOL_DISKS[*]}), count=${#ZFS_POOL_DISKS[@]}"
  log_info "ZFS_RAID=$ZFS_RAID, BOOT_DISK=$BOOT_DISK"

  # Validate required variables
  if [[ ${#ZFS_POOL_DISKS[@]} -eq 0 ]]; then
    log_error "ZFS_POOL_DISKS is empty - no disks to create pool from"
    return 1
  fi
  if [[ -z $ZFS_RAID ]]; then
    log_error "ZFS_RAID is empty - RAID level not specified"
    return 1
  fi

  # Load virtio mapping from QEMU setup
  if ! load_virtio_mapping; then
    log_error "Failed to load virtio mapping"
    return 1
  fi

  # Map physical disks to virtio devices
  local vdevs_str
  vdevs_str=$(map_disks_to_virtio "space_separated" "${ZFS_POOL_DISKS[@]}")
  if [[ -z $vdevs_str ]]; then
    log_error "Failed to map pool disks to virtio devices"
    return 1
  fi
  read -ra vdevs <<<"$vdevs_str"
  log_info "Pool disks: ${vdevs[*]} (RAID: $ZFS_RAID)"

  # Build zpool create command based on RAID type
  local pool_cmd
  pool_cmd=$(build_zpool_command "$pool_name" "$ZFS_RAID" "${vdevs[@]}")
  if [[ -z $pool_cmd ]]; then
    log_error "Failed to build zpool create command"
    return 1
  fi
  log_info "ZFS pool command: $pool_cmd"

  # Validate command format before execution (defensive check)
  if [[ $pool_cmd != zpool\ create* ]]; then
    log_error "Invalid pool command format: $pool_cmd"
    return 1
  fi

  # Create pool, set properties, configure Proxmox storage
  # Use set -e to fail on ANY error (prevents silent failures)
  if ! remote_run "Creating ZFS pool '$pool_name'" "
    set -e
    ${pool_cmd}
    zfs set compression=lz4 '$pool_name'
    zfs set atime=off '$pool_name'
    zfs set xattr=sa '$pool_name'
    zfs set dnodesize=auto '$pool_name'
    zfs create '$pool_name'/vm-disks
    pvesm add zfspool '$pool_name' --pool '$pool_name'/vm-disks --content images,rootdir
    pvesm set local --content iso,vztmpl,backup,snippets
  " "ZFS pool '$pool_name' created"; then
    log_error "Failed to create ZFS pool '$pool_name'"
    return 1
  fi

  log_info "ZFS pool '$pool_name' created successfully"
  return 0
}

# Ensures local-zfs storage exists for rpool (Proxmox auto-install may not create it)
_config_ensure_rpool_storage() {
  log_info "Ensuring rpool storage is configured for Proxmox"

  # Check if rpool exists and configure storage if not already present
  # Use pvesm status first, fallback to grep on storage.cfg (pvesm may fail if storage has issues)
  # shellcheck disable=SC2016
  if ! remote_run "Configuring rpool storage" '
    if zpool list rpool &>/dev/null; then
      # Check if storage exists: pvesm status (works if healthy) OR grep config (always works)
      # Note: storage.cfg format is "zfspool: local-zfs" (type: name), not "local-zfs:"
      if pvesm status local-zfs &>/dev/null || grep -qE "^zfspool:[[:space:]]+local-zfs" /etc/pve/storage.cfg 2>/dev/null; then
        echo "local-zfs storage already exists"
      else
        zfs list rpool/data &>/dev/null || zfs create rpool/data
        pvesm add zfspool local-zfs --pool rpool/data --content images,rootdir
        pvesm set local --content iso,vztmpl,backup,snippets
        echo "local-zfs storage created"
      fi
    else
      echo "WARNING: rpool not found - system may have installed on LVM/ext4"
    fi
  ' "rpool storage configured"; then
    log_warn "rpool storage configuration had issues"
    # Don't fail - rpool might be intentionally absent if user chose different config
  fi
  return 0
}

# Main entry point - creates or imports ZFS pool based on configuration.
# Only runs when BOOT_DISK is set (ext4 install mode).
# When BOOT_DISK is empty, all disks are in ZFS rpool - ensures storage is configured.
_config_zfs_pool() {
  if [[ -z $BOOT_DISK ]]; then
    log_info "BOOT_DISK not set, all-ZFS mode - ensuring rpool storage"
    _config_ensure_rpool_storage
    return 0
  fi

  # If no pool disks defined, we're done (LVM already expanded by configure_lvm_storage)
  if [[ ${#ZFS_POOL_DISKS[@]} -eq 0 && $USE_EXISTING_POOL != "yes" ]]; then
    log_info "No ZFS pool disks - using expanded local storage only"
    return 0
  fi

  if [[ $USE_EXISTING_POOL == "yes" ]]; then
    _config_import_existing_pool
  else
    _config_create_new_pool
  fi
}

# Public wrapper

# Creates or imports ZFS pool when BOOT_DISK is set.
# Modes: USE_EXISTING_POOL=yes imports existing, otherwise creates DEFAULT_ZFS_POOL_NAME.
# Configures Proxmox storage: pool for VMs, local for ISO/templates.
configure_zfs_pool() {
  _config_zfs_pool
}
# shellcheck shell=bash
# Configure LVM storage for ext4 boot mode

# Expands LVM root to use all disk space (ext4 boot mode only).
# Removes local-lvm data LV and extends root LV to 100% free.
_config_expand_lvm_root() {
  log_info "Expanding LVM root to use all disk space"

  # shellcheck disable=SC2016
  if ! remote_run "Expanding LVM root filesystem" '
    set -e
    if ! vgs pve &>/dev/null; then
      echo "No pve VG found - not LVM install"
      exit 0
    fi
    if pvesm status local-lvm &>/dev/null; then
      pvesm remove local-lvm || true
      echo "Removed local-lvm storage"
    fi
    if lvs pve/data &>/dev/null; then
      lvremove -f /dev/pve/data
      echo "Removed data LV"
    fi
    free_extents=$(vgs --noheadings -o vg_free_count pve 2>/dev/null | xargs)
    if [[ "$free_extents" -gt 0 ]]; then
      lvextend -l +100%FREE /dev/pve/root
      resize2fs /dev/mapper/pve-root
      echo "Extended root LV to use all disk space"
    else
      echo "No free space in VG - root already uses all space"
    fi
    pvesm set local --content iso,vztmpl,backup,snippets,images,rootdir 2>/dev/null || true
  ' "LVM root filesystem expanded"; then
    log_warn "LVM expansion had issues, continuing"
  fi
  return 0
}

# Public wrapper - expands LVM root to use all disk space.
# Only runs in ext4 boot mode (BOOT_DISK set).
configure_lvm_storage() {
  [[ -z $BOOT_DISK ]] && return 0
  _config_expand_lvm_root
  parallel_mark_configured "LVM root expanded"
}
# shellcheck shell=bash
# Installation Cleanup
# Clears logs and syncs filesystems before shutdown

# Clears system logs from installation process for clean first boot.
# Removes journal logs, auth logs, and other installation artifacts.
cleanup_installation_logs() {
  remote_run "Cleaning up installation logs" '
    # Clear systemd journal (installation messages)
    journalctl --rotate 2>/dev/null || true
    journalctl --vacuum-time=1s 2>/dev/null || true

    # Clear traditional log files
    : > /var/log/syslog 2>/dev/null || true
    : > /var/log/messages 2>/dev/null || true
    : > /var/log/auth.log 2>/dev/null || true
    : > /var/log/kern.log 2>/dev/null || true
    : > /var/log/daemon.log 2>/dev/null || true
    : > /var/log/debug 2>/dev/null || true

    # Clear apt logs
    : > /var/log/apt/history.log 2>/dev/null || true
    : > /var/log/apt/term.log 2>/dev/null || true
    rm -f /var/log/apt/*.gz 2>/dev/null || true

    # Clear dpkg log
    : > /var/log/dpkg.log 2>/dev/null || true

    # Remove rotated logs
    find /var/log -name "*.gz" -delete 2>/dev/null || true
    find /var/log -name "*.[0-9]" -delete 2>/dev/null || true
    find /var/log -name "*.old" -delete 2>/dev/null || true

    # Clear lastlog and wtmp (login history)
    : > /var/log/lastlog 2>/dev/null || true
    : > /var/log/wtmp 2>/dev/null || true
    : > /var/log/btmp 2>/dev/null || true

    # Clear machine-id and regenerate on first boot (optional - makes system unique)
    # Commented out - may cause issues with some services
    # : > /etc/machine-id

    # Sync filesystems to ensure all data is written before shutdown
    # ZFS requires explicit zpool sync to commit all transactions (critical for data integrity)
    sync
    if command -v zpool &>/dev/null; then
      zpool sync 2>/dev/null || true
    fi
    umount /boot/efi 2>/dev/null || true
    sync
    # Final ZFS sync after EFI unmount
    if command -v zpool &>/dev/null; then
      zpool sync 2>/dev/null || true
    fi
  ' "Installation logs cleaned"
}
# shellcheck shell=bash
# EFI Fallback Bootloader Configuration

# Configures EFI fallback boot path for systems without NVRAM boot entries.
# Copies the installed bootloader to /EFI/BOOT/BOOTX64.EFI (UEFI default).
# This is required when installing via QEMU without persistent NVRAM.
configure_efi_fallback_boot() {
  # Only needed for UEFI systems
  if ! remote_exec 'test -d /sys/firmware/efi' 2>/dev/null; then
    log_info "Legacy BIOS mode - skipping EFI fallback configuration"
    return 0
  fi

  # shellcheck disable=SC2016 # Variables expand on remote, not locally
  remote_run "Configuring EFI fallback boot" '
    # Ensure EFI partition is mounted
    if ! mountpoint -q /boot/efi 2>/dev/null; then
      # Try fstab first, then find EFI partition directly
      if ! mount /boot/efi 2>/dev/null; then
        # Find EFI System Partition by type GUID
        efi_part=$(lsblk -no PATH,PARTTYPE 2>/dev/null \
          | grep -i "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" \
          | head -1 | awk "{print \$1}")

        if [[ -z $efi_part ]]; then
          # Fallback: find vfat partition on first disk
          efi_part=$(lsblk -no PATH,FSTYPE 2>/dev/null \
            | grep -E "vfat$" | head -1 | awk "{print \$1}")
        fi

        if [[ -n $efi_part ]]; then
          mkdir -p /boot/efi
          mount -t vfat "$efi_part" /boot/efi || exit 1
        else
          echo "WARNING: No EFI partition found - skipping fallback boot setup"
          exit 0
        fi
      fi
    fi

    # Create fallback directory if needed
    mkdir -p /boot/efi/EFI/BOOT

    # Find and copy the bootloader to fallback path
    # Priority: systemd-boot (ZFS) > GRUB (ext4/LVM) > shim (secure boot)
    bootloader=""
    if [[ -f /boot/efi/EFI/systemd/systemd-bootx64.efi ]]; then
      bootloader="/boot/efi/EFI/systemd/systemd-bootx64.efi"
    elif [[ -f /boot/efi/EFI/proxmox/grubx64.efi ]]; then
      bootloader="/boot/efi/EFI/proxmox/grubx64.efi"
    elif [[ -f /boot/efi/EFI/debian/grubx64.efi ]]; then
      bootloader="/boot/efi/EFI/debian/grubx64.efi"
    fi

    if [[ -z $bootloader ]]; then
      echo "WARNING: No bootloader found to copy to fallback path"
      exit 0
    fi

    # Copy to fallback path (overwrite if exists)
    cp -f "$bootloader" /boot/efi/EFI/BOOT/BOOTX64.EFI
    echo "Copied $bootloader to /EFI/BOOT/BOOTX64.EFI"
  ' "EFI fallback boot configured"
}
# shellcheck shell=bash
# SSH hardening and finalization

# Deploys hardened SSH configuration to remote system WITHOUT restarting.
# Uses sshd_config template with ADMIN_USERNAME substitution.
# Called before validation so we can verify the config file.
# shellcheck disable=SC2317 # invoked indirectly by run_with_progress
_deploy_ssh_config() {
  deploy_template "templates/sshd_config" "/etc/ssh/sshd_config" \
    "ADMIN_USERNAME=${ADMIN_USERNAME}" || return 1
}

# Deploys hardened sshd_config without restarting SSH service.
# SSH key was deployed to admin user in 302-configure-admin.sh.
deploy_ssh_hardening_config() {
  if ! run_with_progress "Deploying SSH hardening config" "SSH config deployed" _deploy_ssh_config; then
    log_error "SSH config deploy failed"
    return 1
  fi
}

# Restarts SSH service to apply hardened configuration.
# Called as the LAST SSH operation - after this, password auth is disabled.
restart_ssh_service() {
  log_info "Restarting SSH to apply hardening"
  # Use run_with_progress for consistent UI
  if ! run_with_progress "Applying SSH hardening" "SSH hardening active" \
    remote_exec "systemctl restart sshd"; then
    log_warn "SSH restart failed - config will apply on reboot"
  fi
}

# Installation Validation

# Validates installation by checking packages, services, and configs.
# Uses validation.sh.tmpl with variable substitution for enabled features.
# Shows FAIL/WARN results in live logs for visibility.
validate_installation() {
  log_info "Generating validation script from template..."

  # Stage template to preserve original
  local staged
  staged=$(mktemp) || {
    log_error "Failed to create temp file for validation.sh"
    return 1
  }
  register_temp_file "$staged"
  cp "./templates/validation.sh" "$staged" || {
    log_error "Failed to stage validation.sh"
    rm -f "$staged"
    return 1
  }

  # Generate validation script with current settings
  apply_template_vars "$staged" \
    "INSTALL_TAILSCALE=${INSTALL_TAILSCALE:-no}" \
    "INSTALL_FIREWALL=${INSTALL_FIREWALL:-no}" \
    "FIREWALL_MODE=${FIREWALL_MODE:-standard}" \
    "INSTALL_APPARMOR=${INSTALL_APPARMOR:-no}" \
    "INSTALL_AUDITD=${INSTALL_AUDITD:-no}" \
    "INSTALL_AIDE=${INSTALL_AIDE:-no}" \
    "INSTALL_CHKROOTKIT=${INSTALL_CHKROOTKIT:-no}" \
    "INSTALL_LYNIS=${INSTALL_LYNIS:-no}" \
    "INSTALL_NEEDRESTART=${INSTALL_NEEDRESTART:-no}" \
    "INSTALL_VNSTAT=${INSTALL_VNSTAT:-no}" \
    "INSTALL_PROMTAIL=${INSTALL_PROMTAIL:-no}" \
    "ADMIN_USERNAME=${ADMIN_USERNAME}" \
    "INSTALL_NETDATA=${INSTALL_NETDATA:-no}" \
    "INSTALL_YAZI=${INSTALL_YAZI:-no}" \
    "INSTALL_NVIM=${INSTALL_NVIM:-no}" \
    "INSTALL_RINGBUFFER=${INSTALL_RINGBUFFER:-no}" \
    "SHELL_TYPE=${SHELL_TYPE:-bash}" \
    "SSL_TYPE=${SSL_TYPE:-self-signed}"
  local validation_script
  validation_script=$(cat "$staged")
  rm -f "$staged"

  log_info "Validation script generated"
  printf '%s\n' "$validation_script" >>"$LOG_FILE"

  # Execute validation and capture output
  start_task "${TREE_BRANCH} Validating installation"
  local task_idx="$TASK_INDEX"
  local validation_output
  validation_output=$(printf '%s\n' "$validation_script" | remote_exec 'bash -s' 2>&1) || true
  printf '%s\n' "$validation_output" >>"$LOG_FILE"

  # Parse and display results in live logs
  local errors=0 warnings=0
  while IFS= read -r line; do
    case "$line" in
      FAIL:*)
        add_subtask_log "$line" "$CLR_RED"
        ((errors++))
        ;;
      WARN:*)
        add_subtask_log "$line" "$CLR_YELLOW"
        ((warnings++))
        ;;
    esac
  done <<<"$validation_output"

  # Update task with final status
  if ((errors > 0)); then
    complete_task "$task_idx" "${TREE_BRANCH} Validation: ${CLR_RED}${errors} error(s)${CLR_RESET}, ${CLR_YELLOW}${warnings} warning(s)${CLR_RESET}" "error"
    log_error "Installation validation failed with $errors error(s)"
  elif ((warnings > 0)); then
    complete_task "$task_idx" "${TREE_BRANCH} Validation passed with ${CLR_YELLOW}${warnings} warning(s)${CLR_RESET}" "warning"
  else
    complete_task "$task_idx" "${TREE_BRANCH} Validation passed"
  fi
}

# Finalizes VM by powering it off and waiting for QEMU to exit.
# Uses SIGTERM to QEMU process for ACPI shutdown (SSH is disabled after hardening)
finalize_vm() {
  # Send SIGTERM to QEMU for graceful ACPI shutdown
  # This is more reliable than SSH after hardening disables password auth
  (
    if kill -0 "$QEMU_PID" 2>/dev/null; then
      kill -TERM "$QEMU_PID" 2>/dev/null || true
    fi
  ) &
  show_progress "$!" "Powering off the VM"

  # Wait for QEMU to exit
  (
    timeout="${VM_SHUTDOWN_TIMEOUT:-120}"
    wait_interval="${PROCESS_KILL_WAIT:-1}"
    elapsed=0
    while ((elapsed < timeout)); do
      if ! kill -0 "$QEMU_PID" 2>/dev/null; then
        exit 0
      fi
      sleep "$wait_interval"
      ((elapsed += wait_interval))
    done
    exit 1
  ) &
  local wait_pid="$!"

  show_progress "$wait_pid" "Waiting for QEMU process to exit" "QEMU process exited"
  local exit_code="$?"
  if [[ $exit_code -ne 0 ]]; then
    log_warn "QEMU process did not exit cleanly within 120 seconds"
    # Force kill if still running
    kill -9 "$QEMU_PID" 2>/dev/null || true
  fi
}

# Main configuration function

# Main entry point for post-install Proxmox configuration via SSH.
# Orchestrates all configuration steps with parallel execution where safe.
# Uses batch package installation and parallel config groups for speed.
configure_proxmox_via_ssh() {
  log_info "Starting Proxmox configuration via SSH"

  _phase_base_configuration || {
    log_error "Base configuration failed"
    return 1
  }
  _phase_storage_configuration || {
    log_error "Storage configuration failed"
    return 1
  }
  _phase_security_configuration || {
    log_error "Security configuration failed"
    return 1
  }
  _phase_monitoring_tools || {
    log_warn "Monitoring tools configuration had issues"
    # Non-fatal: continue with installation
  }
  _phase_ssl_api || {
    log_warn "SSL/API configuration had issues"
    # Non-fatal: continue with installation
  }
  _phase_finalization || {
    log_error "Finalization failed"
    return 1
  }
}
# shellcheck shell=bash
# Configuration phases for Proxmox post-install
# Broken out for maintainability and testability

# PHASE 1: Base Configuration (sequential then parallel)
# Must run first - sets up admin user and base system
_phase_base_configuration() {
  make_templates || {
    log_error "make_templates failed"
    return 1
  }
  configure_admin_user || {
    log_error "configure_admin_user failed"
    return 1
  }
  configure_base_system || {
    log_error "configure_base_system failed"
    return 1
  }

  # Shell and system services have no inter-dependencies - run in parallel
  # configure_shell: Oh-My-Zsh, plugins (operates on user home directory)
  # configure_system_services: chrony, governors, limits (operates on system configs)
  run_parallel_group "Configuring shell & services" "Shell & services configured" \
    configure_shell \
    configure_system_services
}

# PHASE 2: Storage Configuration (LVM parallel with ZFS arc, then sequential ZFS chain)
_phase_storage_configuration() {
  # LVM and ZFS arc can run in parallel (no dependencies, non-critical)
  # run_parallel_group properly suppresses progress output (>/dev/null) - no wasted calls
  # log_info inside functions still writes to $LOG_FILE
  if [[ -n $BOOT_DISK ]]; then
    # LVM operates on boot partition, arc sets kernel params - no shared resources
    run_parallel_group "Configuring LVM & ZFS memory" "LVM & ZFS memory configured" \
      configure_lvm_storage \
      configure_zfs_arc
  else
    # Subshell catches exit 1 from remote_run, making failure non-fatal
    # Note: remote_run calls exit 1, not return 1, so || pattern needs subshell
    (configure_zfs_arc) || log_warn "configure_zfs_arc failed"
  fi

  # ZFS pool is critical - must succeed for storage to work
  configure_zfs_pool || {
    log_error "configure_zfs_pool failed"
    return 1
  }

  # These depend on pool existing (must run after pool)
  # Subshell catches exit 1 from remote_run, making failures non-fatal
  (configure_zfs_cachefile) || log_warn "configure_zfs_cachefile failed"
  (configure_zfs_scrub) || log_warn "configure_zfs_scrub failed"

  # Update initramfs to include ZFS cachefile changes (prevents "cachefile import failed" on boot)
  (remote_run "Updating initramfs" "update-initramfs -u -k all") || log_warn "update-initramfs failed"
}

# PHASE 3: Security Configuration (parallel after batch install)
_phase_security_configuration() {
  # Batch install security & optional packages first
  batch_install_packages

  # Tailscale (needs package installed, needed for firewall rules)
  configure_tailscale

  # Firewall next (depends on tailscale for rule generation)
  configure_firewall

  # Parallel security configuration - failures are fatal
  if ! run_parallel_group "Configuring security" "Security features configured" \
    configure_apparmor \
    configure_fail2ban \
    configure_auditd \
    configure_aide \
    configure_chkrootkit \
    configure_lynis \
    configure_needrestart; then
    log_error "Security configuration failed - aborting installation"
    print_error "Security hardening failed. Check $LOG_FILE for details."
    return 1
  fi
}

# PHASE 4: Monitoring & Tools (parallel where possible)
_phase_monitoring_tools() {
  # Special installers (non-apt) - run in background with proper error tracking
  # NOTE: Must call directly (not via $()) to keep process as child of main shell
  local netdata_pid yazi_pid
  start_async_feature "netdata" "INSTALL_NETDATA"
  netdata_pid="$REPLY"
  start_async_feature "yazi" "INSTALL_YAZI"
  yazi_pid="$REPLY"

  # Parallel config for apt-installed tools (packages already installed by batch)
  run_parallel_group "Configuring tools" "Tools configured" \
    configure_promtail \
    configure_vnstat \
    configure_ringbuffer \
    configure_nvim \
    configure_postfix

  # Wait for special installers and check results
  wait_async_feature "netdata" "$netdata_pid"
  wait_async_feature "yazi" "$yazi_pid"
}

# PHASE 5: SSL & API Configuration (parallel - independent operations)
_phase_ssl_api() {
  # SSL certificate and API token creation are independent - run in parallel
  # Failures logged but not fatal (user can configure manually post-install)
  if ! run_parallel_group "Configuring SSL & API" "SSL & API configured" \
    configure_ssl \
    configure_api_token; then
    log_warn "SSL/API configuration had failures - check $LOG_FILE for details"
  fi
}

# PHASE 6: Validation & Finalization
_phase_finalization() {
  # Deploy SSH hardening config BEFORE validation (so validation can verify it)
  deploy_ssh_hardening_config || {
    log_error "deploy_ssh_hardening_config failed"
    return 1
  }

  # Validate installation (SSH config file now has hardened settings)
  # Non-fatal: continue even if validation has warnings
  validate_installation || { log_warn "validate_installation reported issues"; }

  # Configure EFI fallback boot path (required for QEMU installs without NVRAM persistence)
  # Must run BEFORE cleanup which unmounts /boot/efi
  # Subshell catches exit 1 from remote_run, making failure non-fatal
  (configure_efi_fallback_boot) || log_warn "configure_efi_fallback_boot failed"

  # Clean up installation logs for fresh first boot
  (cleanup_installation_logs) || log_warn "cleanup_installation_logs failed"

  # Restart SSH as the LAST operation - after this, password auth is disabled
  restart_ssh_service || { log_warn "restart_ssh_service failed"; }

  # Power off VM - SSH no longer available, use QEMU ACPI shutdown
  finalize_vm || { log_warn "finalize_vm did not complete cleanly"; }
}
# shellcheck shell=bash
# Completion screen - shows credentials and handles reboot

_render_completion_screen() {
  local output=""
  local banner_output

  # Capture banner output
  banner_output=$(show_banner)

  # Start output with banner
  output+="${banner_output}\n\n"

  # Success header (wizard step continuation style)
  output+="$(format_wizard_header "Installation Complete")\n\n"

  # Warning to save credentials
  output+="  ${CLR_YELLOW}⚠ SAVE THESE CREDENTIALS${CLR_RESET}\n\n"

  # Helper to add field (wizard style)
  _cred_field() {
    local label="$1" value="$2" note="${3:-}"
    if [[ -n $label ]]; then
      output+="  ${CLR_GRAY}${label}${CLR_RESET}${value}"
    else
      output+="                   ${value}"
    fi
    [[ -n $note ]] && output+=" ${CLR_GRAY}${note}${CLR_RESET}"
    output+="\n"
  }

  # System info
  _cred_field "Hostname         " "${CLR_CYAN}${PVE_HOSTNAME}.${DOMAIN_SUFFIX}${CLR_RESET}"
  output+="\n"

  # Admin credentials (SSH + Proxmox UI)
  _cred_field "Admin User       " "${CLR_CYAN}${ADMIN_USERNAME}${CLR_RESET}"
  _cred_field "Admin Password   " "${CLR_ORANGE}${ADMIN_PASSWORD}${CLR_RESET}" "(SSH + Proxmox UI)"
  output+="\n"

  # Root credentials (console/KVM only - SSH blocked)
  _cred_field "Root Password    " "${CLR_ORANGE}${NEW_ROOT_PASSWORD}${CLR_RESET}" "(console/KVM only)"
  output+="\n"

  # Determine access based on firewall mode
  local has_tailscale=""
  [[ -n $TAILSCALE_IP && $TAILSCALE_IP != "pending" && $TAILSCALE_IP != "not authenticated" ]] && has_tailscale="yes"

  case "${FIREWALL_MODE:-standard}" in
    stealth)
      if [[ $has_tailscale == "yes" ]]; then
        _cred_field "SSH              " "${CLR_CYAN}ssh ${ADMIN_USERNAME}@${TAILSCALE_IP}${CLR_RESET}" "(Tailscale)"
        _cred_field "Web UI           " "${CLR_CYAN}https://${TAILSCALE_IP}${CLR_RESET}" "(Tailscale)"
      else
        _cred_field "SSH              " "${CLR_YELLOW}blocked${CLR_RESET}" "(stealth mode)"
        _cred_field "Web UI           " "${CLR_YELLOW}blocked${CLR_RESET}" "(stealth mode)"
      fi
      ;;
    strict)
      _cred_field "SSH              " "${CLR_CYAN}ssh ${ADMIN_USERNAME}@${MAIN_IPV4}${CLR_RESET}"
      if [[ $has_tailscale == "yes" ]]; then
        _cred_field "" "${CLR_CYAN}ssh ${ADMIN_USERNAME}@${TAILSCALE_IP}${CLR_RESET}" "(Tailscale)"
        _cred_field "Web UI           " "${CLR_CYAN}https://${TAILSCALE_IP}${CLR_RESET}" "(Tailscale)"
      else
        _cred_field "Web UI           " "${CLR_YELLOW}blocked${CLR_RESET}" "(strict mode)"
      fi
      ;;
    *)
      _cred_field "SSH              " "${CLR_CYAN}ssh ${ADMIN_USERNAME}@${MAIN_IPV4}${CLR_RESET}"
      [[ $has_tailscale == "yes" ]] && _cred_field "" "${CLR_CYAN}ssh ${ADMIN_USERNAME}@${TAILSCALE_IP}${CLR_RESET}" "(Tailscale)"
      _cred_field "Web UI           " "${CLR_CYAN}https://${MAIN_IPV4}${CLR_RESET}"
      [[ $has_tailscale == "yes" ]] && _cred_field "" "${CLR_CYAN}https://${TAILSCALE_IP}${CLR_RESET}" "(Tailscale)"
      ;;
  esac

  # API Token (if created) - uses centralized path constant from 003-init.sh
  if [[ -f "$_TEMP_API_TOKEN_FILE" ]]; then
    # Validate file contains only expected API token variables (defense in depth)
    if grep -qvE '^API_TOKEN_(VALUE|ID|NAME)=' "$_TEMP_API_TOKEN_FILE"; then
      log_error "API token file contains unexpected content"
    else
      # shellcheck disable=SC1090,SC1091
      source "$_TEMP_API_TOKEN_FILE"
    fi

    if [[ -n $API_TOKEN_VALUE ]]; then
      output+="\n"
      _cred_field "API Token ID     " "${CLR_CYAN}${API_TOKEN_ID}${CLR_RESET}"
      _cred_field "API Secret       " "${CLR_ORANGE}${API_TOKEN_VALUE}${CLR_RESET}"
    fi
  fi

  output+="\n"

  # Centered footer
  local footer_text="${CLR_GRAY}[${CLR_ORANGE}Enter${CLR_GRAY}] reboot  [${CLR_ORANGE}Q${CLR_GRAY}] quit without reboot${CLR_RESET}"
  output+="$(_wiz_center "$footer_text")"

  # Clear and render
  _wiz_clear
  printf '%b' "$output"
}

# Handle completion screen input (Enter=reboot, Q=exit)
_completion_screen_input() {
  while true; do
    _render_completion_screen

    # Read single keypress
    local key
    IFS= read -rsn1 key

    case "$key" in
      q | Q)
        printf '\n'
        print_info "Exiting without reboot."
        printf '\n'
        print_info "You can reboot manually when ready with: ${CLR_CYAN}reboot${CLR_RESET}"
        exit 0
        ;;
      "")
        # Enter pressed - reboot
        printf '\n'
        print_info "Rebooting the system..."
        if ! reboot; then
          log_error "Failed to reboot - system may require manual restart"
          print_error "Failed to reboot the system"
          exit 1
        fi
        ;;
    esac
  done
}

# Finishes live installation display and shows completion screen.
# Prompts user to reboot or exit without reboot.
reboot_to_main_os() {
  # Finish live installation display
  finish_live_installation

  # Show completion screen with wizard style
  _completion_screen_input
}
# shellcheck shell=bash
# Main orchestrator - installation flow

# Main execution flow
log_info "==================== Qoxi Automated Installer v${VERSION} ===================="
log_debug "QEMU_RAM_OVERRIDE=$QEMU_RAM_OVERRIDE QEMU_CORES_OVERRIDE=$QEMU_CORES_OVERRIDE"
log_debug "PVE_REPO_TYPE=${PVE_REPO_TYPE:-no-subscription} SSL_TYPE=${SSL_TYPE:-self-signed}"

metrics_start
log_info "Step: collect_system_info"
show_banner_animated_start 0.1

# Create temporary file for sharing variables between processes
SYSTEM_INFO_CACHE=$(mktemp) || {
  log_error "Failed to create temp file"
  exit 1
}
register_temp_file "$SYSTEM_INFO_CACHE"

# Run system checks and prefetch Proxmox ISO info in background job
{
  collect_system_info
  log_info "Step: prefetch_proxmox_iso_info"
  prefetch_proxmox_iso_info

  # Export system/network/ISO variables to temp file (atomic write to prevent partial data)
  declare -p | grep -E "^declare -[^ ]* (PREFLIGHT_|DRIVE_|INTERFACE_|CURRENT_INTERFACE|PREDICTABLE_NAME|DEFAULT_INTERFACE|AVAILABLE_|MAC_ADDRESS|MAIN_IPV|IPV6_|FIRST_IPV6_|_ISO_|_CHECKSUM_|WIZ_TIMEZONES|WIZ_COUNTRIES|TZ_TO_COUNTRY|DETECTED_POOLS)" >"${SYSTEM_INFO_CACHE}.tmp" \
    && mv "${SYSTEM_INFO_CACHE}.tmp" "$SYSTEM_INFO_CACHE"
} >/dev/null 2>&1 &

# Wait for background tasks to complete
wait "$!"

# Reset command caches (new packages installed in subshell)
cmd_cache_clear

# Verify required packages are available
_missing_cmds=()
for _cmd in gum jq aria2c curl; do
  command -v "$_cmd" &>/dev/null || _missing_cmds+=("$_cmd")
done
if [[ ${#_missing_cmds[@]} -gt 0 ]]; then
  log_error "Required packages not installed: ${_missing_cmds[*]}"
  print_error "Required packages not installed: ${_missing_cmds[*]}"
  exit 1
fi
unset _missing_cmds _cmd

# Stop animation and show static banner with system info
show_banner_animated_stop

# Import variables from background job
if [[ -s $SYSTEM_INFO_CACHE ]]; then
  # Validate file contains only declare statements (defense in depth)
  if grep -qvE '^declare -' "$SYSTEM_INFO_CACHE"; then
    log_error "SYSTEM_INFO_CACHE contains invalid content, skipping import"
  else
    # shellcheck disable=SC1090
    source "$SYSTEM_INFO_CACHE"
  fi
  rm -f "$SYSTEM_INFO_CACHE"
fi

log_info "Step: show_system_status"
show_system_status
log_metric "system_info"

# Show interactive configuration editor (replaces get_system_inputs)
log_info "Step: show_gum_config_editor"
show_gum_config_editor
log_metric "config_wizard"

# Start live installation display
start_live_installation

log_info "Step: prepare_packages"
prepare_packages
log_metric "packages"

# Download ISO and generate TOML in parallel (no shared resources)
log_info "Step: prepare_iso_and_toml (parallel)"
if ! run_parallel_group "Preparing ISO & TOML" "ISO & TOML ready" \
  _parallel_download_iso \
  _parallel_make_toml; then
  log_error "ISO/TOML preparation failed - check $LOG_FILE for details"
  exit 1
fi
log_metric "iso_download"

log_info "Step: make_autoinstall_iso"
make_autoinstall_iso
log_metric "autoinstall_prep"

log_info "Step: wipe_installation_disks"
run_with_progress "Wiping disks" "Disks wiped" wipe_installation_disks
log_metric "disk_wipe"

log_info "Step: install_proxmox"
install_proxmox
log_metric "proxmox_install"

log_info "Step: boot_proxmox_with_port_forwarding"
boot_proxmox_with_port_forwarding || {
  log_error "Failed to boot Proxmox with port forwarding"
  exit 1
}
log_metric "qemu_boot"

log_info "Step: configure_proxmox_via_ssh"
configure_proxmox_via_ssh || {
  log_error "configure_proxmox_via_ssh failed"
  exit 1
}
log_metric "system_config"

# Log final metrics
metrics_finish

# Mark installation as completed (disables error handler message)
INSTALL_COMPLETED=true

# Reboot to the main OS
log_info "Step: reboot_to_main_os"
reboot_to_main_os
