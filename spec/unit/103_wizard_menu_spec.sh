# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
# =============================================================================
# Tests for 103-wizard-menu.sh - Menu Rendering and Display Values
# =============================================================================
# Note: SC2034 disabled - variables used by ShellSpec assertions
#       SC2154 disabled - variables set by mocks

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/ui_mocks.sh")"

# =============================================================================
# Global constants needed by the module
# =============================================================================
TERM_WIDTH=80

# Hex colors for gum
HEX_RED="#ff0000"
HEX_CYAN="#00b1ff"
HEX_YELLOW="#ffff00"
HEX_ORANGE="#ff8700"
HEX_GRAY="#585858"
HEX_WHITE="#ffffff"
HEX_NONE="7"

# =============================================================================
# Mocks for external dependencies
# =============================================================================

# Mock tput for terminal operations
tput() {
  case "$1" in
    cols) echo "80" ;;
    lines) echo "24" ;;
    cuu) : ;;
    smcup | rmcup | cnorm | civis) : ;;
    *) : ;;
  esac
}

# Mock show_banner
show_banner() { echo "=== BANNER ==="; }

# Mock get_iso_version
get_iso_version() { echo "${1:-8.3-1}"; }

# Mock _wiz_fmt (from 101-wizard-ui.sh)
_wiz_fmt() {
  local value="$1"
  local placeholder="${2:-→ set value}"
  if [[ -n $value ]]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "${CLR_GRAY}${placeholder}${CLR_RESET}"
  fi
}

# Mock _wiz_center (from 102-wizard-nav.sh)
_wiz_center() {
  local text="$1"
  echo "$text"
}

# Mock _wiz_render_nav (from 102-wizard-nav.sh)
_wiz_render_nav() {
  echo "[NAV HEADER]"
}

# Mock _wiz_clear (from 101-wizard-ui.sh)
_wiz_clear() {
  printf '\033[H\033[J'
}

# Screen definitions (from 102-wizard-nav.sh)
WIZ_SCREENS=("Basic" "Proxmox" "Network" "Storage" "Services" "Access")
WIZ_CURRENT_SCREEN=0

# Reset wizard state
reset_wizard_state() {
  WIZ_CURRENT_SCREEN=0
  _WIZ_FIELD_COUNT=0
  _WIZ_FIELD_MAP=()

  # Reset display vars
  _DSP_PASS=""
  _DSP_HOSTNAME=""
  _DSP_IPV6=""
  _DSP_TAILSCALE=""
  _DSP_SSL=""
  _DSP_REPO=""
  _DSP_BRIDGE=""
  _DSP_ZFS=""
  _DSP_ARC=""
  _DSP_SHELL=""
  _DSP_POWER=""
  _DSP_SECURITY=""
  _DSP_MONITORING=""
  _DSP_TOOLS=""
  _DSP_API=""
  _DSP_SSH=""
  _DSP_ADMIN_USER=""
  _DSP_ADMIN_PASS=""
  _DSP_FIREWALL=""
  _DSP_ISO=""
  _DSP_MTU=""
  _DSP_BOOT=""
  _DSP_POOL=""

  # Reset config vars
  PVE_HOSTNAME=""
  DOMAIN_SUFFIX=""
  EMAIL=""
  NEW_ROOT_PASSWORD=""
  ADMIN_USERNAME=""
  ADMIN_PASSWORD=""
  TIMEZONE=""
  KEYBOARD=""
  COUNTRY=""
  PROXMOX_ISO_VERSION=""
  PVE_REPO_TYPE=""
  INTERFACE_NAME=""
  INTERFACE_COUNT=1
  BRIDGE_MODE=""
  BRIDGE_MTU=""
  PRIVATE_SUBNET=""
  IPV6_MODE=""
  MAIN_IPV6=""
  IPV6_GATEWAY=""
  ZFS_RAID=""
  ZFS_ARC_MODE=""
  ZFS_POOL_DISKS=()
  SHELL_TYPE=""
  CPU_GOVERNOR=""
  SSH_PUBLIC_KEY=""
  INSTALL_TAILSCALE=""
  SSL_TYPE=""
  FIREWALL_MODE=""
  INSTALL_FIREWALL=""
  BOOT_DISK=""
  DRIVES=()
  DRIVE_MODELS=()
  DRIVE_COUNT=1

  # Feature flags
  INSTALL_APPARMOR=""
  INSTALL_AUDITD=""
  INSTALL_AIDE=""
  INSTALL_CHKROOTKIT=""
  INSTALL_LYNIS=""
  INSTALL_NEEDRESTART=""
  INSTALL_VNSTAT=""
  INSTALL_NETDATA=""
  INSTALL_PROMTAIL=""
  INSTALL_YAZI=""
  INSTALL_NVIM=""
  INSTALL_RINGBUFFER=""
  INSTALL_API_TOKEN=""
  API_TOKEN_NAME=""
}

Describe "103-wizard-menu.sh"
  Include "$SCRIPTS_DIR/103-wizard-menu.sh"

  # ===========================================================================
  # _wiz_config_complete()
  # ===========================================================================
  Describe "_wiz_config_complete()"
    BeforeEach 'reset_wizard_state'

    Describe "when all fields are set"
      setup_complete_config() {
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="password123"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="adminpass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE="no-subscription"
        INTERFACE_NAME="eth0"
        BRIDGE_MODE="external"
        PRIVATE_SUBNET="10.0.0.0/24"
        IPV6_MODE="disabled"
        ZFS_RAID="single"
        ZFS_ARC_MODE="balanced"
        SHELL_TYPE="zsh"
        CPU_GOVERNOR="performance"
        SSH_PUBLIC_KEY="ssh-rsa AAAA..."
        ZFS_POOL_DISKS=("/dev/sda")
        INSTALL_TAILSCALE="yes"
        FIREWALL_MODE="standard"
      }

      BeforeEach 'setup_complete_config'

      It "returns success"
        When call _wiz_config_complete
        The status should be success
      End
    End

    Describe "when required fields are missing"
      It "returns failure when hostname is empty"
        PVE_HOSTNAME=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when domain suffix is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when email is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when pool disks is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="pass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE="no-subscription"
        INTERFACE_NAME="eth0"
        BRIDGE_MODE="external"
        PRIVATE_SUBNET="10.0.0.0/24"
        IPV6_MODE="disabled"
        ZFS_RAID="single"
        ZFS_ARC_MODE="balanced"
        SHELL_TYPE="zsh"
        CPU_GOVERNOR="performance"
        SSH_PUBLIC_KEY="ssh-rsa AAAA..."
        ZFS_POOL_DISKS=()
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when root password is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when admin username is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when admin password is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when timezone is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="pass"
        TIMEZONE=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when keyboard is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="pass"
        TIMEZONE="UTC"
        KEYBOARD=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when country is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="pass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when ISO version is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="pass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when repo type is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="pass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when interface name is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="pass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE="no-subscription"
        INTERFACE_NAME=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when bridge mode is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="pass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE="no-subscription"
        INTERFACE_NAME="eth0"
        BRIDGE_MODE=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when private subnet is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="pass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE="no-subscription"
        INTERFACE_NAME="eth0"
        BRIDGE_MODE="external"
        PRIVATE_SUBNET=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when IPv6 mode is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="pass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE="no-subscription"
        INTERFACE_NAME="eth0"
        BRIDGE_MODE="external"
        PRIVATE_SUBNET="10.0.0.0/24"
        IPV6_MODE=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when ZFS RAID is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="pass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE="no-subscription"
        INTERFACE_NAME="eth0"
        BRIDGE_MODE="external"
        PRIVATE_SUBNET="10.0.0.0/24"
        IPV6_MODE="disabled"
        ZFS_RAID=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when ZFS ARC mode is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="pass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE="no-subscription"
        INTERFACE_NAME="eth0"
        BRIDGE_MODE="external"
        PRIVATE_SUBNET="10.0.0.0/24"
        IPV6_MODE="disabled"
        ZFS_RAID="single"
        ZFS_ARC_MODE=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when shell type is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="pass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE="no-subscription"
        INTERFACE_NAME="eth0"
        BRIDGE_MODE="external"
        PRIVATE_SUBNET="10.0.0.0/24"
        IPV6_MODE="disabled"
        ZFS_RAID="single"
        ZFS_ARC_MODE="balanced"
        SHELL_TYPE=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when CPU governor is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="pass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE="no-subscription"
        INTERFACE_NAME="eth0"
        BRIDGE_MODE="external"
        PRIVATE_SUBNET="10.0.0.0/24"
        IPV6_MODE="disabled"
        ZFS_RAID="single"
        ZFS_ARC_MODE="balanced"
        SHELL_TYPE="zsh"
        CPU_GOVERNOR=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns failure when SSH public key is empty"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="pass"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="pass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE="no-subscription"
        INTERFACE_NAME="eth0"
        BRIDGE_MODE="external"
        PRIVATE_SUBNET="10.0.0.0/24"
        IPV6_MODE="disabled"
        ZFS_RAID="single"
        ZFS_ARC_MODE="balanced"
        SHELL_TYPE="zsh"
        CPU_GOVERNOR="performance"
        SSH_PUBLIC_KEY=""
        When call _wiz_config_complete
        The status should be failure
      End
    End

    Describe "SSL validation"
      setup_no_tailscale() {
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="password123"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="adminpass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE="no-subscription"
        INTERFACE_NAME="eth0"
        BRIDGE_MODE="external"
        PRIVATE_SUBNET="10.0.0.0/24"
        IPV6_MODE="disabled"
        ZFS_RAID="single"
        ZFS_ARC_MODE="balanced"
        SHELL_TYPE="zsh"
        CPU_GOVERNOR="performance"
        SSH_PUBLIC_KEY="ssh-rsa AAAA..."
        ZFS_POOL_DISKS=("/dev/sda")
        INSTALL_TAILSCALE="no"
        FIREWALL_MODE="standard"
      }

      BeforeEach 'setup_no_tailscale'

      It "returns failure when Tailscale disabled and SSL not set"
        SSL_TYPE=""
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns success when Tailscale disabled and SSL is set"
        SSL_TYPE="self-signed"
        When call _wiz_config_complete
        The status should be success
      End
    End

    Describe "Stealth firewall validation"
      setup_stealth_firewall() {
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="password123"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="adminpass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE="no-subscription"
        INTERFACE_NAME="eth0"
        BRIDGE_MODE="external"
        PRIVATE_SUBNET="10.0.0.0/24"
        IPV6_MODE="disabled"
        ZFS_RAID="single"
        ZFS_ARC_MODE="balanced"
        SHELL_TYPE="zsh"
        CPU_GOVERNOR="performance"
        SSH_PUBLIC_KEY="ssh-rsa AAAA..."
        ZFS_POOL_DISKS=("/dev/sda")
        SSL_TYPE="self-signed"
        FIREWALL_MODE="stealth"
        INSTALL_TAILSCALE="no"
      }

      BeforeEach 'setup_stealth_firewall'

      It "returns failure when stealth firewall without Tailscale"
        When call _wiz_config_complete
        The status should be failure
      End

      It "returns success when stealth firewall with Tailscale"
        INSTALL_TAILSCALE="yes"
        When call _wiz_config_complete
        The status should be success
      End
    End
  End

  # ===========================================================================
  # _wiz_build_display_values()
  # ===========================================================================
  Describe "_wiz_build_display_values()"
    BeforeEach 'reset_wizard_state'

    Describe "password display"
      It "shows masked password when set"
        NEW_ROOT_PASSWORD="secret123"
        When call _wiz_build_display_values
        The variable _DSP_PASS should equal "********"
      End

      It "shows empty when password not set"
        NEW_ROOT_PASSWORD=""
        When call _wiz_build_display_values
        The variable _DSP_PASS should equal ""
      End
    End

    Describe "hostname display"
      It "shows full hostname when set"
        PVE_HOSTNAME="server1"
        DOMAIN_SUFFIX="example.com"
        When call _wiz_build_display_values
        The variable _DSP_HOSTNAME should equal "server1.example.com"
      End

      It "shows empty when hostname not set"
        PVE_HOSTNAME=""
        When call _wiz_build_display_values
        The variable _DSP_HOSTNAME should equal ""
      End
    End

    Describe "IPv6 display"
      It "shows Auto for auto mode"
        IPV6_MODE="auto"
        When call _wiz_build_display_values
        The variable _DSP_IPV6 should equal "Auto"
      End

      It "shows Manual with address for manual mode"
        IPV6_MODE="manual"
        MAIN_IPV6="2001:db8::1"
        IPV6_GATEWAY="2001:db8::ff"
        When call _wiz_build_display_values
        The variable _DSP_IPV6 should include "Manual"
        The variable _DSP_IPV6 should include "2001:db8::1"
      End

      It "shows Disabled for disabled mode"
        IPV6_MODE="disabled"
        When call _wiz_build_display_values
        The variable _DSP_IPV6 should equal "Disabled"
      End
    End

    Describe "Tailscale display"
      It "shows Enabled + Stealth when yes"
        INSTALL_TAILSCALE="yes"
        When call _wiz_build_display_values
        The variable _DSP_TAILSCALE should equal "Enabled + Stealth"
      End

      It "shows Disabled when no"
        INSTALL_TAILSCALE="no"
        When call _wiz_build_display_values
        The variable _DSP_TAILSCALE should equal "Disabled"
      End
    End

    Describe "SSL display"
      It "shows Self-signed for self-signed"
        SSL_TYPE="self-signed"
        When call _wiz_build_display_values
        The variable _DSP_SSL should equal "Self-signed"
      End

      It "shows Let's Encrypt for letsencrypt"
        SSL_TYPE="letsencrypt"
        When call _wiz_build_display_values
        The variable _DSP_SSL should equal "Let's Encrypt"
      End
    End

    Describe "Repository display"
      It "shows friendly name for no-subscription"
        PVE_REPO_TYPE="no-subscription"
        When call _wiz_build_display_values
        The variable _DSP_REPO should equal "No-subscription (free)"
      End

      It "shows Enterprise for enterprise"
        PVE_REPO_TYPE="enterprise"
        When call _wiz_build_display_values
        The variable _DSP_REPO should equal "Enterprise"
      End

      It "shows Test/Development for test"
        PVE_REPO_TYPE="test"
        When call _wiz_build_display_values
        The variable _DSP_REPO should equal "Test/Development"
      End
    End

    Describe "Bridge mode display"
      It "shows External bridge for external"
        BRIDGE_MODE="external"
        When call _wiz_build_display_values
        The variable _DSP_BRIDGE should equal "External bridge"
      End

      It "shows Internal NAT for internal"
        BRIDGE_MODE="internal"
        When call _wiz_build_display_values
        The variable _DSP_BRIDGE should equal "Internal NAT"
      End

      It "shows Both for both"
        BRIDGE_MODE="both"
        When call _wiz_build_display_values
        The variable _DSP_BRIDGE should equal "Both"
      End
    End

    Describe "ZFS mode display"
      It "shows Single disk for single"
        ZFS_RAID="single"
        When call _wiz_build_display_values
        The variable _DSP_ZFS should equal "Single disk"
      End

      It "shows RAID-0 for raid0"
        ZFS_RAID="raid0"
        When call _wiz_build_display_values
        The variable _DSP_ZFS should equal "RAID-0 (striped)"
      End

      It "shows RAID-1 for raid1"
        ZFS_RAID="raid1"
        When call _wiz_build_display_values
        The variable _DSP_ZFS should equal "RAID-1 (mirror)"
      End

      It "shows RAID-Z1 for raidz1"
        ZFS_RAID="raidz1"
        When call _wiz_build_display_values
        The variable _DSP_ZFS should equal "RAID-Z1 (parity)"
      End

      It "shows RAID-Z2 for raidz2"
        ZFS_RAID="raidz2"
        When call _wiz_build_display_values
        The variable _DSP_ZFS should equal "RAID-Z2 (double parity)"
      End

      It "shows RAID-10 for raid10"
        ZFS_RAID="raid10"
        When call _wiz_build_display_values
        The variable _DSP_ZFS should equal "RAID-10 (striped mirrors)"
      End
    End

    Describe "ZFS ARC display"
      It "shows VM-focused for vm-focused"
        ZFS_ARC_MODE="vm-focused"
        When call _wiz_build_display_values
        The variable _DSP_ARC should equal "VM-focused (4GB)"
      End

      It "shows Balanced for balanced"
        ZFS_ARC_MODE="balanced"
        When call _wiz_build_display_values
        The variable _DSP_ARC should equal "Balanced (25-40%)"
      End

      It "shows Storage-focused for storage-focused"
        ZFS_ARC_MODE="storage-focused"
        When call _wiz_build_display_values
        The variable _DSP_ARC should equal "Storage-focused (50%)"
      End
    End

    Describe "Shell display"
      It "shows ZSH for zsh"
        SHELL_TYPE="zsh"
        When call _wiz_build_display_values
        The variable _DSP_SHELL should equal "ZSH"
      End

      It "shows Bash for bash"
        SHELL_TYPE="bash"
        When call _wiz_build_display_values
        The variable _DSP_SHELL should equal "Bash"
      End
    End

    Describe "Power profile display"
      It "shows Performance for performance"
        CPU_GOVERNOR="performance"
        When call _wiz_build_display_values
        The variable _DSP_POWER should equal "Performance"
      End

      It "shows Balanced for ondemand"
        CPU_GOVERNOR="ondemand"
        When call _wiz_build_display_values
        The variable _DSP_POWER should equal "Balanced"
      End

      It "shows Balanced for powersave"
        CPU_GOVERNOR="powersave"
        When call _wiz_build_display_values
        The variable _DSP_POWER should equal "Balanced"
      End

      It "shows Adaptive for schedutil"
        CPU_GOVERNOR="schedutil"
        When call _wiz_build_display_values
        The variable _DSP_POWER should equal "Adaptive"
      End

      It "shows Conservative for conservative"
        CPU_GOVERNOR="conservative"
        When call _wiz_build_display_values
        The variable _DSP_POWER should equal "Conservative"
      End
    End

    Describe "Security features display"
      It "shows none when no features enabled"
        When call _wiz_build_display_values
        The variable _DSP_SECURITY should equal "none"
      End

      It "shows enabled features"
        INSTALL_APPARMOR="yes"
        INSTALL_AUDITD="yes"
        When call _wiz_build_display_values
        The variable _DSP_SECURITY should include "apparmor"
        The variable _DSP_SECURITY should include "auditd"
      End

      It "shows all security features when enabled"
        INSTALL_APPARMOR="yes"
        INSTALL_AUDITD="yes"
        INSTALL_AIDE="yes"
        INSTALL_CHKROOTKIT="yes"
        INSTALL_LYNIS="yes"
        INSTALL_NEEDRESTART="yes"
        When call _wiz_build_display_values
        The variable _DSP_SECURITY should include "apparmor"
        The variable _DSP_SECURITY should include "auditd"
        The variable _DSP_SECURITY should include "aide"
        The variable _DSP_SECURITY should include "chkrootkit"
        The variable _DSP_SECURITY should include "lynis"
        The variable _DSP_SECURITY should include "needrestart"
      End
    End

    Describe "Monitoring features display"
      It "shows none when no features enabled"
        When call _wiz_build_display_values
        The variable _DSP_MONITORING should equal "none"
      End

      It "shows enabled monitoring features"
        INSTALL_VNSTAT="yes"
        INSTALL_NETDATA="yes"
        INSTALL_PROMTAIL="yes"
        When call _wiz_build_display_values
        The variable _DSP_MONITORING should include "vnstat"
        The variable _DSP_MONITORING should include "netdata"
        The variable _DSP_MONITORING should include "promtail"
      End
    End

    Describe "Tools display"
      It "shows none when no tools enabled"
        When call _wiz_build_display_values
        The variable _DSP_TOOLS should equal "none"
      End

      It "shows enabled tools"
        INSTALL_YAZI="yes"
        INSTALL_NVIM="yes"
        INSTALL_RINGBUFFER="yes"
        When call _wiz_build_display_values
        The variable _DSP_TOOLS should include "yazi"
        The variable _DSP_TOOLS should include "nvim"
        The variable _DSP_TOOLS should include "ringbuffer"
      End
    End

    Describe "API Token display"
      It "shows Yes with token name when enabled"
        INSTALL_API_TOKEN="yes"
        API_TOKEN_NAME="automation"
        When call _wiz_build_display_values
        The variable _DSP_API should equal "Yes (automation)"
      End

      It "shows No when disabled"
        INSTALL_API_TOKEN="no"
        When call _wiz_build_display_values
        The variable _DSP_API should equal "No"
      End
    End

    Describe "SSH Key display"
      It "shows truncated key when set"
        SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC..."
        When call _wiz_build_display_values
        The variable _DSP_SSH should include "..."
        The variable _DSP_SSH should include "ssh-rsa"
      End

      It "shows empty when not set"
        SSH_PUBLIC_KEY=""
        When call _wiz_build_display_values
        The variable _DSP_SSH should equal ""
      End
    End

    Describe "Admin user display"
      It "shows username when set"
        ADMIN_USERNAME="myadmin"
        When call _wiz_build_display_values
        The variable _DSP_ADMIN_USER should equal "myadmin"
      End

      It "shows masked password when set"
        ADMIN_PASSWORD="secret"
        When call _wiz_build_display_values
        The variable _DSP_ADMIN_PASS should equal "********"
      End
    End

    Describe "Firewall display"
      It "shows Stealth for stealth mode"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="stealth"
        When call _wiz_build_display_values
        The variable _DSP_FIREWALL should equal "Stealth (Tailscale only)"
      End

      It "shows Strict for strict mode"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="strict"
        When call _wiz_build_display_values
        The variable _DSP_FIREWALL should equal "Strict (SSH only)"
      End

      It "shows Standard for standard mode"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="standard"
        When call _wiz_build_display_values
        The variable _DSP_FIREWALL should equal "Standard (SSH + Web UI)"
      End

      It "shows Disabled when firewall disabled"
        INSTALL_FIREWALL="no"
        When call _wiz_build_display_values
        The variable _DSP_FIREWALL should equal "Disabled"
      End
    End

    Describe "MTU display"
      It "shows jumbo suffix for 9000"
        BRIDGE_MTU="9000"
        When call _wiz_build_display_values
        The variable _DSP_MTU should equal "9000 (jumbo)"
      End

      It "shows raw value for non-9000"
        BRIDGE_MTU="1500"
        When call _wiz_build_display_values
        The variable _DSP_MTU should equal "1500"
      End

      It "defaults to 9000 (jumbo) when not set"
        BRIDGE_MTU=""
        When call _wiz_build_display_values
        The variable _DSP_MTU should equal "9000 (jumbo)"
      End
    End

    Describe "Boot disk display"
      It "shows All in pool when no boot disk"
        BOOT_DISK=""
        When call _wiz_build_display_values
        The variable _DSP_BOOT should equal "All in pool"
      End

      It "shows model name when boot disk matches"
        BOOT_DISK="/dev/sda"
        DRIVES=("/dev/sda" "/dev/sdb")
        DRIVE_MODELS=("Samsung 970" "WD Black")
        When call _wiz_build_display_values
        The variable _DSP_BOOT should equal "Samsung 970"
      End
    End

    Describe "Pool disks display"
      It "shows disk count"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb" "/dev/sdc")
        When call _wiz_build_display_values
        The variable _DSP_POOL should equal "3 disks"
      End

      It "shows 0 disks when empty"
        ZFS_POOL_DISKS=()
        When call _wiz_build_display_values
        The variable _DSP_POOL should equal "0 disks"
      End

      It "shows 1 disk correctly"
        ZFS_POOL_DISKS=("/dev/sda")
        When call _wiz_build_display_values
        The variable _DSP_POOL should equal "1 disks"
      End
    End

    Describe "ISO version display"
      It "shows ISO version when set"
        PROXMOX_ISO_VERSION="8.3-1"
        When call _wiz_build_display_values
        The variable _DSP_ISO should equal "8.3-1"
      End

      It "shows empty when not set"
        PROXMOX_ISO_VERSION=""
        When call _wiz_build_display_values
        The variable _DSP_ISO should equal ""
      End
    End

    Describe "Unknown/fallback values"
      It "uses raw value for unknown IPv6 mode"
        IPV6_MODE="custom"
        When call _wiz_build_display_values
        The variable _DSP_IPV6 should equal "custom"
      End

      It "uses raw value for unknown SSL type"
        SSL_TYPE="custom-ssl"
        When call _wiz_build_display_values
        The variable _DSP_SSL should equal "custom-ssl"
      End

      It "uses raw value for unknown repo type"
        PVE_REPO_TYPE="custom-repo"
        When call _wiz_build_display_values
        The variable _DSP_REPO should equal "custom-repo"
      End

      It "uses raw value for unknown bridge mode"
        BRIDGE_MODE="custom-bridge"
        When call _wiz_build_display_values
        The variable _DSP_BRIDGE should equal "custom-bridge"
      End

      It "uses raw value for unknown ZFS mode"
        ZFS_RAID="custom-raid"
        When call _wiz_build_display_values
        The variable _DSP_ZFS should equal "custom-raid"
      End

      It "uses raw value for unknown ZFS ARC mode"
        ZFS_ARC_MODE="custom-arc"
        When call _wiz_build_display_values
        The variable _DSP_ARC should equal "custom-arc"
      End

      It "uses raw value for unknown shell type"
        SHELL_TYPE="fish"
        When call _wiz_build_display_values
        The variable _DSP_SHELL should equal "fish"
      End

      It "uses raw value for unknown CPU governor"
        CPU_GOVERNOR="userspace"
        When call _wiz_build_display_values
        The variable _DSP_POWER should equal "userspace"
      End

      It "uses raw value for unknown firewall mode"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="custom-fw"
        When call _wiz_build_display_values
        The variable _DSP_FIREWALL should equal "custom-fw"
      End
    End

    Describe "Manual IPv6 without address"
      It "shows Manual when address not set"
        IPV6_MODE="manual"
        MAIN_IPV6=""
        When call _wiz_build_display_values
        The variable _DSP_IPV6 should equal "Manual"
      End
    End

    Describe "Boot disk with non-matching disk"
      It "shows All in pool when disk not in DRIVES array"
        BOOT_DISK="/dev/sdc"
        DRIVES=("/dev/sda" "/dev/sdb")
        DRIVE_MODELS=("Samsung 970" "WD Black")
        When call _wiz_build_display_values
        The variable _DSP_BOOT should equal "All in pool"
      End

      It "shows second disk model correctly"
        BOOT_DISK="/dev/sdb"
        DRIVES=("/dev/sda" "/dev/sdb")
        DRIVE_MODELS=("Samsung 970" "WD Black")
        When call _wiz_build_display_values
        The variable _DSP_BOOT should equal "WD Black"
      End
    End

    Describe "Empty/unset variable handling"
      It "handles empty hostname with set domain"
        PVE_HOSTNAME=""
        DOMAIN_SUFFIX="example.com"
        When call _wiz_build_display_values
        The variable _DSP_HOSTNAME should equal ""
      End

      It "handles set hostname with empty domain"
        PVE_HOSTNAME="server"
        DOMAIN_SUFFIX=""
        When call _wiz_build_display_values
        The variable _DSP_HOSTNAME should equal ""
      End

      It "handles empty Tailscale setting"
        INSTALL_TAILSCALE=""
        When call _wiz_build_display_values
        The variable _DSP_TAILSCALE should equal ""
      End

      It "handles empty SSL type"
        SSL_TYPE=""
        When call _wiz_build_display_values
        The variable _DSP_SSL should equal ""
      End

      It "handles empty API token setting"
        INSTALL_API_TOKEN=""
        When call _wiz_build_display_values
        The variable _DSP_API should equal ""
      End

      It "handles empty firewall setting"
        INSTALL_FIREWALL=""
        When call _wiz_build_display_values
        The variable _DSP_FIREWALL should equal ""
      End
    End
  End

  # ===========================================================================
  # _wiz_render_screen_content()
  # ===========================================================================
  Describe "_wiz_render_screen_content()"
    BeforeEach 'reset_wizard_state'

    # Need to set up _add_field as local for testing
    setup_add_field() {
      _WIZ_FIELD_MAP=()
      field_idx=0
      output=""
      _add_field() {
        local label="$1"
        local value="$2"
        local field_name="$3"
        _WIZ_FIELD_MAP+=("$field_name")
        output+="${label}|${field_name}\n"
        ((field_idx++))
      }
    }

    Describe "Basic screen (0)"
      BeforeEach 'setup_add_field'

      It "adds hostname field"
        _DSP_HOSTNAME="test.example.com"
        When call _wiz_render_screen_content 0 0
        The value "${_WIZ_FIELD_MAP[*]}" should include "hostname"
      End

      It "adds all basic fields"
        When call _wiz_render_screen_content 0 0
        The value "${_WIZ_FIELD_MAP[*]}" should include "hostname"
        The value "${_WIZ_FIELD_MAP[*]}" should include "email"
        The value "${_WIZ_FIELD_MAP[*]}" should include "password"
        The value "${_WIZ_FIELD_MAP[*]}" should include "timezone"
        The value "${_WIZ_FIELD_MAP[*]}" should include "keyboard"
        The value "${_WIZ_FIELD_MAP[*]}" should include "country"
      End
    End

    Describe "Proxmox screen (1)"
      BeforeEach 'setup_add_field'

      It "adds version and repository fields"
        When call _wiz_render_screen_content 1 0
        The value "${_WIZ_FIELD_MAP[*]}" should include "iso_version"
        The value "${_WIZ_FIELD_MAP[*]}" should include "repository"
      End
    End

    Describe "Network screen (2)"
      BeforeEach 'setup_add_field'

      It "includes interface when multiple interfaces"
        INTERFACE_COUNT=2
        When call _wiz_render_screen_content 2 0
        The value "${_WIZ_FIELD_MAP[*]}" should include "interface"
      End

      It "excludes interface when single interface"
        INTERFACE_COUNT=1
        When call _wiz_render_screen_content 2 0
        The value "${_WIZ_FIELD_MAP[*]}" should not include "interface"
      End

      It "includes private_subnet and bridge_mtu for internal mode"
        BRIDGE_MODE="internal"
        When call _wiz_render_screen_content 2 0
        The value "${_WIZ_FIELD_MAP[*]}" should include "private_subnet"
        The value "${_WIZ_FIELD_MAP[*]}" should include "bridge_mtu"
      End

      It "includes private_subnet and bridge_mtu for both mode"
        BRIDGE_MODE="both"
        When call _wiz_render_screen_content 2 0
        The value "${_WIZ_FIELD_MAP[*]}" should include "private_subnet"
        The value "${_WIZ_FIELD_MAP[*]}" should include "bridge_mtu"
      End

      It "excludes private_subnet and bridge_mtu for external mode"
        BRIDGE_MODE="external"
        When call _wiz_render_screen_content 2 0
        The value "${_WIZ_FIELD_MAP[*]}" should not include "private_subnet"
        The value "${_WIZ_FIELD_MAP[*]}" should not include "bridge_mtu"
      End

      It "always includes ipv6 and firewall"
        When call _wiz_render_screen_content 2 0
        The value "${_WIZ_FIELD_MAP[*]}" should include "ipv6"
        The value "${_WIZ_FIELD_MAP[*]}" should include "firewall"
      End
    End

    Describe "Storage screen (3)"
      BeforeEach 'setup_add_field'

      It "includes boot_disk and pool_disks when multiple drives"
        DRIVE_COUNT=3
        When call _wiz_render_screen_content 3 0
        The value "${_WIZ_FIELD_MAP[*]}" should include "boot_disk"
        The value "${_WIZ_FIELD_MAP[*]}" should include "pool_disks"
      End

      It "excludes boot_disk and pool_disks when single drive"
        DRIVE_COUNT=1
        When call _wiz_render_screen_content 3 0
        The value "${_WIZ_FIELD_MAP[*]}" should not include "boot_disk"
        The value "${_WIZ_FIELD_MAP[*]}" should not include "pool_disks"
      End

      It "always includes zfs_mode and zfs_arc"
        When call _wiz_render_screen_content 3 0
        The value "${_WIZ_FIELD_MAP[*]}" should include "zfs_mode"
        The value "${_WIZ_FIELD_MAP[*]}" should include "zfs_arc"
      End
    End

    Describe "Services screen (4)"
      BeforeEach 'setup_add_field'

      It "includes ssl when tailscale disabled"
        INSTALL_TAILSCALE="no"
        When call _wiz_render_screen_content 4 0
        The value "${_WIZ_FIELD_MAP[*]}" should include "ssl"
      End

      It "excludes ssl when tailscale enabled"
        INSTALL_TAILSCALE="yes"
        When call _wiz_render_screen_content 4 0
        The value "${_WIZ_FIELD_MAP[*]}" should not include "ssl"
      End

      It "always includes core service fields"
        When call _wiz_render_screen_content 4 0
        The value "${_WIZ_FIELD_MAP[*]}" should include "tailscale"
        The value "${_WIZ_FIELD_MAP[*]}" should include "shell"
        The value "${_WIZ_FIELD_MAP[*]}" should include "power_profile"
        The value "${_WIZ_FIELD_MAP[*]}" should include "security"
        The value "${_WIZ_FIELD_MAP[*]}" should include "monitoring"
        The value "${_WIZ_FIELD_MAP[*]}" should include "tools"
      End
    End

    Describe "Access screen (5)"
      BeforeEach 'setup_add_field'

      It "includes all access fields"
        When call _wiz_render_screen_content 5 0
        The value "${_WIZ_FIELD_MAP[*]}" should include "admin_username"
        The value "${_WIZ_FIELD_MAP[*]}" should include "admin_password"
        The value "${_WIZ_FIELD_MAP[*]}" should include "ssh_key"
        The value "${_WIZ_FIELD_MAP[*]}" should include "api_token"
      End
    End
  End

  # ===========================================================================
  # _wiz_render_menu()
  # ===========================================================================
  Describe "_wiz_render_menu()"
    BeforeEach 'reset_wizard_state'

    It "renders menu without error"
      When call _wiz_render_menu 0
      The status should be success
      The output should be present
    End

    It "includes banner output"
      When call _wiz_render_menu 0
      The output should include "BANNER"
    End

    It "includes navigation header"
      When call _wiz_render_menu 0
      The output should include "NAV HEADER"
    End

    It "includes footer navigation hints"
      When call _wiz_render_menu 0
      The output should include "navigate"
      The output should include "edit"
      The output should include "start"
      The output should include "quit"
    End

    It "populates _WIZ_FIELD_MAP"
      When call _wiz_render_menu 0
      The output should be present
      # After render, field map should have entries (Basic screen has 6 fields)
      The value "${#_WIZ_FIELD_MAP[@]}" should equal 6
    End

    It "sets _WIZ_FIELD_COUNT"
      When call _wiz_render_menu 0
      The output should be present
      # Basic screen has 6 fields
      The variable _WIZ_FIELD_COUNT should equal 6
    End

    It "highlights selected field with orange cursor"
      When call _wiz_render_menu 0
      The output should include "›"
    End

    It "handles different screen indexes"
      WIZ_CURRENT_SCREEN=2
      When call _wiz_render_menu 0
      The status should be success
      The output should be present
    End

    It "handles different selection indexes"
      When call _wiz_render_menu 2
      The status should be success
      The output should be present
    End

    It "renders Proxmox screen (1)"
      WIZ_CURRENT_SCREEN=1
      When call _wiz_render_menu 0
      The status should be success
      The output should be present
    End

    It "renders Network screen (2)"
      WIZ_CURRENT_SCREEN=2
      When call _wiz_render_menu 0
      The status should be success
      The output should be present
    End

    It "renders Storage screen (3)"
      WIZ_CURRENT_SCREEN=3
      When call _wiz_render_menu 0
      The status should be success
      The output should be present
    End

    It "renders Services screen (4)"
      WIZ_CURRENT_SCREEN=4
      When call _wiz_render_menu 0
      The status should be success
      The output should be present
    End

    It "renders Access screen (5)"
      WIZ_CURRENT_SCREEN=5
      When call _wiz_render_menu 0
      The status should be success
      The output should be present
    End

    It "shows prev hint"
      WIZ_CURRENT_SCREEN=0
      When call _wiz_render_menu 0
      The output should include "prev"
    End

    It "shows next hint"
      WIZ_CURRENT_SCREEN=5
      When call _wiz_render_menu 0
      The output should include "next"
    End

    Describe "with complete configuration"
      setup_complete_for_menu() {
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="password123"
        ADMIN_USERNAME="admin"
        ADMIN_PASSWORD="adminpass"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE="no-subscription"
        INTERFACE_NAME="eth0"
        BRIDGE_MODE="external"
        PRIVATE_SUBNET="10.0.0.0/24"
        IPV6_MODE="disabled"
        ZFS_RAID="single"
        ZFS_ARC_MODE="balanced"
        SHELL_TYPE="zsh"
        CPU_GOVERNOR="performance"
        SSH_PUBLIC_KEY="ssh-rsa AAAA..."
        ZFS_POOL_DISKS=("/dev/sda")
        INSTALL_TAILSCALE="yes"
        FIREWALL_MODE="standard"
      }

      BeforeEach 'setup_complete_for_menu'

      It "enables start hint when config is complete"
        When call _wiz_render_menu 0
        The output should include "start"
        The status should be success
      End
    End

    Describe "with multiple drives"
      setup_multi_drive() {
        DRIVE_COUNT=3
        DRIVES=("/dev/sda" "/dev/sdb" "/dev/sdc")
        DRIVE_MODELS=("Samsung 970" "WD Black" "Seagate Barracuda")
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
      }

      BeforeEach 'setup_multi_drive'

      It "includes boot_disk field on storage screen"
        WIZ_CURRENT_SCREEN=3
        When call _wiz_render_menu 0
        The output should be present
        The value "${_WIZ_FIELD_MAP[*]}" should include "boot_disk"
      End

      It "includes pool_disks field on storage screen"
        WIZ_CURRENT_SCREEN=3
        When call _wiz_render_menu 0
        The output should be present
        The value "${_WIZ_FIELD_MAP[*]}" should include "pool_disks"
      End
    End

    Describe "with multiple interfaces"
      setup_multi_interface() {
        INTERFACE_COUNT=2
        INTERFACE_NAME="eth0"
      }

      BeforeEach 'setup_multi_interface'

      It "includes interface field on network screen"
        WIZ_CURRENT_SCREEN=2
        When call _wiz_render_menu 0
        The output should be present
        The value "${_WIZ_FIELD_MAP[*]}" should include "interface"
      End
    End

    Describe "Tailscale/SSL display logic"
      It "includes ssl field when tailscale disabled"
        INSTALL_TAILSCALE="no"
        WIZ_CURRENT_SCREEN=4
        When call _wiz_render_menu 0
        The output should be present
        The value "${_WIZ_FIELD_MAP[*]}" should include "ssl"
      End

      It "excludes ssl field when tailscale enabled"
        INSTALL_TAILSCALE="yes"
        WIZ_CURRENT_SCREEN=4
        When call _wiz_render_menu 0
        The output should be present
        The value "${_WIZ_FIELD_MAP[*]}" should not include "ssl"
      End
    End

    Describe "Bridge mode subnet/MTU display logic"
      It "shows private_subnet for internal bridge mode"
        BRIDGE_MODE="internal"
        WIZ_CURRENT_SCREEN=2
        When call _wiz_render_menu 0
        The output should be present
        The value "${_WIZ_FIELD_MAP[*]}" should include "private_subnet"
        The value "${_WIZ_FIELD_MAP[*]}" should include "bridge_mtu"
      End

      It "shows private_subnet for both bridge mode"
        BRIDGE_MODE="both"
        WIZ_CURRENT_SCREEN=2
        When call _wiz_render_menu 0
        The output should be present
        The value "${_WIZ_FIELD_MAP[*]}" should include "private_subnet"
        The value "${_WIZ_FIELD_MAP[*]}" should include "bridge_mtu"
      End

      It "hides private_subnet for external bridge mode"
        BRIDGE_MODE="external"
        WIZ_CURRENT_SCREEN=2
        When call _wiz_render_menu 0
        The output should be present
        The value "${_WIZ_FIELD_MAP[*]}" should not include "private_subnet"
        The value "${_WIZ_FIELD_MAP[*]}" should not include "bridge_mtu"
      End
    End
  End

  # ===========================================================================
  # Field tracking variables
  # ===========================================================================
  Describe "Field tracking"
    BeforeEach 'reset_wizard_state'

    It "initializes _WIZ_FIELD_COUNT to 0"
      The variable _WIZ_FIELD_COUNT should equal 0
    End

    It "initializes _WIZ_FIELD_MAP as empty array"
      The value "${#_WIZ_FIELD_MAP[@]}" should equal 0
    End
  End
End

