#!/usr/bin/env bash
cd /root||exit 1
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
readonly CLR_RED=$'\033[1;31m'
readonly CLR_CYAN=$'\033[38;2;0;177;255m'
readonly CLR_YELLOW=$'\033[1;33m'
readonly CLR_ORANGE=$'\033[38;5;208m'
readonly CLR_GRAY=$'\033[38;5;240m'
readonly CLR_GOLD=$'\033[38;5;179m'
readonly CLR_RESET=$'\033[m'
readonly TREE_BRANCH="$CLR_ORANGE├─$CLR_RESET"
readonly TREE_VERT="$CLR_ORANGE│$CLR_RESET"
readonly TREE_END="$CLR_ORANGE└─$CLR_RESET"
readonly HEX_RED="#ff0000"
readonly HEX_CYAN="#00b1ff"
readonly HEX_YELLOW="#ffff00"
readonly HEX_ORANGE="#ff8700"
readonly HEX_GRAY="#585858"
readonly HEX_WHITE="#ffffff"
readonly HEX_NONE="7"
readonly VERSION="2.0.846-pr.21"
readonly TERM_WIDTH=80
readonly BANNER_WIDTH=51
GITHUB_REPO="${GITHUB_REPO:-qoxi-cloud/proxmox-installer}"
GITHUB_BRANCH="${GITHUB_BRANCH:-feat/interactive-config-table}"
GITHUB_BASE_URL="https://github.com/$GITHUB_REPO/raw/refs/heads/$GITHUB_BRANCH"
readonly PROXMOX_ISO_BASE_URL="https://enterprise.proxmox.com/iso/"
readonly PROXMOX_CHECKSUM_URL="https://enterprise.proxmox.com/iso/SHA256SUMS"
readonly DNS_SERVERS=("1.1.1.1" "8.8.8.8" "9.9.9.9")
readonly DNS_PRIMARY="1.1.1.1"
readonly DNS_SECONDARY="1.0.0.1"
readonly DNS6_PRIMARY="2606:4700:4700::1111"
readonly DNS6_SECONDARY="2606:4700:4700::1001"
readonly DEFAULT_IPV6_GATEWAY="fe80::1"
readonly MIN_DISK_SPACE_MB=6000
readonly MIN_RAM_MB=4000
readonly MIN_CPU_CORES=2
readonly MIN_QEMU_RAM=4096
readonly DOWNLOAD_RETRY_COUNT=3
readonly DOWNLOAD_RETRY_DELAY=2
readonly SSH_CONNECT_TIMEOUT=10
readonly SSH_PORT_QEMU=5555
readonly PORT_SSH=22
readonly PORT_PROXMOX_UI=443
readonly DEFAULT_PASSWORD_LENGTH=16
readonly QEMU_MIN_RAM_RESERVE=2048
readonly DNS_LOOKUP_TIMEOUT=5
readonly DNS_RETRY_DELAY=10
readonly QEMU_INSTALL_TIMEOUT=300
readonly QEMU_BOOT_TIMEOUT=300
readonly QEMU_PORT_CHECK_INTERVAL=3
readonly QEMU_SSH_READY_TIMEOUT=120
readonly DEFAULT_ZFS_POOL_NAME="local-zfs"
readonly RETRY_DELAY_SECONDS=2
readonly SSH_RETRY_ATTEMPTS=3
readonly PROGRESS_POLL_INTERVAL=0.2
readonly PROCESS_KILL_WAIT=1
readonly VM_SHUTDOWN_TIMEOUT=120
readonly WIZARD_MESSAGE_DELAY=3
readonly PARALLEL_MAX_JOBS=8
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
readonly WIZ_IPV6_MODES="Auto
Manual
Disabled"
readonly WIZ_PRIVATE_SUBNETS="10.0.0.0/24
192.168.1.0/24
172.16.0.0/24
Custom"
readonly WIZ_FIREWALL_MODES="Stealth (Tailscale only)
Strict (SSH only)
Standard (SSH + Web UI)
Disabled"
readonly WIZ_PASSWORD_OPTIONS="Manual entry
Generate password"
readonly WIZ_SSH_KEY_OPTIONS="Use detected key
Enter different key"
readonly WIZ_FEATURES_SECURITY="apparmor
auditd
aide
chkrootkit
lynis
needrestart"
readonly WIZ_FEATURES_MONITORING="vnstat
netdata
promtail"
readonly WIZ_FEATURES_TOOLS="yazi
nvim
ringbuffer"
readonly WIZ_MAP_BRIDGE_MODE=(
"Internal NAT:internal"
"External bridge:external"
"Both:both")
readonly WIZ_MAP_BRIDGE_MTU=(
"9000 (jumbo frames):9000"
"1500 (standard):1500")
readonly WIZ_MAP_SHELL=(
"ZSH:zsh"
"Bash:bash")
readonly WIZ_MAP_ZFS_ARC=(
"VM-focused (4GB fixed):vm-focused"
"Balanced (25-40% of RAM):balanced"
"Storage-focused (50% of RAM):storage-focused")
readonly WIZ_MAP_REPO_TYPE=(
"No-subscription (free):no-subscription"
"Enterprise:enterprise"
"Test/Development:test")
readonly WIZ_MAP_SSL_TYPE=(
"Self-signed:self-signed"
"Let's Encrypt:letsencrypt")
readonly WIZ_MAP_WIPE_DISKS=(
"Yes - Full wipe (recommended):yes"
"No - Keep existing:no")
INSTALL_DIR="${INSTALL_DIR:-${HOME:-/root}}"
BOOT_DISK=""
ZFS_POOL_DISKS=()
USE_EXISTING_POOL=""
EXISTING_POOL_NAME=""
EXISTING_POOL_DISKS=()
WIPE_DISKS="yes"
SYSTEM_UTILITIES="sudo btop iotop ncdu tmux pigz smartmontools jq bat fastfetch sysstat nethogs ethtool curl gnupg"
OPTIONAL_PACKAGES="libguestfs-tools"
LOG_FILE="$INSTALL_DIR/pve-install-$(date +%Y%m%d-%H%M%S).log"
INSTALL_COMPLETED=false
INSTALL_START_TIME=$(date +%s)
QEMU_RAM_OVERRIDE=""
QEMU_CORES_OVERRIDE=""
PROXMOX_ISO_VERSION=""
PVE_REPO_TYPE=""
PVE_SUBSCRIPTION_KEY=""
SSL_TYPE=""
SHELL_TYPE=""
KEYBOARD="en-us"
COUNTRY="us"
LOCALE="en_US.UTF-8"
TIMEZONE="UTC"
CPU_GOVERNOR=""
ZFS_ARC_MODE=""
INSTALL_AUDITD=""
INSTALL_AIDE=""
INSTALL_APPARMOR=""
INSTALL_CHKROOTKIT=""
INSTALL_LYNIS=""
INSTALL_NEEDRESTART=""
INSTALL_NETDATA=""
INSTALL_VNSTAT=""
INSTALL_PROMTAIL=""
INSTALL_RINGBUFFER=""
INSTALL_YAZI=""
INSTALL_NVIM=""
INSTALL_TAILSCALE=""
TAILSCALE_AUTH_KEY=""
TAILSCALE_WEBUI=""
INSTALL_POSTFIX=""
SMTP_RELAY_HOST=""
SMTP_RELAY_PORT=""
SMTP_RELAY_USER=""
SMTP_RELAY_PASSWORD=""
BRIDGE_MTU=""
INSTALL_API_TOKEN=""
API_TOKEN_NAME="automation"
API_TOKEN_VALUE=""
API_TOKEN_ID=""
NEW_ROOT_PASSWORD=""
ADMIN_USERNAME=""
ADMIN_PASSWORD=""
INSTALL_FIREWALL=""
FIREWALL_MODE=""
_TEMP_API_TOKEN_FILE="/tmp/pve-install-api-token.$$.env"
_TEMP_SSH_CONTROL_PATH="/tmp/ssh-pve-control.$$"
_TEMP_SCP_LOCK_FILE="/tmp/pve-scp-lock.$$"
_TEMP_FILES=()
register_temp_file(){
_TEMP_FILES+=("$1")
}
cleanup_temp_files(){
local install_dir="${INSTALL_DIR:-${HOME:-/root}}"
if type secure_delete_file &>/dev/null;then
[[ -n ${_TEMP_API_TOKEN_FILE:-} ]]&&secure_delete_file "$_TEMP_API_TOKEN_FILE"
secure_delete_file "$install_dir/answer.toml"
else
if [[ -n ${_TEMP_API_TOKEN_FILE:-} ]];then
rm -f "$_TEMP_API_TOKEN_FILE" 2>/dev/null||true
fi
rm -f "$install_dir/answer.toml" 2>/dev/null||true
fi
for f in "${_TEMP_FILES[@]}";do
if [[ -d $f ]];then
rm -rf "$f" 2>/dev/null||true
elif [[ -f $f ]]||[[ -S $f ]];then
if [[ $f == *"pve-ssh-session"* ]]&&type secure_delete_file &>/dev/null;then
secure_delete_file "$f"
else
rm -f "$f" 2>/dev/null||true
fi
fi
done
if [[ $INSTALL_COMPLETED != "true" ]];then
rm -f "$install_dir/pve.iso" "$install_dir/pve-autoinstall.iso" "$install_dir/SHA256SUMS" 2>/dev/null||true
rm -f "$install_dir"/qemu_*.log 2>/dev/null||true
fi
}
cleanup_and_error_handler(){
local exit_code="$?"
jobs -p|xargs -r kill 2>/dev/null||true
sleep "${PROCESS_KILL_WAIT:-1}"
if type _ssh_session_cleanup &>/dev/null;then
_ssh_session_cleanup
fi
cleanup_temp_files
if [[ -n ${QEMU_PID:-} ]]&&kill -0 "$QEMU_PID" 2>/dev/null;then
log_info "Cleaning up QEMU process $QEMU_PID"
if type release_drives &>/dev/null;then
release_drives
else
pkill -TERM qemu-system-x86 2>/dev/null||true
sleep "${RETRY_DELAY_SECONDS:-2}"
pkill -9 qemu-system-x86 2>/dev/null||true
fi
fi
tput rmcup 2>/dev/null||true
tput cnorm 2>/dev/null||true
if [[ $INSTALL_COMPLETED != "true" && $exit_code -ne 0 ]];then
printf '%s\n' "$CLR_RED*** INSTALLATION FAILED ***$CLR_RESET"
printf '\n'
printf '%s\n' "${CLR_YELLOW}An error occurred and the installation was aborted.$CLR_RESET"
printf '\n'
printf '%s\n' "${CLR_YELLOW}Please check the log file for details:$CLR_RESET"
printf '%s\n' "$CLR_YELLOW  $LOG_FILE$CLR_RESET"
printf '\n'
fi
}
trap cleanup_and_error_handler EXIT
register_temp_file "$_TEMP_SCP_LOCK_FILE"
show_help(){
cat <<EOF
Qoxi Automated Installer v$VERSION

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
parse_cli_args(){
declare -g QEMU_RAM_OVERRIDE=""
declare -g QEMU_CORES_OVERRIDE=""
declare -g PROXMOX_ISO_VERSION=""
while [[ $# -gt 0 ]];do
case $1 in
-h|--help)show_help
return 2
;;
-v|--version)printf '%s\n' "Proxmox Installer v$VERSION"
return 2
;;
--qemu-ram)if
[[ -z ${2:-} || ${2:-} =~ ^-- ]]
then
printf '%s\n' "${CLR_RED}Error: --qemu-ram requires a value in MB$CLR_RESET"
return 1
fi
if ! [[ $2 =~ ^[0-9]{1,6}$ ]]||[[ $2 -lt 2048 ]];then
printf '%s\n' "${CLR_RED}Error: --qemu-ram must be a number >= 2048 MB$CLR_RESET"
return 1
fi
if [[ $2 -gt 131072 ]];then
printf '%s\n' "${CLR_RED}Error: --qemu-ram must be <= 131072 MB (128 GB)$CLR_RESET"
return 1
fi
declare -g QEMU_RAM_OVERRIDE="$2"
shift 2
;;
--qemu-cores)if
[[ -z ${2:-} || ${2:-} =~ ^-- ]]
then
printf '%s\n' "${CLR_RED}Error: --qemu-cores requires a value$CLR_RESET"
return 1
fi
if ! [[ $2 =~ ^[0-9]{1,3}$ ]]||[[ $2 -lt 1 ]];then
printf '%s\n' "${CLR_RED}Error: --qemu-cores must be a positive number$CLR_RESET"
return 1
fi
if [[ $2 -gt 256 ]];then
printf '%s\n' "${CLR_RED}Error: --qemu-cores must be <= 256$CLR_RESET"
return 1
fi
declare -g QEMU_CORES_OVERRIDE="$2"
shift 2
;;
--iso-version)if
[[ -z ${2:-} || ${2:-} =~ ^-- ]]
then
printf '%s\n' "${CLR_RED}Error: --iso-version requires a filename$CLR_RESET"
return 1
fi
if ! [[ $2 =~ ^proxmox-ve_[0-9]+\.[0-9]+-[0-9]+\.iso$ ]];then
printf '%s\n' "${CLR_RED}Error: --iso-version must be in format: proxmox-ve_X.Y-Z.iso$CLR_RESET"
return 1
fi
declare -g PROXMOX_ISO_VERSION="$2"
shift 2
;;
*)printf '%s\n' "Unknown option: $1"
printf '%s\n' "Use --help for usage information"
return 1
esac
done
return 0
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]||[[ ${_CLI_PARSE_ON_SOURCE:-true} == "true" ]];then
parse_cli_args "$@"
_cli_ret="$?"
if [[ $_cli_ret -eq 2 ]];then
exit 0
elif [[ $_cli_ret -ne 0 ]];then
exit 1
fi
fi
log(){
printf '%s\n' "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$LOG_FILE"
}
log_info(){
log "INFO: $*"
}
log_error(){
log "ERROR: $*"
}
log_warn(){
log "WARNING: $*"
}
log_debug(){
log "DEBUG: $*"
}
metrics_start(){
declare -g INSTALL_START_TIME="$(date +%s)"
log "METRIC: installation_started"
}
log_metric(){
local step="$1"
if [[ -n $INSTALL_START_TIME ]];then
local elapsed="$(($(date +%s)-INSTALL_START_TIME))"
log "METRIC: ${step}_completed elapsed=${elapsed}s"
fi
}
metrics_finish(){
if [[ -n $INSTALL_START_TIME ]];then
local total="$(($(date +%s)-INSTALL_START_TIME))"
local minutes="$((total/60))"
local seconds="$((total%60))"
log "METRIC: installation_completed total_time=${total}s (${minutes}m ${seconds}s)"
fi
}
BANNER_LETTER_COUNT=7
BANNER_HEIGHT=9
_BANNER_PAD_SIZE=$(((TERM_WIDTH-BANNER_WIDTH)/2))
printf -v _BANNER_PAD '%*s' "$_BANNER_PAD_SIZE" ''
show_banner(){
local p="$_BANNER_PAD"
local tagline="${CLR_CYAN}Qoxi ${CLR_GRAY}Automated Installer $CLR_GOLD$VERSION$CLR_RESET"
local text="Qoxi Automated Installer $VERSION"
local pad="$(((BANNER_WIDTH-${#text})/2))"
local spaces
printf -v spaces '%*s' "$pad" ''
printf '%s\n' \
"$p$CLR_GRAY _____                                             $CLR_RESET" \
"$p$CLR_GRAY|  __ \\                                            $CLR_RESET" \
"$p$CLR_GRAY| |__) | _ __   ___  ${CLR_ORANGE}__  __$CLR_GRAY  _ __ ___    ___  ${CLR_ORANGE}__  __$CLR_RESET" \
"$p$CLR_GRAY|  ___/ | '__| / _ \\ $CLR_ORANGE\\ \\/ /$CLR_GRAY | '_ \` _ \\  / _ \\ $CLR_ORANGE\\ \\/ /$CLR_RESET" \
"$p$CLR_GRAY| |     | |   | (_) |$CLR_ORANGE >  <$CLR_GRAY  | | | | | || (_) |$CLR_ORANGE >  <$CLR_RESET" \
"$p$CLR_GRAY|_|     |_|    \\___/ $CLR_ORANGE/_/\\_\\$CLR_GRAY |_| |_| |_| \\___/ $CLR_ORANGE/_/\\_\\$CLR_RESET" \
"" \
"$p$spaces$tagline"
}
_show_banner_frame(){
local h="${1:--1}"
local M="$CLR_GRAY"
local A="$CLR_ORANGE"
local R="$CLR_RESET"
local p="$_BANNER_PAD"
local line1="$p$M "
[[ $h -eq 0 ]]&&line1+="${A}_____$M"||line1+="_____"
line1+="                                             $R"
local line2="$p$M"
[[ $h -eq 0 ]]&&line2+="$A|  __ \\$M"||line2+='|  __ \'
line2+="                                            $R"
local line3="$p$M"
[[ $h -eq 0 ]]&&line3+="$A| |__) |$M"||line3+="| |__) |"
[[ $h -eq 1 ]]&&line3+=" ${A}_ __$M"||line3+=" _ __"
[[ $h -eq 2 ]]&&line3+="   ${A}___$M"||line3+="   ___"
[[ $h -eq 3 ]]&&line3+="  ${A}__  __$M"||line3+="  __  __"
[[ $h -eq 4 ]]&&line3+="  ${A}_ __ ___$M"||line3+="  _ __ ___"
[[ $h -eq 5 ]]&&line3+="    ${A}___$M"||line3+="    ___"
[[ $h -eq 6 ]]&&line3+="  ${A}__  __$M"||line3+="  __  __"
line3+="$R"
local line4="$p$M"
[[ $h -eq 0 ]]&&line4+="$A|  ___/ $M"||line4+="|  ___/ "
[[ $h -eq 1 ]]&&line4+="$A| '__|$M"||line4+="| '__|"
[[ $h -eq 2 ]]&&line4+=" $A/ _ \\$M"||line4+=' / _ \'
[[ $h -eq 3 ]]&&line4+=" $A\\ \\/ /$M"||line4+=' \ \/ /'
[[ $h -eq 4 ]]&&line4+=" $A| '_ \` _ \\$M"||line4+=" | '_ \` _ \\"
[[ $h -eq 5 ]]&&line4+="  $A/ _ \\$M"||line4+='  / _ \'
[[ $h -eq 6 ]]&&line4+=" $A\\ \\/ /$M"||line4+=' \ \/ /'
line4+="$R"
local line5="$p$M"
[[ $h -eq 0 ]]&&line5+="$A| |     $M"||line5+="| |     "
[[ $h -eq 1 ]]&&line5+="$A| |$M"||line5+="| |"
[[ $h -eq 2 ]]&&line5+="   $A| (_) |$M"||line5+="   | (_) |"
[[ $h -eq 3 ]]&&line5+="$A >  <$M"||line5+=" >  <"
[[ $h -eq 4 ]]&&line5+="  $A| | | | | |$M"||line5+="  | | | | | |"
[[ $h -eq 5 ]]&&line5+="$A| (_) |$M"||line5+="| (_) |"
[[ $h -eq 6 ]]&&line5+="$A >  <$M"||line5+=" >  <"
line5+="$R"
local line6="$p$M"
[[ $h -eq 0 ]]&&line6+="$A|_|     $M"||line6+="|_|     "
[[ $h -eq 1 ]]&&line6+="$A|_|$M"||line6+="|_|"
[[ $h -eq 2 ]]&&line6+="    $A\\___/$M"||line6+='    \___/'
[[ $h -eq 3 ]]&&line6+=" $A/_/\\_\\$M"||line6+=' /_/\_\'
[[ $h -eq 4 ]]&&line6+=" $A|_| |_| |_|$M"||line6+=" |_| |_| |_|"
[[ $h -eq 5 ]]&&line6+=" $A\\___/$M"||line6+=' \___/'
[[ $h -eq 6 ]]&&line6+=" $A/_/\\_\\$M"||line6+=' /_/\_\'
line6+="$R"
local text="Qoxi Automated Installer $VERSION"
local pad="$(((BANNER_WIDTH-${#text})/2))"
local spaces
printf -v spaces '%*s' "$pad" ''
local line_tagline="$p$spaces${CLR_CYAN}Qoxi ${M}Automated Installer $CLR_GOLD$VERSION$R"
local frame
frame=$(printf '\033[H\033[J%s\n%s\n%s\n%s\n%s\n%s\n\n%s\n' \
"$line1" \
"$line2" \
"$line3" \
"$line4" \
"$line5" \
"$line6" \
"$line_tagline")
printf '%s' "$frame"
}
BANNER_ANIMATION_PID=""
show_banner_animated_start(){
local frame_delay="${1:-0.1}"
[[ ! -t 1 ]]&&return
show_banner_animated_stop 2>/dev/null
_wiz_hide_cursor
clear
(direction=1
current_letter=0
trap 'exit 0' TERM INT
trap 'clear' WINCH
[[ -c /dev/tty ]]&&exec 1>/dev/tty
exec 2>/dev/null
while true;do
_show_banner_frame "$current_letter"
sleep "$frame_delay"
if [[ $direction -eq 1 ]];then
((current_letter++))
if [[ $current_letter -ge $BANNER_LETTER_COUNT ]];then
current_letter="$((BANNER_LETTER_COUNT-2))"
direction=-1
fi
else
((current_letter--))
if [[ $current_letter -lt 0 ]];then
current_letter=1
direction=1
fi
fi
done) \
&
declare -g BANNER_ANIMATION_PID="$!"
}
show_banner_animated_stop(){
if [[ -n $BANNER_ANIMATION_PID ]];then
kill "$BANNER_ANIMATION_PID" 2>/dev/null
wait "$BANNER_ANIMATION_PID" 2>/dev/null
declare -g BANNER_ANIMATION_PID=""
fi
clear
show_banner
_wiz_show_cursor
}
print_error(){
printf '%s\n' "$CLR_RED✗$CLR_RESET $1"
}
print_warning(){
local message="$1"
local second="${2:-false}"
local indent=""
if [[ $# -eq 2 && $second != "true" ]];then
printf '%s\n' "$CLR_YELLOW⚠️$CLR_RESET $message $CLR_CYAN$second$CLR_RESET"
else
if [[ $second == "true" ]];then
indent="  "
fi
printf '%s\n' "$indent$CLR_YELLOW⚠️$CLR_RESET $message"
fi
}
print_info(){
printf '%s\n' "$CLR_CYANℹ$CLR_RESET $1"
}
show_progress(){
local pid="$1"
local message="${2:-Processing}"
local done_message="${3:-$message}"
local silent=false
[[ ${3:-} == "--silent" || ${4:-} == "--silent" ]]&&silent=true
[[ ${3:-} == "--silent" ]]&&done_message="$message"
local poll_interval="${PROGRESS_POLL_INTERVAL:-0.2}"
gum spin --spinner meter --spinner.foreground "#ff8700" --title "$message" -- bash -c "
    while kill -0 \"$pid\" 2>/dev/null; do
      sleep \"$poll_interval\"
    done
  "
wait "$pid" 2>/dev/null
local exit_code="$?"
if [[ $exit_code -eq 0 ]];then
if [[ $silent != true ]];then
printf "$CLR_CYAN✓$CLR_RESET %s\n" "$done_message"
fi
else
printf "$CLR_RED✗$CLR_RESET %s\n" "$message"
fi
return $exit_code
}
format_wizard_header(){
local title="$1"
local banner_pad="$_BANNER_PAD"
local line_width="$((BANNER_WIDTH-3))"
local half="$(((line_width-1)/2))"
local left_line="" right_line="" i
for ((i=0; i<half; i++));do
left_line+="━"
done
for ((i=0; i<line_width-1-half; i++));do
right_line+="─"
done
local title_len="${#title}"
local dot_pos="$half"
local title_start="$((dot_pos-title_len/2))"
local title_spaces=""
((title_start>0))&&title_spaces=$(printf '%*s' "$title_start" '')
printf '%s  %s%s\n' "$banner_pad" "$title_spaces" "$CLR_ORANGE$title$CLR_RESET"
printf '%s  %s%s%s%s' "$banner_pad" "$CLR_CYAN$left_line" "$CLR_ORANGE●" "$CLR_GRAY$right_line$CLR_RESET" ""
}
run_with_progress(){
local message="$1"
local done_message="$2"
shift 2
("$@"||exit 1) > \
/dev/null 2>&1&
show_progress "$!" "$message" "$done_message"
}
download_file(){
local output_file="$1"
local url="$2"
local max_retries="${DOWNLOAD_RETRY_COUNT:-3}"
local retry_delay="${DOWNLOAD_RETRY_DELAY:-2}"
local retry_count=0
while [[ $retry_count -lt $max_retries ]];do
if wget -q -O "$output_file" "$url";then
if [[ -s $output_file ]];then
return 0
else
print_error "Downloaded file is empty: $output_file"
fi
else
print_warning "Download failed (attempt $((retry_count+1))/$max_retries): $url"
fi
retry_count="$((retry_count+1))"
[[ $retry_count -lt $max_retries ]]&&sleep "$retry_delay"
done
log_error "Failed to download $url after $max_retries attempts"
return 1
}
declare -gA _CMD_CACHE
cmd_exists(){
local cmd="$1"
if [[ -z ${_CMD_CACHE[$cmd]+isset} ]];then
command -v "$cmd" &>/dev/null&&_CMD_CACHE[$cmd]=1||_CMD_CACHE[$cmd]=0
fi
[[ ${_CMD_CACHE[$cmd]} -eq 1 ]]
}
cmd_cache_clear(){
_CMD_CACHE=()
hash -r
}
_get_file_size(){
local file="$1"
local size
size=$(stat -c%s "$file" 2>/dev/null)||size=$(stat -f%z "$file" 2>/dev/null)||size=$(wc -c <"$file" 2>/dev/null|tr -d ' ')
[[ -n $size && $size =~ ^[0-9]+$ ]]&&echo "$size"
}
secure_delete_file(){
local file="$1"
[[ -z $file ]]&&return 0
[[ ! -f $file ]]&&return 0
if cmd_exists shred;then
shred -u -z "$file" 2>/dev/null||rm -f "$file"
else
local file_size
file_size=$(_get_file_size "$file")
if [[ -n $file_size ]];then
dd if=/dev/zero of="$file" bs=1 count="$file_size" conv=notrunc 2>/dev/null||true
fi
rm -f "$file"
fi
return 0
}
apply_template_vars(){
local file="$1"
shift
if [[ ! -f $file ]];then
log_error "Template file not found: $file"
return 1
fi
local sed_args=()
if [[ $# -gt 0 ]];then
for pair in "$@";do
local var="${pair%%=*}"
local value="${pair#*=}"
if [[ -z $value ]]&&grep -qF "{{$var}}" "$file" 2>/dev/null;then
local skip_log=false
case "$var" in
MAIN_IPV6|IPV6_ADDRESS|IPV6_GATEWAY|IPV6_PREFIX)[[ ${IPV6_MODE:-} != "auto" && ${IPV6_MODE:-} != "manual" ]]&&skip_log=true
esac
[[ $skip_log == false ]]&&log_debug "Template variable $var is empty, {{$var}} will be replaced with empty string in $file"
fi
value="${value//\\/\\\\}"
value="${value//&/\\&}"
value="${value//|/\\|}"
value="${value//$'\n'/\\$'\n'}"
sed_args+=(-e "s|{{$var}}|$value|g")
done
fi
if [[ ${#sed_args[@]} -gt 0 ]];then
local size_before
size_before=$(wc -c <"$file" 2>/dev/null||echo "?")
log_debug "Processing $file ($size_before bytes, ${#sed_args[@]} substitutions)"
local tmpfile="$file.tmp.$$"
if ! sed "${sed_args[@]}" "$file" >"$tmpfile" 2>>"$LOG_FILE";then
log_error "sed substitution failed for $file"
rm -f "$tmpfile"
return 1
fi
if [[ ! -s $tmpfile ]];then
log_error "sed produced empty output for $file"
log_debug "Original file exists: $([[ -f $file ]]&&echo yes||echo no), size: $(wc -c <"$file" 2>/dev/null||echo 0)"
rm -f "$tmpfile"
return 1
fi
if grep -qE '\{\{[A-Za-z0-9_]+\}\}' "$tmpfile" 2>/dev/null;then
local remaining
remaining=$(grep -oE '\{\{[A-Za-z0-9_]+\}\}' "$tmpfile" 2>/dev/null|sort -u|tr '\n' ' ')
log_error "Unsubstituted placeholders remain in $file: $remaining"
rm -f "$tmpfile"
return 1
fi
if ! mv "$tmpfile" "$file";then
log_error "Failed to replace $file with processed template"
rm -f "$tmpfile"
return 1
fi
local size_after
size_after=$(wc -c <"$file" 2>/dev/null||echo "?")
log_debug "Finished $file ($size_after bytes)"
else
if grep -qE '\{\{[A-Za-z0-9_]+\}\}' "$file" 2>/dev/null;then
local remaining
remaining=$(grep -oE '\{\{[A-Za-z0-9_]+\}\}' "$file" 2>/dev/null|sort -u|tr '\n' ' ')
log_error "Unsubstituted placeholders remain in $file: $remaining"
return 1
fi
fi
return 0
}
apply_common_template_vars(){
local file="$1"
local -a critical_vars=(MAIN_IPV4 MAIN_IPV4_GW PVE_HOSTNAME INTERFACE_NAME)
for var in "${critical_vars[@]}";do
if [[ -z ${!var:-} ]];then
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
download_template(){
local local_path="$1"
local remote_file="${2:-$(basename "$local_path")}"
local url="$GITHUB_BASE_URL/templates/$remote_file.tmpl"
if ! download_file "$local_path" "$url";then
return 1
fi
if [[ ! -s $local_path ]];then
print_error "Template $remote_file is empty or download failed"
log_error "Template $remote_file is empty after download"
return 1
fi
local filename
filename=$(basename "$local_path")
case "$filename" in
answer.toml)if
! grep -q "\[global\]" "$local_path" 2>/dev/null
then
print_error "Template $remote_file appears corrupted (missing [global] section)"
log_error "Template $remote_file corrupted - missing [global] section"
return 1
fi
;;
sshd_config)if
! grep -q "PasswordAuthentication" "$local_path" 2>/dev/null
then
print_error "Template $remote_file appears corrupted (missing PasswordAuthentication)"
log_error "Template $remote_file corrupted - missing PasswordAuthentication"
return 1
fi
;;
*.sh)if
! head -1 "$local_path"|grep -qE "^#!.*bash|^# shellcheck|^export "&&! grep -qE "(if|then|echo|function|export)" "$local_path" 2>/dev/null
then
print_error "Template $remote_file appears corrupted (invalid shell script)"
log_error "Template $remote_file corrupted - invalid shell script"
return 1
fi
;;
nftables.conf)if
! grep -q "table inet" "$local_path" 2>/dev/null
then
print_error "Template $remote_file appears corrupted (missing table inet definition)"
log_error "Template $remote_file corrupted - missing table inet"
return 1
fi
;;
promtail.yml|promtail.yaml)if
! grep -q "server:" "$local_path" 2>/dev/null||! grep -q "clients:" "$local_path" 2>/dev/null
then
print_error "Template $remote_file appears corrupted (missing YAML structure)"
log_error "Template $remote_file corrupted - missing server: or clients: section"
return 1
fi
;;
chrony|chrony.conf)if
! grep -qE "^(pool|server)" "$local_path" 2>/dev/null
then
print_error "Template $remote_file appears corrupted (missing NTP server config)"
log_error "Template $remote_file corrupted - missing pool or server directive"
return 1
fi
;;
*.service)if
! grep -q "\[Service\]" "$local_path" 2>/dev/null
then
print_error "Template $remote_file appears corrupted (missing [Service] section)"
log_error "Template $remote_file corrupted - missing [Service] section"
return 1
fi
if ! grep -qE "^ExecStart=" "$local_path" 2>/dev/null;then
print_error "Template $remote_file appears corrupted (missing ExecStart)"
log_error "Template $remote_file corrupted - missing ExecStart"
return 1
fi
;;
*.conf|*.sources|*.timer)if
[[ $(wc -l <"$local_path" 2>/dev/null||echo 0) -lt 2 ]]
then
print_error "Template $remote_file appears corrupted (too short)"
log_error "Template $remote_file corrupted - file too short"
return 1
fi
esac
log_info "Template $remote_file downloaded and validated successfully"
return 0
}
SSH_OPTS=(
-o StrictHostKeyChecking=no
-o UserKnownHostsFile=/dev/null
-o LogLevel=ERROR
-o "ConnectTimeout=${SSH_CONNECT_TIMEOUT:-10}"
-o ServerAliveInterval=30
-o ServerAliveCountMax=3
-o ControlMaster=auto
-o "ControlPath=$_TEMP_SSH_CONTROL_PATH"
-o ControlPersist=300)
SSH_PORT="${SSH_PORT_QEMU:-5555}"
_SSH_SESSION_PASSFILE=""
_SSH_SESSION_LOGGED=false
_ssh_passfile_path(){
local passfile_dir="/dev/shm"
if [[ ! -d /dev/shm ]]||[[ ! -w /dev/shm ]];then
passfile_dir="/tmp"
fi
printf '%s\n' "$passfile_dir/pve-ssh-session.$$"
}
_ssh_session_init(){
local passfile_path
passfile_path=$(_ssh_passfile_path)
if [[ -f $passfile_path ]]&&[[ -s $passfile_path ]];then
declare -g _SSH_SESSION_PASSFILE="$passfile_path"
return 0
fi
printf '%s' "$NEW_ROOT_PASSWORD" >"$passfile_path"
chmod 600 "$passfile_path"
declare -g _SSH_SESSION_PASSFILE="$passfile_path"
if [[ $BASHPID == "$$" ]]&&[[ $_SSH_SESSION_LOGGED != true ]];then
register_temp_file "$passfile_path"
register_temp_file "$_TEMP_SSH_CONTROL_PATH"
log_info "SSH session initialized: $passfile_path"
declare -g _SSH_SESSION_LOGGED=true
fi
}
_ssh_control_cleanup(){
if [[ -S $_TEMP_SSH_CONTROL_PATH ]];then
ssh -o ControlPath="$_TEMP_SSH_CONTROL_PATH" -O exit root@localhost >>"${LOG_FILE:-/dev/null}" 2>&1||true
rm -f "$_TEMP_SSH_CONTROL_PATH" 2>/dev/null||true
log_info "SSH control socket cleaned up: $_TEMP_SSH_CONTROL_PATH"
fi
}
_ssh_session_cleanup(){
_ssh_control_cleanup
local passfile_path
passfile_path=$(_ssh_passfile_path)
[[ ! -f $passfile_path ]]&&return 0
if type secure_delete_file &>/dev/null;then
secure_delete_file "$passfile_path"
elif cmd_exists shred;then
shred -u -z "$passfile_path" 2>/dev/null||rm -f "$passfile_path"
else
local file_size
file_size=$(stat -c%s "$passfile_path" 2>/dev/null)||file_size=$(stat -f%z "$passfile_path" 2>/dev/null)||file_size=$(wc -c <"$passfile_path" 2>/dev/null|tr -d ' ')
if [[ -n $file_size && $file_size =~ ^[0-9]+$ ]];then
dd if=/dev/zero of="$passfile_path" bs=1 count="$file_size" conv=notrunc 2>/dev/null||true
fi
rm -f "$passfile_path"
fi
declare -g _SSH_SESSION_PASSFILE=""
log_info "SSH session cleaned up: $passfile_path"
}
_ssh_get_passfile(){
_ssh_session_init
printf '%s\n' "$_SSH_SESSION_PASSFILE"
}
check_port_available(){
local port="$1"
if cmd_exists ss;then
if ss -tuln 2>/dev/null|grep -q ":$port ";then
return 1
fi
elif cmd_exists netstat;then
if netstat -tuln 2>/dev/null|grep -q ":$port ";then
return 1
fi
fi
return 0
}
wait_for_ssh_ready(){
local timeout="${1:-120}"
local start_time
start_time=$(date +%s)
local ssh_known_hosts="${INSTALL_DIR:-${HOME:-/root}}/.ssh/known_hosts"
ssh-keygen -f "$ssh_known_hosts" -R "[localhost]:$SSH_PORT" >>"${LOG_FILE:-/dev/null}" 2>&1||true
local port_timeout="$((timeout*3/4))"
local retry_delay="${RETRY_DELAY_SECONDS:-2}"
local port_check=0
local elapsed=0
while ((elapsed<port_timeout));do
if (echo >/dev/tcp/localhost/"$SSH_PORT") 2>/dev/null;then
port_check=1
break
fi
sleep "$retry_delay"
((elapsed+=retry_delay))
done
if [[ $port_check -eq 0 ]];then
print_error "Port $SSH_PORT is not accessible"
log_error "Port $SSH_PORT not accessible after ${port_timeout}s"
return 1
fi
local actual_elapsed="$(($(date +%s)-start_time))"
local ssh_timeout="$((timeout-actual_elapsed))"
if ((ssh_timeout<10));then
ssh_timeout=10
fi
local passfile
passfile=$(_ssh_get_passfile)
(elapsed=0
retry_delay="${RETRY_DELAY_SECONDS:-2}"
while ((elapsed<ssh_timeout));do
if sshpass -f "$passfile" ssh -p "$SSH_PORT" "${SSH_OPTS[@]}" root@localhost 'echo ready' >>"${LOG_FILE:-/dev/null}" 2>&1;then
exit 0
fi
sleep "$retry_delay"
((elapsed+=retry_delay))
done
exit 1) \
&
local wait_pid="$!"
show_progress "$wait_pid" "Waiting for SSH to be ready" "SSH connection established"
return "$?"
}
parse_ssh_key(){
local key="$1"
declare -g SSH_KEY_TYPE=""
declare -g SSH_KEY_DATA=""
declare -g SSH_KEY_COMMENT=""
declare -g SSH_KEY_SHORT=""
[[ -z $key ]]&&return 1
declare -g SSH_KEY_TYPE="$(printf '%s\n' "$key"|awk '{print $1}')"
declare -g SSH_KEY_DATA="$(printf '%s\n' "$key"|awk '{print $2}')"
declare -g SSH_KEY_COMMENT="$(printf '%s\n' "$key"|awk '{$1=""; $2=""; print}'|sed 's/^ *//')"
if [[ ${#SSH_KEY_DATA} -gt 35 ]];then
declare -g SSH_KEY_SHORT="${SSH_KEY_DATA:0:20}...${SSH_KEY_DATA: -10}"
else
declare -g SSH_KEY_SHORT="$SSH_KEY_DATA"
fi
return 0
}
get_rescue_ssh_key(){
local auth_keys="${INSTALL_DIR:-${HOME:-/root}}/.ssh/authorized_keys"
if [[ -f $auth_keys ]];then
grep -E "^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-nistp(256|384|521)|sk-(ssh-ed25519|ecdsa-sha2-nistp256)@openssh.com)" "$auth_keys" 2>/dev/null|head -1
fi
}
readonly SSH_DEFAULT_TIMEOUT=300
_sanitize_script_for_log(){
local script="$1"
local d=$'\x01'
script=$(printf '%s\n' "$script"|sed -E "s$d(PASSWORD|password|PASSWD|passwd|SECRET|secret|TOKEN|token|KEY|key)=('[^']*'|\"([^\"\\\\]|\\\\.)*\"|[^[:space:]'\";]+)$d\\1=[REDACTED]${d}g")
script=$(printf '%s\n' "$script"|sed -E "s$d(echo[[:space:]]+['\"]?[^:]+:)[^|'\"]*$d\\1[REDACTED]${d}g")
script=$(printf '%s\n' "$script"|sed -E "s$d(--authkey=)('[^']*'|\"[^\"]*\"|[^[:space:]'\";]+)$d\\1[REDACTED]${d}g")
script=$(printf '%s\n' "$script"|sed -E "s$d(echo[[:space:]]+['\"]?)[A-Za-z0-9+/=]+(['\"]?[[:space:]]*\\|[[:space:]]*base64[[:space:]]+-d)$d\\1[REDACTED]\\2${d}g")
printf '%s\n' "$script"
}
remote_exec(){
local passfile
passfile=$(_ssh_get_passfile)
local cmd_timeout="${SSH_COMMAND_TIMEOUT:-$SSH_DEFAULT_TIMEOUT}"
local max_attempts="${SSH_RETRY_ATTEMPTS:-3}"
local base_delay="${RETRY_DELAY_SECONDS:-2}"
local attempt=0
while [[ $attempt -lt $max_attempts ]];do
attempt="$((attempt+1))"
timeout "$cmd_timeout" sshpass -f "$passfile" ssh -p "$SSH_PORT" "${SSH_OPTS[@]}" root@localhost "$@" 2>>"$LOG_FILE"
local exit_code="$?"
if [[ $exit_code -eq 0 ]];then
return 0
fi
if [[ $exit_code -eq 124 ]];then
log_error "SSH command timed out after ${cmd_timeout}s: $(_sanitize_script_for_log "$*")"
return 124
fi
if [[ $attempt -lt $max_attempts ]];then
local delay="$((base_delay*(1<<(attempt-1))))"
((delay>30))&&delay=30
log_info "SSH attempt $attempt failed, retrying in $delay seconds..."
sleep "$delay"
fi
done
log_error "SSH command failed after $max_attempts attempts: $(_sanitize_script_for_log "$*")"
return 1
}
_remote_exec_with_progress(){
local message="$1"
local script="$2"
local done_message="${3:-$message}"
log_info "_remote_exec_with_progress: $message"
log_info "--- Script start (sanitized) ---"
_sanitize_script_for_log "$script" >>"$LOG_FILE"
log_info "--- Script end ---"
local passfile
passfile=$(_ssh_get_passfile)
local output_file=""
output_file=$(mktemp)||{
log_error "mktemp failed for output_file in _remote_exec_with_progress"
return 1
}
register_temp_file "$output_file"
local cmd_timeout="${SSH_COMMAND_TIMEOUT:-$SSH_DEFAULT_TIMEOUT}"
printf '%s\n' "$script"|timeout "$cmd_timeout" sshpass -f "$passfile" ssh -p "$SSH_PORT" "${SSH_OPTS[@]}" root@localhost 'bash -s' >"$output_file" 2>&1&
local pid="$!"
show_progress "$pid" "$message" "$done_message"
local exit_code="$?"
local exclude_pattern='(lib.*error|error-perl|\.deb|Unpacking|Setting up|Selecting|grub-probe|/sys/bus/usb|bInterface)'
if grep -iE '\b(error|failed|cannot|unable|fatal)\b' "$output_file" 2>/dev/null|grep -qivE "$exclude_pattern";then
log_warn "Potential errors in remote command output:"
grep -iE '\b(error|failed|cannot|unable|fatal)\b' "$output_file" 2>/dev/null|grep -ivE "$exclude_pattern" >>"$LOG_FILE"||true
fi
cat "$output_file" >>"$LOG_FILE"
rm -f "$output_file"
if [[ $exit_code -ne 0 ]];then
log_info "_remote_exec_with_progress: FAILED with exit code $exit_code"
else
log_info "_remote_exec_with_progress: completed successfully"
fi
return $exit_code
}
remote_run(){
local message="$1"
local script="$2"
local done_message="${3:-$message}"
if ! _remote_exec_with_progress "$message" "$script" "$done_message";then
log_error "$message failed"
exit 1
fi
}
remote_copy(){
local src="$1"
local dst="$2"
local passfile
passfile=$(_ssh_get_passfile)
(flock -x 200||{
log_error "Failed to acquire SCP lock for $src"
exit 1
}
if ! sshpass -f "$passfile" scp -P "$SSH_PORT" "${SSH_OPTS[@]}" "$src" "root@localhost:$dst" >>"$LOG_FILE" 2>&1;then
log_error "Failed to copy $src to $dst"
exit 1
fi) 200> \
"$_TEMP_SCP_LOCK_FILE"
return $?
}
generate_password(){
local length="${1:-16}"
tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom|head -c "$length"
}
_virtio_name_for_index(){
local idx="$1"
local letters="abcdefghijklmnopqrstuvwxyz"
if ((idx<26));then
printf 'vd%s\n' "${letters:idx:1}"
else
local prefix_idx="$(((idx-26)/26))"
local suffix_idx="$(((idx-26)%26))"
printf 'vd%s%s\n' "${letters:prefix_idx:1}" "${letters:suffix_idx:1}"
fi
}
create_virtio_mapping(){
local boot_disk="$1"
shift
local pool_disks=("$@")
declare -gA VIRTIO_MAP
local virtio_idx=0
if [[ -n $boot_disk ]];then
local vdev
vdev="$(_virtio_name_for_index "$virtio_idx")"
VIRTIO_MAP["$boot_disk"]="$vdev"
log_info "Virtio mapping: $boot_disk → /dev/$vdev (boot)"
((virtio_idx++))
fi
for drive in "${pool_disks[@]}";do
if [[ -n ${VIRTIO_MAP[$drive]:-} ]];then
log_info "Virtio mapping: $drive already mapped as boot disk, skipping"
continue
fi
local vdev
vdev="$(_virtio_name_for_index "$virtio_idx")"
VIRTIO_MAP["$drive"]="$vdev"
log_info "Virtio mapping: $drive → /dev/$vdev (pool)"
((virtio_idx++))
done
declare -p VIRTIO_MAP|sed 's/declare -A/declare -gA/' >/tmp/virtio_map.env
register_temp_file "/tmp/virtio_map.env"
log_info "Virtio mapping saved to /tmp/virtio_map.env"
}
load_virtio_mapping(){
if [[ -f /tmp/virtio_map.env ]];then
if ! grep -qE '^declare -gA VIRTIO_MAP=' /tmp/virtio_map.env;then
log_error "virtio_map.env missing expected declare statement"
return 1
fi
if grep -qvE '^declare -gA VIRTIO_MAP=' /tmp/virtio_map.env;then
log_error "virtio_map.env contains unexpected content"
return 1
fi
source /tmp/virtio_map.env
return 0
else
log_error "Virtio mapping file not found"
return 1
fi
}
map_disks_to_virtio(){
local format="$1"
shift
local disks=("$@")
if [[ ${#disks[@]} -eq 0 ]];then
log_error "No disks provided to map_disks_to_virtio"
return 1
fi
local vdevs=()
for disk in "${disks[@]}";do
if [[ -z ${VIRTIO_MAP[$disk]+isset} ]];then
log_error "VIRTIO_MAP not initialized or disk $disk not mapped"
return 1
fi
local vdev="${VIRTIO_MAP[$disk]}"
vdevs+=("/dev/$vdev")
done
case "$format" in
toml_array)local result="["
for i in "${!vdevs[@]}";do
local short_name="${vdevs[$i]#/dev/}"
result+="\"$short_name\""
[[ $i -lt $((${#vdevs[@]}-1)) ]]&&result+=", "
done
result+="]"
printf '%s\n' "$result"
;;
bash_array)printf '%s\n' "(${vdevs[*]})"
;;
space_separated)printf '%s\n' "${vdevs[*]}"
;;
*)log_error "Unknown format: $format"
return 1
esac
}
build_zpool_command(){
local pool_name="$1"
local raid_type="$2"
shift 2
local vdevs=("$@")
if [[ -z $pool_name ]];then
log_error "Pool name not provided"
return 1
fi
if [[ ${#vdevs[@]} -eq 0 ]];then
log_error "No vdevs provided to build_zpool_command"
return 1
fi
local cmd="zpool create -f $pool_name"
case "$raid_type" in
single)cmd+=" ${vdevs[0]}"
;;
raid0)cmd+=" ${vdevs[*]}"
;;
raid1)cmd+=" mirror ${vdevs[*]}"
;;
raidz1)cmd+=" raidz ${vdevs[*]}"
;;
raidz2)cmd+=" raidz2 ${vdevs[*]}"
;;
raidz3)cmd+=" raidz3 ${vdevs[*]}"
;;
raid10)local vdev_count="${#vdevs[@]}"
if ((vdev_count<4));then
log_error "raid10 requires at least 4 vdevs, got $vdev_count"
return 1
fi
if ((vdev_count%2!=0));then
log_error "raid10 requires even number of vdevs, got $vdev_count"
return 1
fi
for ((i=0; i<vdev_count; i+=2));do
cmd+=" mirror ${vdevs[$i]} ${vdevs[$((i+1))]}"
done
;;
*)log_error "Unknown RAID type: $raid_type"
return 1
esac
printf '%s\n' "$cmd"
}
map_raid_to_toml(){
local raid="$1"
case "$raid" in
single)echo "raid0";;
raid0)echo "raid0";;
raid1)echo "raid1";;
raidz1)echo "raidz-1";;
raidz2)echo "raidz-2";;
raidz3)echo "raidz-3";;
raid5)echo "raidz-1";;
raid10)echo "raid10";;
*)log_warn "Unknown RAID type '$raid', defaulting to raid0"
printf '%s\n' "raid0"
esac
}
_run_parallel_task(){
local result_dir="$1"
local idx="$2"
local func="$3"
trap "touch '$result_dir/fail_$idx' 2>/dev/null" EXIT
if "$func" >/dev/null 2>&1;then
if touch "$result_dir/success_$idx" 2>/dev/null;then
trap - EXIT
fi
fi
}
run_parallel_group(){
local group_name="$1"
local done_msg="$2"
shift 2
local funcs=("$@")
if [[ ${#funcs[@]} -eq 0 ]];then
log_info "No functions to run in parallel group: $group_name"
return 0
fi
local max_jobs="${PARALLEL_MAX_JOBS:-8}"
log_info "Running parallel group '$group_name' with functions: ${funcs[*]} (max $max_jobs concurrent)"
local result_dir
result_dir=$(mktemp -d)||{
log_error "Failed to create temp dir for parallel group '$group_name'"
return 1
}
register_temp_file "$result_dir"
export PARALLEL_RESULT_DIR="$result_dir"
local i=0
local running=0
for func in "${funcs[@]}";do
_run_parallel_task "$result_dir" "$i" "$func"&
((i++))
((running++))
while ((running>=max_jobs));do
local completed=0
for ((j=0; j<i; j++));do
[[ -f "$result_dir/success_$j" || -f "$result_dir/fail_$j" ]]&&((completed++))
done
running="$((i-completed))"
((running>=max_jobs))&&sleep 0.1
done
done
local count="$i"
(while
true
do
local done_count=0
for ((j=0; j<count; j++));do
[[ -f "$result_dir/success_$j" || -f "$result_dir/fail_$j" ]]&&((done_count++))
done
[[ $done_count -eq $count ]]&&break
sleep "${PROGRESS_POLL_INTERVAL:-0.2}"
done
for ((j=0; j<count; j++));do
[[ -f "$result_dir/fail_$j" ]]&&exit 1
done) \
&
show_progress "$!" "$group_name" "$done_msg"
wait
local configured=()
for f in "$result_dir"/ran_*;do
[[ -f $f ]]&&configured+=("$(cat "$f")")
done
for item in "${configured[@]}";do
add_subtask_log "$item"
done
local failures=0
for ((j=0; j<count; j++));do
[[ -f "$result_dir/fail_$j" ]]&&((failures++))
done
rm -rf "$result_dir"
unset PARALLEL_RESULT_DIR
if [[ $failures -gt 0 ]];then
log_error "$failures/$count functions failed in group '$group_name'"
return $failures
fi
return 0
}
parallel_mark_configured(){
local feature="$1"
[[ -n ${PARALLEL_RESULT_DIR:-} && -d $PARALLEL_RESULT_DIR ]]&&printf '%s' "$feature" >"$PARALLEL_RESULT_DIR/ran_$BASHPID"
}
start_async_feature(){
local feature="$1"
local flag_var="$2"
local flag_value="${!flag_var:-}"
REPLY=""
[[ $flag_value != "yes" ]]&&return 0
"configure_$feature" >>"$LOG_FILE" 2>&1&
REPLY="$!"
}
wait_async_feature(){
local feature="$1"
local pid="$2"
[[ -z $pid ]]&&return 0
wait "$pid" 2>/dev/null
local exit_code=$?
if [[ $exit_code -ne 0 ]];then
log_error "configure_$feature failed (exit code: $exit_code)"
return 1
fi
return 0
}
run_batch_copies(){
local -a pids=()
local -a pairs=("$@")
for pair in "${pairs[@]}";do
local src="${pair%%:*}"
local dst="${pair#*:}"
remote_copy "$src" "$dst"&
pids+=("$!")
done
local failures=0
for pid in "${pids[@]}";do
if ! wait "$pid";then
((failures++))
fi
done
if [[ $failures -gt 0 ]];then
log_error "$failures/${#pairs[@]} parallel copies failed"
return 1
fi
return 0
}
deploy_timer_with_logdir(){
local timer_name="$1"
local log_dir="$2"
deploy_systemd_timer "$timer_name"||return 1
remote_exec "mkdir -p '$log_dir'"||{
log_error "Failed to create $log_dir"
return 1
}
}
deploy_template(){
local template="$1"
local dest="$2"
shift 2
local staged
local is_service=false
[[ $dest == *.service ]]&&is_service=true
staged=$(mktemp)||{
log_error "Failed to create temp file for $template"
return 1
}
register_temp_file "$staged"
cp "$template" "$staged"||{
log_error "Failed to stage template $template"
rm -f "$staged"
return 1
}
apply_template_vars "$staged" "$@"||{
log_error "Template substitution failed for $template"
rm -f "$staged"
return 1
}
if [[ $is_service == true ]]&&! grep -q "ExecStart=" "$staged" 2>/dev/null;then
log_error "Service file $dest missing ExecStart after template substitution"
rm -f "$staged"
return 1
fi
local dest_dir
dest_dir=$(dirname "$dest")
remote_exec "mkdir -p '$dest_dir'"||{
log_error "Failed to create directory $dest_dir"
rm -f "$staged"
return 1
}
remote_copy "$staged" "$dest"||{
log_error "Failed to deploy $template to $dest"
rm -f "$staged"
return 1
}
rm -f "$staged"
if [[ $dest == /etc/systemd/* || $dest == *.service || $dest == *.timer ]];then
remote_exec "chmod 644 '$dest'"||{
log_error "Failed to set permissions on $dest"
return 1
}
fi
if [[ $is_service == true ]];then
remote_exec "grep -q 'ExecStart=' '$dest'"||{
log_error "Remote service file $dest appears corrupted (missing ExecStart)"
return 1
}
fi
}
make_feature_wrapper(){
local feature="$1"
local flag_var="$2"
eval "configure_$feature() { [[ \${$flag_var:-} != \"yes\" ]] && return 0; _config_$feature; }"
}
make_condition_wrapper(){
local feature="$1"
local var_name="$2"
local expected_value="$3"
eval "configure_$feature() { [[ \${$var_name:-} != \"$expected_value\" ]] && return 0; _config_$feature; }"
}
deploy_systemd_timer(){
local timer_name="$1"
local template_dir="${2:+$2/}"
remote_copy "templates/$template_dir$timer_name.service" \
"/etc/systemd/system/$timer_name.service"||{
log_error "Failed to deploy $timer_name service"
return 1
}
remote_copy "templates/$template_dir$timer_name.timer" \
"/etc/systemd/system/$timer_name.timer"||{
log_error "Failed to deploy $timer_name timer"
return 1
}
remote_exec "chmod 644 /etc/systemd/system/$timer_name.service /etc/systemd/system/$timer_name.timer"||{
log_warn "Failed to set permissions on $timer_name unit files"
}
remote_exec "systemctl daemon-reload && systemctl enable --now $timer_name.timer"||{
log_error "Failed to enable $timer_name timer"
return 1
}
}
deploy_systemd_service(){
local service_name="$1"
shift
local template="templates/$service_name.service"
local dest="/etc/systemd/system/$service_name.service"
deploy_template "$template" "$dest" "$@"||return 1
remote_exec "chmod 644 '$dest'"||{
log_warn "Failed to set permissions on $dest"
}
remote_enable_services "$service_name.service"
}
remote_enable_services(){
local services=("$@")
if [[ ${#services[@]} -eq 0 ]];then
return 0
fi
remote_exec "systemctl daemon-reload && systemctl enable --now ${services[*]}"||{
log_error "Failed to enable services: ${services[*]}"
return 1
}
}
deploy_user_config(){
require_admin_username "deploy user config"||return 1
local template="$1"
local relative_path="$2"
shift 2
local home_dir="/home/$ADMIN_USERNAME"
local dest="$home_dir/$relative_path"
local dest_dir staged
dest_dir="$(dirname "$dest")"
staged=$(mktemp)||{
log_error "Failed to create temp file for $template"
return 1
}
register_temp_file "$staged"
cp "$template" "$staged"||{
log_error "Failed to stage template $template"
rm -f "$staged"
return 1
}
apply_template_vars "$staged" "$@"||{
log_error "Template substitution failed for $template"
rm -f "$staged"
return 1
}
if [[ $dest_dir != "$home_dir" ]];then
remote_exec "mkdir -p '$dest_dir'"||{
log_error "Failed to create directory $dest_dir"
rm -f "$staged"
return 1
}
local dirs_to_chown=""
local dir="$dest_dir"
while [[ $dir != "$home_dir" && $dir != "/" ]];do
local escaped_dir="${dir//\'/\'\\\'\'}"
dirs_to_chown+="'$escaped_dir' "
dir="$(dirname "$dir")"
done
[[ -n $dirs_to_chown ]]&&{
remote_exec "chown $ADMIN_USERNAME:$ADMIN_USERNAME $dirs_to_chown"||{
log_error "Failed to set ownership on $dirs_to_chown"
rm -f "$staged"
return 1
}
}
fi
remote_copy "$staged" "$dest"||{
log_error "Failed to copy $template to $dest"
rm -f "$staged"
return 1
}
rm -f "$staged"
remote_exec "chown $ADMIN_USERNAME:$ADMIN_USERNAME '$dest'"||{
log_error "Failed to set ownership on $dest"
return 1
}
}
deploy_user_configs(){
for pair in "$@";do
local template="${pair%%:*}"
local relative="${pair#*:}"
deploy_user_config "$template" "$relative"||return 1
done
}
_generate_loopback(){
cat <<'EOF'
auto lo
iface lo inet loopback

iface lo inet6 loopback
EOF
}
_generate_iface_manual(){
cat <<EOF
# Physical interface (no IP, part of bridge)
auto $INTERFACE_NAME
iface $INTERFACE_NAME inet manual
EOF
}
_generate_iface_static(){
local ipv4_addr="${MAIN_IPV4_CIDR:-$MAIN_IPV4/32}"
local ipv6_addr="${IPV6_ADDRESS:-${IPV6_CIDR:-$MAIN_IPV6/128}}"
local ipv4_prefix="${ipv4_addr##*/}"
local ipv6_prefix="${ipv6_addr##*/}"
cat <<EOF
# Physical interface with host IP
auto $INTERFACE_NAME
iface $INTERFACE_NAME inet static
    address $ipv4_addr
EOF
if [[ $ipv4_prefix == "32" ]];then
cat <<EOF
    pointopoint $MAIN_IPV4_GW
EOF
fi
cat <<EOF
    gateway $MAIN_IPV4_GW
    up sysctl --system
EOF
if [[ ${IPV6_MODE:-} != "disabled" ]]&&[[ -n ${MAIN_IPV6:-} || -n ${IPV6_ADDRESS:-} ]];then
local ipv6_gw="${IPV6_GATEWAY:-fe80::1}"
[[ $ipv6_gw == "auto" ]]&&ipv6_gw="fe80::1"
cat <<EOF

iface $INTERFACE_NAME inet6 static
    address $ipv6_addr
    gateway $ipv6_gw
EOF
if [[ $ipv6_prefix == "128" && ! $ipv6_gw =~ ^fe80: ]];then
cat <<EOF
    up ip -6 route add $ipv6_gw/128 dev $INTERFACE_NAME
EOF
fi
cat <<EOF
    accept_ra 2
EOF
fi
}
_generate_vmbr0_external(){
local ipv4_addr="${MAIN_IPV4_CIDR:-$MAIN_IPV4/32}"
local ipv6_addr="${IPV6_ADDRESS:-${IPV6_CIDR:-$MAIN_IPV6/128}}"
local ipv4_prefix="${ipv4_addr##*/}"
local ipv6_prefix="${ipv6_addr##*/}"
local mtu="${BRIDGE_MTU:-1500}"
cat <<EOF
# vmbr0: External bridge - VMs get IPs from router/DHCP
# Host IP is on this bridge
auto vmbr0
iface vmbr0 inet static
    address $ipv4_addr
EOF
if [[ $ipv4_prefix == "32" ]];then
cat <<EOF
    pointopoint $MAIN_IPV4_GW
EOF
fi
cat <<EOF
    gateway $MAIN_IPV4_GW
    bridge-ports $INTERFACE_NAME
    bridge-stp off
    bridge-fd 0
    mtu $mtu
    up sysctl --system
EOF
if [[ ${IPV6_MODE:-} != "disabled" ]]&&[[ -n ${MAIN_IPV6:-} || -n ${IPV6_ADDRESS:-} ]];then
local ipv6_gw="${IPV6_GATEWAY:-fe80::1}"
[[ $ipv6_gw == "auto" ]]&&ipv6_gw="fe80::1"
cat <<EOF

iface vmbr0 inet6 static
    address $ipv6_addr
    gateway $ipv6_gw
EOF
if [[ $ipv6_prefix == "128" && ! $ipv6_gw =~ ^fe80: ]];then
cat <<EOF
    up ip -6 route add $ipv6_gw/128 dev vmbr0
EOF
fi
cat <<EOF
    accept_ra 2
EOF
fi
}
_generate_vmbr0_nat(){
local mtu="${BRIDGE_MTU:-9000}"
local private_ip="${PRIVATE_IP_CIDR:-10.0.0.1/24}"
local mtu_comment=""
[[ $mtu -gt 1500 ]]&&mtu_comment=" (jumbo frames for improved VM-to-VM performance)"
cat <<EOF
# vmbr0: Private NAT network for VMs
# All VMs connect here and access internet via NAT$mtu_comment
auto vmbr0
iface vmbr0 inet static
    address $private_ip
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    mtu $mtu
EOF
if [[ -n ${FIRST_IPV6_CIDR:-} && ${IPV6_MODE:-} != "disabled" ]];then
cat <<EOF

iface vmbr0 inet6 static
    address $FIRST_IPV6_CIDR
EOF
fi
}
_generate_vmbr1_nat(){
local mtu="${BRIDGE_MTU:-9000}"
local private_ip="${PRIVATE_IP_CIDR:-10.0.0.1/24}"
local mtu_comment=""
[[ $mtu -gt 1500 ]]&&mtu_comment=" (jumbo frames for improved VM-to-VM performance)"
cat <<EOF
# vmbr1: Private NAT network for VMs
# VMs connect here for isolated network with NAT to internet$mtu_comment
auto vmbr1
iface vmbr1 inet static
    address $private_ip
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    mtu $mtu
EOF
if [[ -n ${FIRST_IPV6_CIDR:-} && ${IPV6_MODE:-} != "disabled" ]];then
cat <<EOF

iface vmbr1 inet6 static
    address $FIRST_IPV6_CIDR
EOF
fi
}
_generate_interfaces_conf(){
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
internal)_generate_iface_static
echo ""
_generate_vmbr0_nat
;;
external)_generate_iface_manual
echo ""
_generate_vmbr0_external
;;
both)_generate_iface_manual
echo ""
_generate_vmbr0_external
echo ""
_generate_vmbr1_nat
;;
*)log_warn "Unknown BRIDGE_MODE '$mode', falling back to static config"
_generate_iface_static
echo ""
_generate_vmbr0_nat
esac
}
generate_interfaces_file(){
local output="${1:-./templates/interfaces}"
_generate_interfaces_conf >"$output"||return 1
log_info "Generated interfaces config (mode: ${BRIDGE_MODE:-internal})"
}
require_admin_username(){
if [[ -z ${ADMIN_USERNAME:-} ]];then
log_error "ADMIN_USERNAME is empty${1:+, cannot $1}"
return 1
fi
}
validate_hostname(){
local hostname="$1"
[[ ${hostname,,} == "localhost" ]]&&return 1
[[ $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]
}
validate_admin_username(){
local username="$1"
[[ ! $username =~ ^[a-z][a-z0-9_-]{0,31}$ ]]&&return 1
case "$username" in
root|nobody|daemon|bin|sys|sync|games|man|lp|mail|\
news|uucp|proxy|www-data|backup|list|irc|gnats|\
sshd|systemd-network|systemd-resolve|messagebus|\
polkitd|postfix|syslog|_apt|tss|uuidd|avahi|colord|\
cups-pk-helper|dnsmasq|geoclue|hplip|kernoops|lightdm|\
nm-openconnect|nm-openvpn|pulse|rtkit|saned|speech-dispatcher|\
whoopsie|admin|administrator|operator|guest)return 1
esac
return 0
}
validate_fqdn(){
local fqdn="$1"
[[ $fqdn =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]]
}
validate_email(){
local email="$1"
[[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}
validate_smtp_host(){
local host="$1"
[[ -z $host ]]&&return 1
[[ $host =~ ^[][a-zA-Z0-9.:-]+$ ]]&&[[ ${#host} -le 253 ]]
}
validate_smtp_port(){
local port="$1"
[[ $port =~ ^[0-9]+$ ]]&&((port>=1&&port<=65535))
}
validate_not_empty(){
[[ -n $1 ]]
}
is_ascii_printable(){
local LC_ALL=C
[[ $1 =~ ^[[:print:]]+$ ]]
}
get_password_error(){
local password="$1"
if [[ -z $password ]];then
printf '%s\n' "Password cannot be empty!"
elif [[ ${#password} -lt 8 ]];then
printf '%s\n' "Password must be at least 8 characters long."
elif ! is_ascii_printable "$password";then
printf '%s\n' "Password contains invalid characters (Cyrillic or non-ASCII). Only Latin letters, digits, and special characters are allowed."
fi
}
validate_pool_disk_conflict(){
[[ -z $BOOT_DISK ]]&&return 1
for disk in "${ZFS_POOL_DISKS[@]}";do
[[ $disk == "$BOOT_DISK" ]]&&return 0
done
return 1
}
validate_raid_disk_count(){
local pool_count="${#ZFS_POOL_DISKS[@]}"
case "$ZFS_RAID" in
single)[[ $pool_count -ne 1 ]]&&return 0;;
raid0|raid1)[[ $pool_count -lt 2 ]]&&return 0;;
raidz1)[[ $pool_count -lt 3 ]]&&return 0;;
raid10|raidz2)[[ $pool_count -lt 4 ]]&&return 0;;
raidz3)[[ $pool_count -lt 5 ]]&&return 0
esac
return 1
}
get_raid_min_disks(){
case "$1" in
single)echo 1;;
raid0|raid1)echo 2;;
raidz1)echo 3;;
raid10|raidz2)echo 4;;
raidz3)echo 5;;
*)echo 1
esac
}
validate_subnet(){
local subnet="$1"
if [[ ! $subnet =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]];then
return 1
fi
local ip="${subnet%/*}"
local octet1 octet2 octet3 octet4 temp
octet1="${ip%%.*}"
temp="${ip#*.}"
octet2="${temp%%.*}"
temp="${temp#*.}"
octet3="${temp%%.*}"
octet4="${temp#*.}"
[[ 10#$octet1 -le 255 && 10#$octet2 -le 255 && 10#$octet3 -le 255 && 10#$octet4 -le 255 ]]
}
validate_ipv6(){
local ipv6="$1"
[[ -z $ipv6 ]]&&return 1
ipv6="${ipv6%%\%*}"
[[ ! $ipv6 =~ ^[0-9a-fA-F:]+$ ]]&&return 1
[[ $ipv6 =~ ^:[^:] ]]&&return 1
[[ $ipv6 =~ [^:]:$ ]]&&return 1
[[ $ipv6 =~ ::: ]]&&return 1
local temp="${ipv6//::/}"
local double_colon_count="$(((${#ipv6}-${#temp})/2))"
[[ $double_colon_count -gt 1 ]]&&return 1
local groups left_count=0 right_count=0 colons
if [[ $ipv6 == *"::"* ]];then
local left="${ipv6%%::*}"
local right="${ipv6##*::}"
if [[ -n $left ]];then
colons="${left//[!:]/}"
left_count="$((${#colons}+1))"
fi
if [[ -n $right ]];then
colons="${right//[!:]/}"
right_count="$((${#colons}+1))"
fi
groups="$((left_count+right_count))"
[[ $groups -ge 8 ]]&&return 1
else
colons="${ipv6//[!:]/}"
[[ ${#colons} -ne 7 ]]&&return 1
fi
local group IFS=':'
set -- $ipv6
for group in "$@";do
[[ -z $group ]]&&continue
[[ ${#group} -gt 4 ]]&&return 1
[[ ! $group =~ ^[0-9a-fA-F]+$ ]]&&return 1
done
return 0
}
validate_ipv6_cidr(){
local ipv6_cidr="$1"
[[ ! $ipv6_cidr =~ ^.+/[0-9]+$ ]]&&return 1
local ipv6="${ipv6_cidr%/*}"
local prefix="${ipv6_cidr##*/}"
[[ ! $prefix =~ ^[0-9]+$ ]]&&return 1
[[ $prefix -lt 0 || $prefix -gt 128 ]]&&return 1
validate_ipv6 "$ipv6"
}
validate_ipv6_gateway(){
local gateway="$1"
[[ -z $gateway ]]&&return 0
[[ $gateway == "auto" ]]&&return 0
validate_ipv6 "$gateway"
}
_extract_ipv4(){
grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}'|head -1
}
_parse_dig_output(){
local output="$1"
local ip=""
ip=$(printf '%s\n' "$output"|grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'|head -1)
[[ -z $ip ]]&&ip=$(printf '%s\n' "$output"|_extract_ipv4)
printf '%s' "$ip"
}
_parse_host_output(){
local output="$1"
local ip=""
ip=$(printf '%s\n' "$output"|grep -i "has address"|head -1|awk '{print $NF}')
[[ -z $ip ]]&&ip=$(printf '%s\n' "$output"|grep -iE '(^|\s)A\s'|head -1|_extract_ipv4)
[[ -z $ip ]]&&ip=$(printf '%s\n' "$output"|tail -n +2|_extract_ipv4)
printf '%s' "$ip"
}
_parse_nslookup_output(){
local output="$1"
local ip=""
ip=$(printf '%s\n' "$output"|awk '/^Address:/ && !/#/ {print $2; exit}')
[[ -z $ip ]]&&ip=$(printf '%s\n' "$output"|grep -E '^Address:\s*[0-9]'|grep -v '#'|head -1|awk '{print $2}')
[[ -z $ip ]]&&ip=$(printf '%s\n' "$output"|awk '/^Name:/{found=1} found && /^Address:/{print $2; exit}')
[[ -z $ip ]]&&ip=$(printf '%s\n' "$output"|sed -n '/Non-authoritative\|^Name:/,$p'|_extract_ipv4)
printf '%s' "$ip"
}
_parse_getent_output(){
local output="$1"
local ip=""
ip=$(printf '%s\n' "$output"|grep -i 'STREAM'|head -1|awk '{print $1}')
[[ -z $ip ]]&&ip=$(printf '%s\n' "$output"|_extract_ipv4)
printf '%s' "$ip"
}
validate_dns_resolution(){
local fqdn="$1"
local expected_ip="$2"
local resolved_ip=""
local dns_timeout="${DNS_LOOKUP_TIMEOUT:-5}"
local retry_delay="${DNS_RETRY_DELAY:-10}"
local max_attempts=3
local dns_tool=""
if cmd_exists dig;then
dns_tool="dig"
elif cmd_exists host;then
dns_tool="host"
elif cmd_exists nslookup;then
dns_tool="nslookup"
fi
if [[ -z $dns_tool ]];then
log_warn "No DNS lookup tool available (dig, host, or nslookup)"
declare -g DNS_RESOLVED_IP=""
return 1
fi
for ((attempt=1; attempt<=max_attempts; attempt++));do
resolved_ip=""
local raw_output=""
for dns_server in "${DNS_SERVERS[@]}";do
case "$dns_tool" in
dig)raw_output=$(timeout "$dns_timeout" dig +short +tries=1 A "$fqdn" "@$dns_server" 2>/dev/null)
resolved_ip=$(_parse_dig_output "$raw_output")
;;
host)raw_output=$(timeout "$dns_timeout" host -t A "$fqdn" "$dns_server" 2>/dev/null)
resolved_ip=$(_parse_host_output "$raw_output")
;;
nslookup)raw_output=$(timeout "$dns_timeout" nslookup "$fqdn" "$dns_server" 2>/dev/null)
resolved_ip=$(_parse_nslookup_output "$raw_output")
esac
if [[ -n $resolved_ip ]];then
break
fi
done
if [[ -z $resolved_ip ]];then
case "$dns_tool" in
dig)raw_output=$(timeout "$dns_timeout" dig +short +tries=1 A "$fqdn" 2>/dev/null)
resolved_ip=$(_parse_dig_output "$raw_output")
;;
*)if
cmd_exists getent
then
raw_output=$(timeout "$dns_timeout" getent ahosts "$fqdn" 2>/dev/null)
resolved_ip=$(_parse_getent_output "$raw_output")
fi
esac
fi
if [[ -n $resolved_ip ]];then
declare -g DNS_RESOLVED_IP="$resolved_ip"
if [[ $resolved_ip == "$expected_ip" ]];then
return 0
else
return 2
fi
fi
if [[ $attempt -lt $max_attempts ]];then
log_warn "DNS lookup for $fqdn failed (attempt $attempt/$max_attempts), retrying in ${retry_delay}s..."
sleep "$retry_delay"
fi
done
log_error "Failed to resolve $fqdn after $max_attempts attempts"
declare -g DNS_RESOLVED_IP=""
return 1
}
validate_ssh_key_secure(){
local key="$1"
local key_info
if ! key_info=$(echo "$key"|ssh-keygen -l -f - 2>/dev/null);then
log_error "Invalid SSH public key format"
return 1
fi
local bits
bits=$(echo "$key_info"|awk '{print $1}')
local key_type
key_type=$(echo "$key"|awk '{print $1}')
case "$key_type" in
ssh-ed25519)log_info "SSH key validated (ED25519)"
return 0
;;
ecdsa-*)if
[[ $bits -ge 256 ]]
then
log_info "SSH key validated ($key_type, $bits bits)"
return 0
fi
log_error "ECDSA key curve too small (current: $bits)"
return 1
;;
ssh-rsa)if
[[ $bits -ge 2048 ]]
then
log_info "SSH key validated ($key_type, $bits bits)"
return 0
fi
log_error "RSA key must be >= 2048 bits (current: $bits)"
return 1
;;
*)log_error "Unsupported key type: $key_type"
return 1
esac
}
validate_disk_space(){
local path="${1:-/root}"
local min_required_mb="${2:-$MIN_DISK_SPACE_MB}"
local available_mb
available_mb=$(df -m "$path" 2>/dev/null|awk 'NR==2 {print $4}')
if [[ -z $available_mb ]];then
log_error "Could not determine disk space for $path"
return 1
fi
declare -g DISK_SPACE_MB="$available_mb"
if [[ $available_mb -lt $min_required_mb ]];then
log_error "Insufficient disk space: ${available_mb}MB available, ${min_required_mb}MB required"
return 1
fi
log_info "Disk space OK: ${available_mb}MB available (${min_required_mb}MB required)"
return 0
}
validate_tailscale_key(){
local key="$1"
[[ -z $key ]]&&return 1
if [[ $key =~ ^tskey-(auth|client)-[a-zA-Z0-9]+-[a-zA-Z0-9]+$ ]];then
return 0
fi
return 1
}
_zfs_functional(){
zpool version &>/dev/null
}
_install_zfs_if_needed(){
if _zfs_functional;then
log_info "ZFS already installed and functional"
return 0
fi
log_info "ZFS not functional, attempting installation..."
if cmd_exists zpool;then
log_info "Found zpool wrapper, triggering ZFS compilation..."
timeout 90 bash -c 'echo "y" | zpool version' &>/dev/null||true
if _zfs_functional;then
log_info "ZFS compiled successfully via wrapper"
return 0
fi
fi
local install_dir="${INSTALL_DIR:-${HOME:-/root}}"
local zfs_scripts=(
"$install_dir/.oldroot/nfs/install/zfs.sh"
"$install_dir/zfs-install.sh"
"/usr/local/bin/install-zfs")
for script in "${zfs_scripts[@]}";do
if [[ -x $script ]];then
log_info "Running ZFS install script: $script"
timeout 90 bash -c 'echo "y" | "$1"' _ "$script" >/dev/null 2>&1||true
if _zfs_functional;then
log_info "ZFS installed successfully via $script"
return 0
fi
fi
done
if [[ -f /etc/debian_version ]];then
log_info "Trying apt install zfsutils-linux..."
timeout 120 apt-get install -qq -y zfsutils-linux >/dev/null 2>&1||true
if _zfs_functional;then
log_info "ZFS installed via apt"
return 0
fi
fi
log_warn "Failed to install ZFS - existing pool detection unavailable"
}
_install_required_packages(){
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
[gum]="gum")
local packages_to_install=()
local need_charm_repo=false
for cmd in "${!required_commands[@]}";do
if ! cmd_exists "$cmd";then
packages_to_install+=("${required_commands[$cmd]}")
[[ $cmd == "gum" ]]&&need_charm_repo=true
fi
done
if [[ $need_charm_repo == true ]];then
mkdir -p /etc/apt/keyrings 2>/dev/null
curl -fsSL https://repo.charm.sh/apt/gpg.key 2>/dev/null|gpg --dearmor -o /etc/apt/keyrings/charm.gpg >/dev/null 2>&1
printf '%s\n' "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" >/etc/apt/sources.list.d/charm.list 2>/dev/null
fi
if [[ ${#packages_to_install[@]} -gt 0 ]];then
apt-get update -qq >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive timeout 120 apt-get install -qq -y "${packages_to_install[@]}" >/dev/null 2>&1
fi
_install_zfs_if_needed
}
install_base_packages(){
local packages=($SYSTEM_UTILITIES $OPTIONAL_PACKAGES usrmerge locales chrony unattended-upgrades apt-listchanges linux-cpupower)
[[ ${SHELL_TYPE:-bash} == "zsh" ]]&&packages+=(zsh git)
local pkg_list&&printf -v pkg_list '"%s" ' "${packages[@]}"
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
    apt-get install -yqq $pkg_list
    apt-get autoremove -yqq
    apt-get clean
    set +e
    pveupgrade 2>/dev/null || echo 'pveupgrade check skipped' >&2
    pveam update 2>/dev/null || echo 'pveam update skipped' >&2
  " "System packages installed"
log_subtasks "${packages[@]}"
}
batch_install_packages(){
local packages=()
[[ $INSTALL_FIREWALL == "yes" ]]&&packages+=(nftables)
if [[ $INSTALL_FIREWALL == "yes" && ${FIREWALL_MODE:-standard} != "stealth" ]];then
packages+=(fail2ban)
fi
[[ $INSTALL_APPARMOR == "yes" ]]&&packages+=(apparmor apparmor-utils)
[[ $INSTALL_AUDITD == "yes" ]]&&packages+=(auditd audispd-plugins)
[[ $INSTALL_AIDE == "yes" ]]&&packages+=(aide aide-common)
[[ $INSTALL_CHKROOTKIT == "yes" ]]&&packages+=(chkrootkit binutils)
[[ $INSTALL_LYNIS == "yes" ]]&&packages+=(lynis)
[[ $INSTALL_NEEDRESTART == "yes" ]]&&packages+=(needrestart)
[[ $INSTALL_VNSTAT == "yes" ]]&&packages+=(vnstat)
[[ $INSTALL_PROMTAIL == "yes" ]]&&packages+=(promtail)
[[ $INSTALL_NETDATA == "yes" ]]&&packages+=(netdata)
[[ $INSTALL_NVIM == "yes" ]]&&packages+=(neovim)
[[ $INSTALL_RINGBUFFER == "yes" ]]&&packages+=(ethtool)
[[ $INSTALL_YAZI == "yes" ]]&&packages+=(yazi ffmpeg 7zip jq poppler-utils fd-find ripgrep fzf zoxide imagemagick)
[[ $INSTALL_TAILSCALE == "yes" ]]&&packages+=(tailscale)
[[ ${SSL_TYPE:-self-signed} == "letsencrypt" ]]&&packages+=(certbot)
if [[ ${#packages[@]} -eq 0 ]];then
log_info "No optional packages to install"
return 0
fi
local pkg_list&&printf -v pkg_list '"%s" ' "${packages[@]}"
log_info "Batch installing packages: ${packages[*]}"
local repo_setup='
    DEBIAN_CODENAME=$(grep -oP "VERSION_CODENAME=\K\w+" /etc/os-release 2>/dev/null || echo "bookworm")
  '
if [[ $INSTALL_TAILSCALE == "yes" ]];then
repo_setup+='
      curl -fsSL "https://pkgs.tailscale.com/stable/debian/${DEBIAN_CODENAME}.noarmor.gpg" | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
      curl -fsSL "https://pkgs.tailscale.com/stable/debian/${DEBIAN_CODENAME}.tailscale-keyring.list" | tee /etc/apt/sources.list.d/tailscale.list
    '
fi
if [[ $INSTALL_NETDATA == "yes" ]];then
repo_setup+='
      curl -fsSL https://repo.netdata.cloud/netdatabot.gpg.key | gpg --dearmor -o /usr/share/keyrings/netdata-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/netdata-archive-keyring.gpg] https://repo.netdata.cloud/repos/stable/debian/ ${DEBIAN_CODENAME}/" > /etc/apt/sources.list.d/netdata.list
    '
fi
if [[ $INSTALL_PROMTAIL == "yes" ]];then
repo_setup+='
      curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor -o /usr/share/keyrings/grafana-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/grafana-archive-keyring.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list
    '
fi
if [[ $INSTALL_YAZI == "yes" ]];then
repo_setup+='
      curl -fsSL https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpg
      echo "deb https://debian.griffo.io/apt ${DEBIAN_CODENAME} main" > /etc/apt/sources.list.d/debian.griffo.io.list
    '
fi
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
      apt-get install -yqq '"$pkg_list"'
    ' "Packages installed"
log_subtasks "${packages[@]}"
return 0
}
_check_root_access(){
if [[ $EUID -ne 0 ]];then
declare -g PREFLIGHT_ROOT="✗ Not root"
declare -g PREFLIGHT_ROOT_STATUS="error"
return 1
else
declare -g PREFLIGHT_ROOT="Running as root"
declare -g PREFLIGHT_ROOT_STATUS="ok"
return 0
fi
}
_check_internet(){
if ping -c 1 -W 3 "$DNS_PRIMARY" >/dev/null 2>&1;then
declare -g PREFLIGHT_NET="Available"
declare -g PREFLIGHT_NET_STATUS="ok"
return 0
else
declare -g PREFLIGHT_NET="No connection"
declare -g PREFLIGHT_NET_STATUS="error"
return 1
fi
}
_check_disk_space(){
if validate_disk_space "/root" "$MIN_DISK_SPACE_MB";then
declare -g PREFLIGHT_DISK="$DISK_SPACE_MB MB"
declare -g PREFLIGHT_DISK_STATUS="ok"
return 0
else
declare -g PREFLIGHT_DISK="${DISK_SPACE_MB:-0} MB (need ${MIN_DISK_SPACE_MB}MB+)"
declare -g PREFLIGHT_DISK_STATUS="error"
return 1
fi
}
_check_ram(){
local total_ram_mb
total_ram_mb=$(free -m|awk '/^Mem:/{print $2}')
if [[ $total_ram_mb -ge $MIN_RAM_MB ]];then
declare -g PREFLIGHT_RAM="$total_ram_mb MB"
declare -g PREFLIGHT_RAM_STATUS="ok"
return 0
else
declare -g PREFLIGHT_RAM="$total_ram_mb MB (need ${MIN_RAM_MB}MB+)"
declare -g PREFLIGHT_RAM_STATUS="error"
return 1
fi
}
_check_cpu(){
local cpu_cores
cpu_cores=$(nproc)
if [[ $cpu_cores -ge 2 ]];then
declare -g PREFLIGHT_CPU="$cpu_cores cores"
declare -g PREFLIGHT_CPU_STATUS="ok"
else
declare -g PREFLIGHT_CPU="$cpu_cores core(s)"
declare -g PREFLIGHT_CPU_STATUS="warn"
fi
}
_check_kvm(){
if [[ ! -e /dev/kvm ]];then
modprobe kvm 2>/dev/null||true
if grep -q "Intel" /proc/cpuinfo 2>/dev/null;then
modprobe kvm_intel 2>/dev/null||true
elif grep -q "AMD" /proc/cpuinfo 2>/dev/null;then
modprobe kvm_amd 2>/dev/null||true
else
modprobe kvm_intel 2>/dev/null||modprobe kvm_amd 2>/dev/null||true
fi
local retries=6
while [[ ! -e /dev/kvm && $retries -gt 0 ]];do
sleep 0.5
((retries--))
done
fi
if [[ -e /dev/kvm ]];then
declare -g PREFLIGHT_KVM="Available"
declare -g PREFLIGHT_KVM_STATUS="ok"
return 0
else
declare -g PREFLIGHT_KVM="Not available"
declare -g PREFLIGHT_KVM_STATUS="error"
return 1
fi
}
_run_preflight_checks(){
local errors=0
_check_root_access||((errors++))
_check_internet||((errors++))
_check_disk_space||((errors++))
_check_ram||((errors++))
_check_cpu
_check_kvm||((errors++))
declare -g PREFLIGHT_ERRORS="$errors"
}
collect_system_info(){
_install_required_packages
_run_preflight_checks
_detect_default_interface
_detect_predictable_name
_detect_available_interfaces
if ! _detect_ipv4;then
log_warn "IPv4 detection failed - network config will require manual configuration"
fi
_detect_ipv6_and_mac
_load_wizard_data
}
_detect_default_interface(){
if cmd_exists ip&&cmd_exists jq;then
declare -g CURRENT_INTERFACE="$(ip -j route 2>/dev/null|jq -r '.[] | select(.dst == "default") | .dev'|head -n1)"
elif cmd_exists ip;then
declare -g CURRENT_INTERFACE="$(ip route|grep default|awk '{print $5}'|head -n1)"
elif cmd_exists route;then
declare -g CURRENT_INTERFACE="$(route -n|awk '/^0\.0\.0\.0/ {print $8}'|head -n1)"
fi
if [[ -z $CURRENT_INTERFACE ]];then
if cmd_exists ip&&cmd_exists jq;then
declare -g CURRENT_INTERFACE="$(ip -j link show 2>/dev/null|jq -r '.[] | select(.ifname != "lo" and .operstate == "UP") | .ifname'|head -n1)"
elif cmd_exists ip;then
declare -g CURRENT_INTERFACE="$(ip link show|awk -F': ' '/^[0-9]+:/ && !/lo:/ {print $2; exit}')"
elif cmd_exists ifconfig;then
declare -g CURRENT_INTERFACE="$(ifconfig -a|awk '/^[a-z]/ && !/^lo/ {print $1; exit}'|tr -d ':')"
fi
fi
if [[ -z $CURRENT_INTERFACE ]];then
declare -g CURRENT_INTERFACE="eth0"
log_warn "Could not detect network interface, defaulting to eth0"
fi
}
_detect_predictable_name(){
declare -g PREDICTABLE_NAME=""
if [[ -e "/sys/class/net/$CURRENT_INTERFACE" ]];then
local udev_info
udev_info=$(udevadm info "/sys/class/net/$CURRENT_INTERFACE" 2>/dev/null)
declare -g PREDICTABLE_NAME="$(printf '%s\n' "$udev_info"|grep "ID_NET_NAME_MAC="|cut -d'=' -f2)"
if [[ -z $PREDICTABLE_NAME ]];then
declare -g PREDICTABLE_NAME="$(printf '%s\n' "$udev_info"|grep "ID_NET_NAME_PATH="|cut -d'=' -f2)"
fi
if [[ -z $PREDICTABLE_NAME ]];then
declare -g PREDICTABLE_NAME="$(printf '%s\n' "$udev_info"|grep "ID_NET_NAME_ONBOARD="|cut -d'=' -f2)"
fi
if [[ -z $PREDICTABLE_NAME ]];then
declare -g PREDICTABLE_NAME="$(ip -d link show "$CURRENT_INTERFACE" 2>/dev/null|grep "altname"|awk '{print $2}'|head -1)"
fi
fi
if [[ -n $PREDICTABLE_NAME ]];then
declare -g DEFAULT_INTERFACE="$PREDICTABLE_NAME"
else
declare -g DEFAULT_INTERFACE="$CURRENT_INTERFACE"
fi
}
_get_mac_based_name(){
local iface="$1"
local udev_info mac_name
if [[ -e "/sys/class/net/$iface" ]];then
udev_info=$(udevadm info "/sys/class/net/$iface" 2>/dev/null)
mac_name=$(printf '%s\n' "$udev_info"|grep "ID_NET_NAME_MAC="|cut -d'=' -f2)
if [[ -n $mac_name ]];then
printf '%s' "$mac_name"
return 0
fi
mac_name=$(printf '%s\n' "$udev_info"|grep "ID_NET_NAME_PATH="|cut -d'=' -f2)
if [[ -n $mac_name ]];then
printf '%s' "$mac_name"
return 0
fi
fi
printf '%s' "$iface"
}
_detect_available_interfaces(){
declare -g AVAILABLE_ALTNAMES=$(ip -d link show|grep -v "lo:"|grep -E '(^[0-9]+:|altname)'|awk '/^[0-9]+:/ {interface=$2; gsub(/:/, "", interface); printf "%s", interface} /altname/ {printf ", %s", $2} END {print ""}'|sed 's/, $//')
local raw_interfaces
if cmd_exists ip&&cmd_exists jq;then
raw_interfaces=$(ip -j link show 2>/dev/null|jq -r '.[] | select(.ifname != "lo") | .ifname'|sort)
elif cmd_exists ip;then
raw_interfaces=$(ip link show|awk -F': ' '/^[0-9]+:/ && !/lo:/ {print $2}'|sort)
else
raw_interfaces="$CURRENT_INTERFACE"
fi
declare -g AVAILABLE_INTERFACES=""
local iface mac_name
while IFS= read -r iface;do
[[ -z $iface ]]&&continue
mac_name=$(_get_mac_based_name "$iface")
if [[ -n $AVAILABLE_INTERFACES ]];then
declare -g AVAILABLE_INTERFACES="$AVAILABLE_INTERFACES"$'\n'"$mac_name"
else
declare -g AVAILABLE_INTERFACES="$mac_name"
fi
done <<<"$raw_interfaces"
declare -g INTERFACE_COUNT="$(printf '%s\n' "$AVAILABLE_INTERFACES"|wc -l)"
if [[ -z $INTERFACE_NAME ]];then
declare -g INTERFACE_NAME="$DEFAULT_INTERFACE"
fi
}
_detect_ipv4(){
local max_attempts="${SSH_RETRY_ATTEMPTS:-3}"
local attempt=0
while [[ $attempt -lt $max_attempts ]];do
attempt="$((attempt+1))"
if cmd_exists ip&&cmd_exists jq;then
declare -g MAIN_IPV4_CIDR="$(ip -j address show "$CURRENT_INTERFACE" 2>/dev/null|jq -r '.[0].addr_info[] | select(.family == "inet" and .scope == "global") | "\(.local)/\(.prefixlen)"'|head -n1)"
declare -g MAIN_IPV4="${MAIN_IPV4_CIDR%/*}"
declare -g MAIN_IPV4_GW="$(ip -j route 2>/dev/null|jq -r '.[] | select(.dst == "default") | .gateway'|head -n1)"
[[ -n $MAIN_IPV4 ]]&&[[ -n $MAIN_IPV4_GW ]]&&return 0
elif cmd_exists ip;then
declare -g MAIN_IPV4_CIDR="$(ip address show "$CURRENT_INTERFACE" 2>/dev/null|grep global|grep "inet "|awk '{print $2}'|head -n1)"
declare -g MAIN_IPV4="${MAIN_IPV4_CIDR%/*}"
declare -g MAIN_IPV4_GW="$(ip route 2>/dev/null|grep default|awk '{print $3}'|head -n1)"
[[ -n $MAIN_IPV4 ]]&&[[ -n $MAIN_IPV4_GW ]]&&return 0
elif cmd_exists ifconfig;then
declare -g MAIN_IPV4="$(ifconfig "$CURRENT_INTERFACE" 2>/dev/null|awk '/inet / {print $2}'|sed 's/addr://')"
local netmask
netmask=$(ifconfig "$CURRENT_INTERFACE" 2>/dev/null|awk '/inet / {print $4}'|sed 's/Mask://')
if [[ -n $MAIN_IPV4 ]]&&[[ -n $netmask ]];then
case "$netmask" in
255.255.255.0)declare -g MAIN_IPV4_CIDR="$MAIN_IPV4/24";;
255.255.255.128)declare -g MAIN_IPV4_CIDR="$MAIN_IPV4/25";;
255.255.255.192)declare -g MAIN_IPV4_CIDR="$MAIN_IPV4/26";;
255.255.255.224)declare -g MAIN_IPV4_CIDR="$MAIN_IPV4/27";;
255.255.255.240)declare -g MAIN_IPV4_CIDR="$MAIN_IPV4/28";;
255.255.255.248)declare -g MAIN_IPV4_CIDR="$MAIN_IPV4/29";;
255.255.255.252)declare -g MAIN_IPV4_CIDR="$MAIN_IPV4/30";;
255.255.0.0)declare -g MAIN_IPV4_CIDR="$MAIN_IPV4/16";;
*)declare -g MAIN_IPV4_CIDR="$MAIN_IPV4/24"
esac
fi
if cmd_exists route;then
declare -g MAIN_IPV4_GW="$(route -n 2>/dev/null|awk '/^0\.0\.0\.0/ {print $2}'|head -n1)"
fi
[[ -n $MAIN_IPV4 ]]&&[[ -n $MAIN_IPV4_GW ]]&&return 0
fi
if [[ $attempt -lt $max_attempts ]];then
log_info "Network info attempt $attempt failed, retrying in ${RETRY_DELAY_SECONDS:-2} seconds..."
sleep "${RETRY_DELAY_SECONDS:-2}"
fi
done
log_error "IPv4 detection failed after $max_attempts attempts"
return 1
}
_detect_ipv6_and_mac(){
if cmd_exists ip&&cmd_exists jq;then
declare -g MAC_ADDRESS="$(ip -j link show "$CURRENT_INTERFACE" 2>/dev/null|jq -r '.[0].address // empty')"
declare -g IPV6_CIDR="$(ip -j address show "$CURRENT_INTERFACE" 2>/dev/null|jq -r '.[0].addr_info[] | select(.family == "inet6" and .scope == "global") | "\(.local)/\(.prefixlen)"'|head -n1)"
elif cmd_exists ip;then
declare -g MAC_ADDRESS="$(ip link show "$CURRENT_INTERFACE" 2>/dev/null|awk '/ether/ {print $2}')"
declare -g IPV6_CIDR="$(ip address show "$CURRENT_INTERFACE" 2>/dev/null|grep global|grep "inet6 "|awk '{print $2}'|head -n1)"
elif cmd_exists ifconfig;then
declare -g MAC_ADDRESS="$(ifconfig "$CURRENT_INTERFACE" 2>/dev/null|awk '/ether/ {print $2}')"
declare -g IPV6_CIDR="$(ifconfig "$CURRENT_INTERFACE" 2>/dev/null|awk '/inet6/ && /global/ {print $2}')"
fi
declare -g MAIN_IPV6="${IPV6_CIDR%/*}"
if [[ -n $IPV6_CIDR ]];then
local ipv6_prefix
ipv6_prefix=$(printf '%s' "$MAIN_IPV6"|cut -d':' -f1-4)
declare -g FIRST_IPV6_CIDR="$ipv6_prefix:1::1/80"
else
declare -g FIRST_IPV6_CIDR=""
fi
if [[ -n $MAIN_IPV6 ]];then
if cmd_exists ip;then
declare -g IPV6_GATEWAY="$(ip -6 route 2>/dev/null|grep default|awk '{print $3}'|head -n1)"
fi
fi
}
detect_drives(){
mapfile -t DRIVES < <(lsblk -d -n -o NAME,TYPE|grep nvme|grep disk|awk '{print "/dev/"$1}'|sort)
declare -g DRIVE_COUNT="${#DRIVES[@]}"
if [[ $DRIVE_COUNT -eq 0 ]];then
mapfile -t DRIVES < <(lsblk -d -n -o NAME,TYPE|grep disk|grep -v loop|awk '{print "/dev/"$1}'|sort)
declare -g DRIVE_COUNT="${#DRIVES[@]}"
fi
declare -g -a DRIVE_NAMES=()
declare -g -a DRIVE_SIZES=()
declare -g -a DRIVE_MODELS=()
for drive in "${DRIVES[@]}";do
local name size model
name="$(basename "$drive")"
size="$(lsblk -d -n -o SIZE "$drive"|xargs)"
model="$(lsblk -d -n -o MODEL "$drive" 2>/dev/null|xargs||echo "Disk")"
DRIVE_NAMES+=("$name")
DRIVE_SIZES+=("$size")
DRIVE_MODELS+=("$model")
done
}
detect_disk_roles(){
[[ $DRIVE_COUNT -eq 0 ]]&&return 1
declare -g BOOT_DISK=""
declare -g -a ZFS_POOL_DISKS=()
log_info "Disk roles initialized (user selection required)"
log_info "Available drives: ${DRIVES[*]}"
}
detect_existing_pools(){
if ! cmd_exists zpool;then
log_warn "zpool not found - ZFS not installed in rescue"
return 0
fi
local pools=()
local import_output
import_output=$(zpool import -d /dev 2>&1)||true
if [[ -z $import_output ]]||[[ $import_output == *"no pools available"* ]];then
import_output=$(zpool import 2>&1)||true
fi
log_debug "zpool import output: ${import_output:-(empty)}"
if [[ -z $import_output ]]||[[ $import_output == *"no pools available"* ]];then
log_debug "No importable pools found"
return 0
fi
local current_pool=""
local current_state=""
local current_disks=""
local in_config=false
while IFS= read -r line;do
if [[ $line =~ ^[[:space:]]*pool:[[:space:]]*(.+)$ ]];then
if [[ -n $current_pool ]];then
pools+=("$current_pool|$current_state|$current_disks")
fi
current_pool="${BASH_REMATCH[1]}"
current_state=""
current_disks=""
in_config=false
elif [[ $line =~ ^[[:space:]]*state:[[:space:]]*(.+)$ ]];then
current_state="${BASH_REMATCH[1]}"
elif [[ $line =~ ^[[:space:]]*config: ]];then
in_config=true
elif [[ $in_config == true ]];then
if [[ $line =~ ^[[:space:]]+(nvme[0-9]+n[0-9]+|[shxv]d[a-z]+)[p0-9]*[[:space:]] ]];then
local disk="${BASH_REMATCH[1]}"
if [[ -n $current_disks ]];then
current_disks="$current_disks,/dev/$disk"
else
current_disks="/dev/$disk"
fi
fi
fi
done <<<"$import_output"
if [[ -n $current_pool ]];then
pools+=("$current_pool|$current_state|$current_disks")
fi
for pool in "${pools[@]}";do
printf '%s\n' "$pool"
done
}
get_pool_disks(){
local pool_name="$1"
for line in "${DETECTED_POOLS[@]}";do
local name="${line%%|*}"
if [[ $name == "$pool_name" ]];then
local rest="${line#*|}"
printf '%s\n' "${rest#*|}"
return 0
fi
done
return 1
}
DETECTED_POOLS=()
_load_timezones(){
if cmd_exists timedatectl;then
declare -g WIZ_TIMEZONES=$(timedatectl list-timezones 2>/dev/null)
else
declare -g WIZ_TIMEZONES=$(find /usr/share/zoneinfo -type f 2>/dev/null|sed 's|/usr/share/zoneinfo/||'|grep -E '^(Africa|America|Antarctica|Asia|Atlantic|Australia|Europe|Indian|Pacific)/'|sort)
fi
WIZ_TIMEZONES+=$'\nUTC'
}
_load_countries(){
local iso_file="/usr/share/iso-codes/json/iso_3166-1.json"
if [[ -f $iso_file ]];then
declare -g WIZ_COUNTRIES=$(grep -oP '"alpha_2":\s*"\K[^"]+' "$iso_file"|tr '[:upper:]' '[:lower:]'|sort)
else
declare -g WIZ_COUNTRIES=$(locale -a 2>/dev/null|grep -oP '^[a-z]{2}(?=_)'|sort -u)
fi
}
_build_tz_to_country(){
declare -gA TZ_TO_COUNTRY
local zone_tab="/usr/share/zoneinfo/zone.tab"
[[ -f $zone_tab ]]||return 0
while IFS=$'\t' read -r country _ tz _;do
[[ $country == \#* ]]&&continue
[[ -z $tz ]]&&continue
TZ_TO_COUNTRY["$tz"]="${country,,}"
done <"$zone_tab"
}
_detect_pools(){
declare -g -a DETECTED_POOLS=()
local pool_output
pool_output=$(detect_existing_pools 2>&1)
while IFS= read -r line;do
[[ $line == *"|"* ]]&&DETECTED_POOLS+=("$line")
done <<<"$pool_output"
if [[ ${#DETECTED_POOLS[@]} -gt 0 ]];then
log_info "Detected ${#DETECTED_POOLS[@]} existing ZFS pool(s):"
for pool in "${DETECTED_POOLS[@]}";do
log_info "  - $pool"
done
else
log_info "No existing ZFS pools detected"
fi
}
_load_wizard_data(){
_load_timezones
_load_countries
_build_tz_to_country
_detect_pools
}
show_system_status(){
detect_drives
detect_disk_roles
local no_drives=0
if [[ $DRIVE_COUNT -eq 0 ]];then
no_drives=1
fi
local has_errors=false
if [[ $PREFLIGHT_ERRORS -gt 0 || $no_drives -eq 1 ]];then
has_errors=true
fi
if [[ $has_errors == false ]];then
_wiz_start_edit
return 0
fi
local table_data
table_data=",,
Status,Item,Value
"
format_status(){
local status="$1"
case "$status" in
ok)gum style --foreground "$HEX_CYAN" "[OK]";;
warn)gum style --foreground "$HEX_YELLOW" "[WARN]";;
error)gum style --foreground "$HEX_RED" "[ERROR]"
esac
}
add_row(){
local status="$1"
local label="$2"
local value="$3"
local status_text
status_text=$(format_status "$status")
table_data+="$status_text,$label,$value
"
}
add_row "$PREFLIGHT_ROOT_STATUS" "Root Access" "$PREFLIGHT_ROOT"
add_row "$PREFLIGHT_NET_STATUS" "Internet" "$PREFLIGHT_NET"
add_row "$PREFLIGHT_DISK_STATUS" "Temp Space" "$PREFLIGHT_DISK"
add_row "$PREFLIGHT_RAM_STATUS" "RAM" "$PREFLIGHT_RAM"
add_row "$PREFLIGHT_CPU_STATUS" "CPU" "$PREFLIGHT_CPU"
add_row "$PREFLIGHT_KVM_STATUS" "KVM" "$PREFLIGHT_KVM"
if [[ $no_drives -eq 1 ]];then
local error_status
error_status=$(format_status "error")
table_data+="$error_status,No drives detected!,
"
else
for i in "${!DRIVE_NAMES[@]}";do
local ok_status
ok_status=$(format_status "ok")
table_data+="$ok_status,${DRIVE_NAMES[$i]},${DRIVE_SIZES[$i]}  ${DRIVE_MODELS[$i]:0:25}
"
done
fi
table_data="${table_data%$'\n'}"
printf '%s\n' "$table_data"|gum table \
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
get_terminal_dimensions(){
if [[ -t 1 && -n ${TERM:-} ]];then
_LOG_TERM_HEIGHT="$(tput lines 2>/dev/null)"
_LOG_TERM_WIDTH="$(tput cols 2>/dev/null)"
fi
[[ $_LOG_TERM_HEIGHT =~ ^[0-9]+$ ]]||_LOG_TERM_HEIGHT=24
[[ $_LOG_TERM_WIDTH =~ ^[0-9]+$ ]]||_LOG_TERM_WIDTH=80
}
LOGO_HEIGHT=${BANNER_HEIGHT:-9}
HEADER_HEIGHT=4
calculate_log_area(){
get_terminal_dimensions
declare -g LOG_AREA_HEIGHT="$((_LOG_TERM_HEIGHT-LOGO_HEIGHT-HEADER_HEIGHT-1))"
}
declare -a LOG_LINES=()
LOG_COUNT=0
add_log(){
local message="$1"
LOG_LINES+=("$message")
((LOG_COUNT++))
render_logs
}
_render_install_header(){
printf '\033[%d;0H' "$((LOGO_HEIGHT+1))"
format_wizard_header "Installing Proxmox"
_wiz_blank_line
_wiz_blank_line
} >/dev/tty 2>/dev/null
render_logs(){
_render_install_header
local start_line=0
local lines_printed=0
if ((LOG_COUNT>LOG_AREA_HEIGHT));then
start_line="$((LOG_COUNT-LOG_AREA_HEIGHT))"
fi
for ((i=start_line; i<LOG_COUNT; i++));do
printf '%s\033[K\n' "${LOG_LINES[$i]}"
((lines_printed++))
done
local remaining="$((LOG_AREA_HEIGHT-lines_printed))"
for ((i=0; i<remaining; i++));do
printf '\033[K\n'
done
} >/dev/tty 2>/dev/null
start_task(){
local message="$1"
add_log "$message..."
declare -g TASK_INDEX="$((LOG_COUNT-1))"
}
complete_task(){
local task_index="$1"
local message="$2"
local status="${3:-success}"
local indicator
case "$status" in
error)indicator="$CLR_RED✗$CLR_RESET";;
warning)indicator="$CLR_YELLOW⚠$CLR_RESET";;
*)indicator="$CLR_CYAN✓$CLR_RESET"
esac
LOG_LINES[task_index]="$message $indicator"
render_logs
}
add_subtask_log(){
local message="$1"
local color="${2:-$CLR_GRAY}"
add_log "$TREE_VERT   $color$message$CLR_RESET"
}
start_live_installation(){
show_progress(){
live_show_progress "$@"
}
calculate_log_area
tput smcup
tput civis
_wiz_clear
show_banner
trap 'ec=$?; tput cnorm 2>/dev/null; tput rmcup 2>/dev/null; (exit $ec); cleanup_and_error_handler' EXIT
}
finish_live_installation(){
tput cnorm
tput rmcup
}
live_show_progress(){
local pid="$1"
local message="${2:-Processing}"
local done_message="${3:-$message}"
local silent=false
[[ ${3:-} == "--silent" || ${4:-} == "--silent" ]]&&silent=true
[[ ${3:-} == "--silent" ]]&&done_message="$message"
start_task "$TREE_BRANCH $message"
local task_idx="$TASK_INDEX"
local animation_counter=0
while kill -0 "$pid" 2>/dev/null;do
sleep 0.3
local dots_count="$(((animation_counter%3)+1))"
local dots=""
for ((d=0; d<dots_count; d++));do dots+=".";done
LOG_LINES[task_idx]="$TREE_BRANCH $message$CLR_ORANGE$dots$CLR_RESET"
render_logs
((animation_counter++))
done
wait "$pid" 2>/dev/null
local exit_code="$?"
if [[ $exit_code -eq 0 ]];then
if [[ $silent != true ]];then
complete_task "$task_idx" "$TREE_BRANCH $done_message"
else
unset 'LOG_LINES[task_idx]'
LOG_LINES=("${LOG_LINES[@]}")
((LOG_COUNT--))
render_logs
fi
else
complete_task "$task_idx" "$TREE_BRANCH $message" "error"
fi
return $exit_code
}
live_log_subtask(){
local message="$1"
add_subtask_log "$message"
}
log_subtasks(){
local max_width=55
local current_line=""
local first=true
for item in "$@";do
local addition
if [[ $first == true ]];then
addition="$item"
first=false
else
addition=", $item"
fi
if [[ $((${#current_line}+${#addition})) -gt $max_width && -n $current_line ]];then
add_subtask_log "$current_line,"
current_line="$item"
else
current_line+="$addition"
fi
done
if [[ -n $current_line ]];then
add_subtask_log "$current_line"
fi
}
_wizard_main(){
local selection=0
while true;do
_wiz_render_menu "$selection"
_wiz_read_key
case "$WIZ_KEY" in
up)if
[[ $selection -gt 0 ]]
then
((selection--))
fi
;;
down)if
[[ $selection -lt $((_WIZ_FIELD_COUNT-1)) ]]
then
((selection++))
fi
;;
left)if
[[ $WIZ_CURRENT_SCREEN -gt 0 ]]
then
((WIZ_CURRENT_SCREEN--))
selection=0
fi
;;
right)if
[[ $WIZ_CURRENT_SCREEN -lt $((${#WIZ_SCREENS[@]}-1)) ]]
then
((WIZ_CURRENT_SCREEN++))
selection=0
fi
;;
enter)_wiz_show_cursor
local field_name="${_WIZ_FIELD_MAP[$selection]:-}"
if [[ -z $field_name ]];then
log_warn "No field mapped for selection $selection"
else
case "$field_name" in
hostname)_edit_hostname;;
email)_edit_email;;
password)_edit_password;;
timezone)_edit_timezone;;
keyboard)_edit_keyboard;;
country)_edit_country;;
iso_version)_edit_iso_version;;
repository)_edit_repository;;
interface)_edit_interface;;
bridge_mode)_edit_bridge_mode;;
private_subnet)_edit_private_subnet;;
bridge_mtu)_edit_bridge_mtu;;
ipv6)_edit_ipv6;;
firewall)_edit_firewall;;
boot_disk)_edit_boot_disk;;
wipe_disks)_edit_wipe_disks;;
existing_pool)_edit_existing_pool;;
pool_disks)_edit_pool_disks;;
zfs_mode)_edit_zfs_mode;;
zfs_arc)_edit_zfs_arc;;
tailscale)_edit_tailscale;;
ssl)_edit_ssl;;
postfix)_edit_postfix;;
shell)_edit_shell;;
power_profile)_edit_power_profile;;
security)_edit_features_security;;
monitoring)_edit_features_monitoring;;
tools)_edit_features_tools;;
api_token)_edit_api_token;;
admin_username)_edit_admin_username;;
admin_password)_edit_admin_password;;
ssh_key)_edit_ssh_key;;
*)log_warn "Unknown field name: $field_name"
esac
fi
_wiz_hide_cursor
;;
start)return 0
;;
quit|esc)_wiz_start_edit
_wiz_show_cursor
if _wiz_confirm "Quit installation?" --default=false;then
tput rmcup 2>/dev/null||true
clear
tput cnorm 2>/dev/null||true
exit 0
fi
_wiz_hide_cursor
esac
done
}
_show_input_footer(){
local type="${1:-input}"
local component_lines="${2:-1}"
local -r footer_fixed_lines=2
local i
for ((i=0; i<component_lines; i++));do
_wiz_blank_line
done
_wiz_blank_line
local footer_text
case "$type" in
filter)footer_text="$CLR_GRAY[$CLR_ORANGE↑↓$CLR_GRAY] navigate  [${CLR_ORANGE}Enter$CLR_GRAY] select  [${CLR_ORANGE}Esc$CLR_GRAY] cancel$CLR_RESET"
;;
checkbox)footer_text="$CLR_GRAY[$CLR_ORANGE↑↓$CLR_GRAY] navigate  [${CLR_ORANGE}Space$CLR_GRAY] toggle  [${CLR_ORANGE}Enter$CLR_GRAY] confirm  [${CLR_ORANGE}Esc$CLR_GRAY] cancel$CLR_RESET"
;;
*)footer_text="$CLR_GRAY[${CLR_ORANGE}Enter$CLR_GRAY] confirm  [${CLR_ORANGE}Esc$CLR_GRAY] cancel$CLR_RESET"
esac
printf '%s\n' "$(_wiz_center "$footer_text")"
tput cuu $((component_lines+footer_fixed_lines))
}
_validate_config(){
_wiz_config_complete&&return 0
local missing_fields=()
[[ -z $PVE_HOSTNAME ]]&&missing_fields+=("Hostname")
[[ -z $DOMAIN_SUFFIX ]]&&missing_fields+=("Domain")
[[ -z $EMAIL ]]&&missing_fields+=("Email")
[[ -z $NEW_ROOT_PASSWORD ]]&&missing_fields+=("Root Password")
[[ -z $ADMIN_USERNAME ]]&&missing_fields+=("Admin Username")
[[ -z $ADMIN_PASSWORD ]]&&missing_fields+=("Admin Password")
[[ -z $TIMEZONE ]]&&missing_fields+=("Timezone")
[[ -z $KEYBOARD ]]&&missing_fields+=("Keyboard")
[[ -z $COUNTRY ]]&&missing_fields+=("Country")
[[ -z $PROXMOX_ISO_VERSION ]]&&missing_fields+=("Proxmox Version")
[[ -z $PVE_REPO_TYPE ]]&&missing_fields+=("Repository")
[[ -z $INTERFACE_NAME ]]&&missing_fields+=("Network Interface")
[[ -z $MAIN_IPV4 ]]&&missing_fields+=("IPv4 Address")
[[ -z $MAIN_IPV4_GW ]]&&missing_fields+=("IPv4 Gateway")
[[ -z $BRIDGE_MODE ]]&&missing_fields+=("Bridge mode")
[[ $BRIDGE_MODE != "external" && -z $PRIVATE_SUBNET ]]&&missing_fields+=("Private subnet")
[[ -z $IPV6_MODE ]]&&missing_fields+=("IPv6")
if [[ $USE_EXISTING_POOL == "yes" ]];then
[[ -z $EXISTING_POOL_NAME ]]&&missing_fields+=("Existing pool name")
else
[[ -z $ZFS_RAID ]]&&missing_fields+=("ZFS mode")
[[ ${#ZFS_POOL_DISKS[@]} -eq 0 ]]&&missing_fields+=("Pool disks")
validate_pool_disk_conflict&&missing_fields+=("Pool disks (boot disk conflict)")
validate_raid_disk_count&&missing_fields+=("ZFS mode (requires $(get_raid_min_disks "$ZFS_RAID")+ disks)")
fi
[[ -z $ZFS_ARC_MODE ]]&&missing_fields+=("ZFS ARC")
[[ -z $SHELL_TYPE ]]&&missing_fields+=("Shell")
[[ -z $CPU_GOVERNOR ]]&&missing_fields+=("Power profile")
[[ -z $SSH_PUBLIC_KEY ]]&&missing_fields+=("SSH Key")
[[ $INSTALL_TAILSCALE != "yes" && -z $SSL_TYPE ]]&&missing_fields+=("SSL Certificate")
[[ $FIREWALL_MODE == "stealth" && $INSTALL_TAILSCALE != "yes" ]]&&missing_fields+=("Tailscale (required for Stealth firewall)")
if [[ $INSTALL_POSTFIX == "yes" ]];then
[[ -z $SMTP_RELAY_HOST || -z $SMTP_RELAY_USER || -z $SMTP_RELAY_PASSWORD ]]&&missing_fields+=("Postfix SMTP relay settings")
fi
if [[ ${#missing_fields[@]} -gt 0 ]];then
_wiz_start_edit
_wiz_hide_cursor
_wiz_error --bold "Configuration incomplete!"
_wiz_blank_line
_wiz_warn "Please configure the following required fields:"
_wiz_blank_line
for field in "${missing_fields[@]}";do
printf '%s\n' "  $CLR_CYAN•$CLR_RESET $field"
done
_wiz_blank_line
_wiz_show_cursor
_wiz_confirm "Return to configuration?" --default=true||exit 1
_wiz_hide_cursor
return 1
fi
return 0
}
show_gum_config_editor(){
tput smcup
_wiz_hide_cursor
trap 'ec=$?; _wiz_show_cursor; tput rmcup 2>/dev/null; (exit $ec); cleanup_and_error_handler' EXIT
while true;do
_wizard_main
if _validate_config;then
break
fi
done
}
WIZ_NOTIFY_INDENT="   "
_wiz_hide_cursor(){ printf '\033[?25l';}
_wiz_show_cursor(){ printf '\033[?25h';}
_wiz_blank_line(){ printf '\n';}
_wiz_error(){
local flags=()
while [[ ${1:-} == --* ]];do
flags+=("$1")
shift
done
gum style --foreground "$HEX_RED" "${flags[@]}" "$WIZ_NOTIFY_INDENT✗ $*"
}
_wiz_warn(){
local flags=()
while [[ ${1:-} == --* ]];do
flags+=("$1")
shift
done
gum style --foreground "$HEX_YELLOW" "${flags[@]}" "$WIZ_NOTIFY_INDENT$*"
}
_wiz_info(){
local flags=()
while [[ ${1:-} == --* ]];do
flags+=("$1")
shift
done
gum style --foreground "$HEX_CYAN" "${flags[@]}" "$WIZ_NOTIFY_INDENT✓ $*"
}
_wiz_dim(){
local flags=()
while [[ ${1:-} == --* ]];do
flags+=("$1")
shift
done
gum style --foreground "$HEX_GRAY" "${flags[@]}" "$WIZ_NOTIFY_INDENT$*"
}
_wiz_description(){
local output=""
for line in "$@";do
line="${line//\{\{cyan:/$CLR_CYAN}"
line="${line//\{\{yellow:/$CLR_YELLOW}"
line="${line//\}\}/$CLR_GRAY}"
output+="$CLR_GRAY$line$CLR_RESET\n"
done
printf '%b' "$output"
}
_wiz_confirm(){
local prompt="$1"
shift
local content_width left_pad
content_width="$((${#prompt}>15?${#prompt}:15))"
left_pad="$(((TERM_WIDTH-content_width)/2))"
((left_pad<0))&&left_pad=0
local footer_text
footer_text="$CLR_GRAY[$CLR_ORANGE←→$CLR_GRAY] toggle  [${CLR_ORANGE}Enter$CLR_GRAY] submit  [${CLR_ORANGE}Y$CLR_GRAY] yes  [${CLR_ORANGE}N$CLR_GRAY] no$CLR_RESET"
_wiz_blank_line
_wiz_blank_line
printf '%s\n' "$(_wiz_center "$footer_text")"
tput cuu 5
gum confirm "$prompt" "$@" \
--no-show-help \
--padding "0 0 0 $left_pad" \
--prompt.foreground "$HEX_ORANGE" \
--selected.background "$HEX_ORANGE"
}
_wiz_choose(){
gum choose \
--padding "0 0 0 1" \
--header.foreground "$HEX_CYAN" \
--cursor "$CLR_ORANGE›$CLR_RESET " \
--cursor.foreground "$HEX_NONE" \
--item.foreground "$HEX_WHITE" \
--selected.foreground "$HEX_WHITE" \
--no-show-help \
"$@"
}
_wiz_choose_multi(){
gum choose \
--no-limit \
--padding "0 0 0 1" \
--header.foreground "$HEX_CYAN" \
--cursor "$CLR_ORANGE›$CLR_RESET " \
--cursor.foreground "$HEX_NONE" \
--cursor-prefix "◦ " \
--selected.foreground "$HEX_WHITE" \
--selected-prefix "$CLR_CYAN✓$CLR_RESET " \
--unselected-prefix "◦ " \
--no-show-help \
"$@"
}
_wiz_input(){
gum input \
--padding "0 0 0 1" \
--prompt.foreground "$HEX_CYAN" \
--cursor.foreground "$HEX_ORANGE" \
--no-show-help \
"$@"
}
_wiz_filter(){
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
_wiz_clear(){
printf '\033[H\033[J'
}
_wiz_start_edit(){
_wiz_clear
show_banner
_wiz_blank_line
}
_wiz_input_screen(){
_wiz_start_edit
for line in "$@";do
_wiz_dim "$line"
done
[[ $# -gt 0 ]]&&printf '\n'
_show_input_footer
}
_wiz_fmt(){
local value="$1"
local placeholder="${2:-→ set value}"
if [[ -n $value ]];then
printf '%s\n' "$value"
else
printf '%s\n' "$CLR_GRAY$placeholder$CLR_RESET"
fi
}
show_validation_error(){
local message="$1"
_wiz_hide_cursor
_wiz_error "$message"
sleep "${WIZARD_MESSAGE_DELAY:-3}"
}
WIZ_SCREENS=("Basic" "Proxmox" "Network" "Storage" "Services" "Access")
WIZ_CURRENT_SCREEN=0
_NAV_COL_WIDTH=10
_wiz_center(){
local text="$1"
local term_width
term_width="$(tput cols 2>/dev/null||echo 80)"
local visible_text
visible_text="$(printf '%s' "$text"|sed $'s/\e\\[[0-9;]*m//g')"
local text_len="${#visible_text}"
local padding="$(((term_width-text_len)/2))"
((padding<0))&&padding=0
printf '%*s%s' "$padding" "" "$text"
}
_nav_repeat(){
local char="$1" count="$2" i
for ((i=0; i<count; i++));do
printf '%s' "$char"
done
}
_nav_color(){
local idx="$1" current="$2"
if [[ $idx -eq $current ]];then
printf '%s\n' "$CLR_ORANGE"
elif [[ $idx -lt $current ]];then
printf '%s\n' "$CLR_CYAN"
else
printf '%s\n' "$CLR_GRAY"
fi
}
_nav_dot(){
local idx="$1" current="$2"
if [[ $idx -eq $current ]];then
printf '%s\n' "◉"
elif [[ $idx -lt $current ]];then
printf '%s\n' "●"
else
printf '%s\n' "○"
fi
}
_nav_line(){
local idx="$1" current="$2" len="$3"
if [[ $idx -lt $current ]];then
_nav_repeat "━" "$len"
else
_nav_repeat "─" "$len"
fi
}
_wiz_render_nav(){
local current="$WIZ_CURRENT_SCREEN"
local total="${#WIZ_SCREENS[@]}"
local col="$_NAV_COL_WIDTH"
local nav_width="$((col*total))"
local pad_left="$(((TERM_WIDTH-nav_width)/2))"
local padding=""
((pad_left>0))&&padding=$(printf '%*s' $pad_left '')
local labels="$padding"
for i in "${!WIZ_SCREENS[@]}";do
local name="${WIZ_SCREENS[$i]}"
local name_len="${#name}"
local pad_left="$(((col-name_len)/2))"
local pad_right="$((col-name_len-pad_left))"
local centered
centered=$(printf '%*s%s%*s' $pad_left '' "$name" $pad_right '')
labels+="$(_nav_color "$i" "$current")$centered$CLR_RESET"
done
local dots="$padding"
local center_pad="$(((col-1)/2))"
local right_pad="$((col-center_pad-1))"
for i in "${!WIZ_SCREENS[@]}";do
local color line_color dot
color=$(_nav_color "$i" "$current")
dot=$(_nav_dot "$i" "$current")
if [[ $i -eq 0 ]];then
dots+=$(printf '%*s' $center_pad '')
dots+="$color$dot$CLR_RESET"
local line_clr
line_clr=$([[ $i -lt $current ]]&&echo "$CLR_CYAN"||echo "$CLR_GRAY")
dots+="$line_clr$(_nav_line "$i" "$current" "$right_pad")$CLR_RESET"
elif [[ $i -eq $((total-1)) ]];then
local prev_line_clr
prev_line_clr=$([[ $((i-1)) -lt $current ]]&&echo "$CLR_CYAN"||echo "$CLR_GRAY")
dots+="$prev_line_clr$(_nav_line "$((i-1))" "$current" "$center_pad")$CLR_RESET"
dots+="$color$dot$CLR_RESET"
else
local prev_line_clr
prev_line_clr=$([[ $((i-1)) -lt $current ]]&&echo "$CLR_CYAN"||echo "$CLR_GRAY")
dots+="$prev_line_clr$(_nav_line "$((i-1))" "$current" "$center_pad")$CLR_RESET"
dots+="$color$dot$CLR_RESET"
local next_line_clr
next_line_clr=$([[ $i -lt $current ]]&&echo "$CLR_CYAN"||echo "$CLR_GRAY")
dots+="$next_line_clr$(_nav_line "$i" "$current" "$right_pad")$CLR_RESET"
fi
done
printf '%s\n%s\n' "$labels" "$dots"
}
_wiz_read_key(){
local key
IFS= read -rsn1 key
if [[ $key == $'\x1b' ]];then
read -rsn2 -t 0.5 key
case "$key" in
'[A')declare -g WIZ_KEY="up";;
'[B')declare -g WIZ_KEY="down";;
'[C')declare -g WIZ_KEY="right";;
'[D')declare -g WIZ_KEY="left";;
*)declare -g WIZ_KEY="esc"
esac
elif [[ $key == "" ]];then
declare -g WIZ_KEY="enter"
elif [[ $key == "q" || $key == "Q" ]];then
declare -g WIZ_KEY="quit"
elif [[ $key == "s" || $key == "S" ]];then
declare -g WIZ_KEY="start"
else
declare -g WIZ_KEY="$key"
fi
}
declare -gA _DSP_MAP=(
["repo:no-subscription"]="No-subscription (free)"
["repo:enterprise"]="Enterprise"
["repo:test"]="Test/Development"
["ipv6:auto"]="Auto"
["ipv6:manual"]="Manual"
["ipv6:disabled"]="Disabled"
["bridge:external"]="External bridge"
["bridge:internal"]="Internal NAT"
["bridge:both"]="Both"
["firewall:stealth"]="Stealth (Tailscale only)"
["firewall:strict"]="Strict (SSH only)"
["firewall:standard"]="Standard (SSH + Web UI)"
["zfs:single"]="Single disk"
["zfs:raid0"]="RAID-0 (striped)"
["zfs:raid1"]="RAID-1 (mirror)"
["zfs:raidz1"]="RAID-Z1 (parity)"
["zfs:raidz2"]="RAID-Z2 (double parity)"
["zfs:raidz3"]="RAID-Z3 (triple parity)"
["zfs:raid10"]="RAID-10 (striped mirrors)"
["arc:vm-focused"]="VM-focused (4GB)"
["arc:balanced"]="Balanced (25-40%)"
["arc:storage-focused"]="Storage-focused (50%)"
["ssl:self-signed"]="Self-signed"
["ssl:letsencrypt"]="Let's Encrypt"
["shell:zsh"]="ZSH"
["shell:bash"]="Bash"
["power:performance"]="Performance"
["power:ondemand"]="Balanced"
["power:powersave"]="Balanced"
["power:schedutil"]="Adaptive"
["power:conservative"]="Conservative")
_dsp_lookup(){
local key="$1:$2"
echo "${_DSP_MAP[$key]:-$2}"
}
_dsp_escape(){
printf '%s' "${1//\\/\\\\}"
}
_dsp_basic(){
declare -g _DSP_PASS=""
[[ -n $NEW_ROOT_PASSWORD ]]&&declare -g _DSP_PASS="********"
declare -g _DSP_HOSTNAME=""
if [[ -n $PVE_HOSTNAME && -n $DOMAIN_SUFFIX ]];then
declare -g _DSP_HOSTNAME="$(_dsp_escape "$PVE_HOSTNAME").$(_dsp_escape "$DOMAIN_SUFFIX")"
fi
}
_dsp_proxmox(){
declare -g _DSP_REPO=""
[[ -n $PVE_REPO_TYPE ]]&&declare -g _DSP_REPO=$(_dsp_lookup "repo" "$PVE_REPO_TYPE")
declare -g _DSP_ISO=""
[[ -n $PROXMOX_ISO_VERSION ]]&&declare -g _DSP_ISO=$(get_iso_version "$PROXMOX_ISO_VERSION")
}
_dsp_network(){
declare -g _DSP_IPV6=""
if [[ -n $IPV6_MODE ]];then
declare -g _DSP_IPV6=$(_dsp_lookup "ipv6" "$IPV6_MODE")
if [[ $IPV6_MODE == "manual" && -n $MAIN_IPV6 ]];then
_DSP_IPV6+=" ($(_dsp_escape "$MAIN_IPV6"), gw: $(_dsp_escape "$IPV6_GATEWAY"))"
fi
fi
declare -g _DSP_BRIDGE=""
[[ -n $BRIDGE_MODE ]]&&declare -g _DSP_BRIDGE=$(_dsp_lookup "bridge" "$BRIDGE_MODE")
declare -g _DSP_FIREWALL=""
if [[ -n $INSTALL_FIREWALL ]];then
if [[ $INSTALL_FIREWALL == "yes" ]];then
declare -g _DSP_FIREWALL=$(_dsp_lookup "firewall" "$FIREWALL_MODE")
else
declare -g _DSP_FIREWALL="Disabled"
fi
fi
declare -g _DSP_MTU="${BRIDGE_MTU:-9000}"
[[ $_DSP_MTU == "9000" ]]&&declare -g _DSP_MTU="9000 (jumbo)"
}
_dsp_storage(){
declare -g _DSP_EXISTING_POOL=""
if [[ $USE_EXISTING_POOL == "yes" && -n $EXISTING_POOL_NAME ]];then
declare -g _DSP_EXISTING_POOL="Use: $(_dsp_escape "$EXISTING_POOL_NAME") (${#EXISTING_POOL_DISKS[@]} disks)"
else
declare -g _DSP_EXISTING_POOL="Create new"
fi
declare -g _DSP_ZFS=""
if [[ -n $ZFS_RAID ]];then
declare -g _DSP_ZFS=$(_dsp_lookup "zfs" "$ZFS_RAID")
elif [[ $USE_EXISTING_POOL == "yes" ]];then
declare -g _DSP_ZFS="(preserved)"
fi
declare -g _DSP_ARC=""
[[ -n $ZFS_ARC_MODE ]]&&declare -g _DSP_ARC=$(_dsp_lookup "arc" "$ZFS_ARC_MODE")
declare -g _DSP_BOOT="All in pool"
if [[ -n $BOOT_DISK ]];then
for i in "${!DRIVES[@]}";do
if [[ ${DRIVES[$i]} == "$BOOT_DISK" ]];then
declare -g _DSP_BOOT="${DRIVE_MODELS[$i]}"
break
fi
done
fi
if [[ $USE_EXISTING_POOL == "yes" ]];then
declare -g _DSP_POOL="(existing pool)"
elif [[ ${#ZFS_POOL_DISKS[@]} -eq 0 ]];then
declare -g _DSP_POOL="$CLR_YELLOW(select disks)$CLR_RESET"
elif _pool_disks_have_mixed_sizes;then
declare -g _DSP_POOL="${#ZFS_POOL_DISKS[@]} disks $CLR_YELLOW⚠ different sizes$CLR_RESET"
else
declare -g _DSP_POOL="${#ZFS_POOL_DISKS[@]} disks"
fi
declare -g _DSP_WIPE=""
if [[ $WIPE_DISKS == "yes" ]];then
declare -g _DSP_WIPE="Yes (full wipe)"
else
declare -g _DSP_WIPE="No (keep existing)"
fi
}
_dsp_services(){
declare -g _DSP_TAILSCALE=""
if [[ -n $INSTALL_TAILSCALE ]];then
if [[ $INSTALL_TAILSCALE == "yes" ]];then
declare -g _DSP_TAILSCALE="Enabled + Stealth"
else
declare -g _DSP_TAILSCALE="Disabled"
fi
fi
declare -g _DSP_SSL=""
[[ -n $SSL_TYPE ]]&&declare -g _DSP_SSL=$(_dsp_lookup "ssl" "$SSL_TYPE")
declare -g _DSP_POSTFIX=""
if [[ -n $INSTALL_POSTFIX ]];then
if [[ $INSTALL_POSTFIX == "yes" && -n $SMTP_RELAY_HOST ]];then
declare -g _DSP_POSTFIX="Relay: $(_dsp_escape "$SMTP_RELAY_HOST"):$(_dsp_escape "${SMTP_RELAY_PORT:-587}")"
elif [[ $INSTALL_POSTFIX == "yes" ]];then
declare -g _DSP_POSTFIX="Enabled (no relay)"
else
declare -g _DSP_POSTFIX="Disabled"
fi
fi
declare -g _DSP_SHELL=""
[[ -n $SHELL_TYPE ]]&&declare -g _DSP_SHELL=$(_dsp_lookup "shell" "$SHELL_TYPE")
declare -g _DSP_POWER=""
[[ -n $CPU_GOVERNOR ]]&&declare -g _DSP_POWER=$(_dsp_lookup "power" "$CPU_GOVERNOR")
declare -g _DSP_SECURITY="none"
local sec_items=()
[[ $INSTALL_APPARMOR == "yes" ]]&&sec_items+=("apparmor")
[[ $INSTALL_AUDITD == "yes" ]]&&sec_items+=("auditd")
[[ $INSTALL_AIDE == "yes" ]]&&sec_items+=("aide")
[[ $INSTALL_CHKROOTKIT == "yes" ]]&&sec_items+=("chkrootkit")
[[ $INSTALL_LYNIS == "yes" ]]&&sec_items+=("lynis")
[[ $INSTALL_NEEDRESTART == "yes" ]]&&sec_items+=("needrestart")
[[ ${#sec_items[@]} -gt 0 ]]&&declare -g _DSP_SECURITY="${sec_items[*]}"
declare -g _DSP_MONITORING="none"
local mon_items=()
[[ $INSTALL_VNSTAT == "yes" ]]&&mon_items+=("vnstat")
[[ $INSTALL_NETDATA == "yes" ]]&&mon_items+=("netdata")
[[ $INSTALL_PROMTAIL == "yes" ]]&&mon_items+=("promtail")
[[ ${#mon_items[@]} -gt 0 ]]&&declare -g _DSP_MONITORING="${mon_items[*]}"
declare -g _DSP_TOOLS="none"
local tool_items=()
[[ $INSTALL_YAZI == "yes" ]]&&tool_items+=("yazi")
[[ $INSTALL_NVIM == "yes" ]]&&tool_items+=("nvim")
[[ $INSTALL_RINGBUFFER == "yes" ]]&&tool_items+=("ringbuffer")
[[ ${#tool_items[@]} -gt 0 ]]&&declare -g _DSP_TOOLS="${tool_items[*]}"
}
_dsp_access(){
declare -g _DSP_ADMIN_USER=""
[[ -n $ADMIN_USERNAME ]]&&declare -g _DSP_ADMIN_USER="$(_dsp_escape "$ADMIN_USERNAME")"
declare -g _DSP_ADMIN_PASS=""
[[ -n $ADMIN_PASSWORD ]]&&declare -g _DSP_ADMIN_PASS="********"
declare -g _DSP_SSH=""
[[ -n $SSH_PUBLIC_KEY ]]&&declare -g _DSP_SSH="$(_dsp_escape "${SSH_PUBLIC_KEY:0:20}")..."
declare -g _DSP_API=""
if [[ -n $INSTALL_API_TOKEN ]];then
case "$INSTALL_API_TOKEN" in
yes)declare -g _DSP_API="Yes ($(_dsp_escape "$API_TOKEN_NAME"))";;
no)declare -g _DSP_API="No"
esac
fi
}
_wiz_build_display_values(){
_dsp_basic
_dsp_proxmox
_dsp_network
_dsp_storage
_dsp_services
_dsp_access
}
_wiz_config_complete(){
[[ -z $PVE_HOSTNAME ]]&&return 1
[[ -z $DOMAIN_SUFFIX ]]&&return 1
[[ -z $EMAIL ]]&&return 1
[[ -z $NEW_ROOT_PASSWORD ]]&&return 1
[[ -z $ADMIN_USERNAME ]]&&return 1
[[ -z $ADMIN_PASSWORD ]]&&return 1
[[ -z $TIMEZONE ]]&&return 1
[[ -z $KEYBOARD ]]&&return 1
[[ -z $COUNTRY ]]&&return 1
[[ -z $PROXMOX_ISO_VERSION ]]&&return 1
[[ -z $PVE_REPO_TYPE ]]&&return 1
[[ -z $INTERFACE_NAME ]]&&return 1
[[ -z $MAIN_IPV4 ]]&&return 1
[[ -z $MAIN_IPV4_GW ]]&&return 1
[[ -z $BRIDGE_MODE ]]&&return 1
[[ $BRIDGE_MODE != "external" && -z $PRIVATE_SUBNET ]]&&return 1
[[ -z $IPV6_MODE ]]&&return 1
if [[ $USE_EXISTING_POOL == "yes" ]];then
[[ -z $EXISTING_POOL_NAME ]]&&return 1
else
[[ -z $ZFS_RAID ]]&&return 1
[[ ${#ZFS_POOL_DISKS[@]} -eq 0 ]]&&return 1
validate_pool_disk_conflict&&return 1
validate_raid_disk_count&&return 1
fi
[[ -z $ZFS_ARC_MODE ]]&&return 1
[[ -z $SHELL_TYPE ]]&&return 1
[[ -z $CPU_GOVERNOR ]]&&return 1
[[ -z $SSH_PUBLIC_KEY ]]&&return 1
[[ $INSTALL_TAILSCALE != "yes" && -z $SSL_TYPE ]]&&return 1
[[ $FIREWALL_MODE == "stealth" && $INSTALL_TAILSCALE != "yes" ]]&&return 1
if [[ $INSTALL_POSTFIX == "yes" ]];then
[[ -z $SMTP_RELAY_HOST || -z $SMTP_RELAY_USER || -z $SMTP_RELAY_PASSWORD ]]&&return 1
fi
return 0
}
_WIZ_FIELD_COUNT=0
_WIZ_FIELD_MAP=()
_wiz_render_screen_content(){
local screen="$1"
local selection="$2"
case $screen in
0)_add_field "Hostname         " "$(_wiz_fmt "$_DSP_HOSTNAME")" "hostname"
_add_field "Email            " "$(_wiz_fmt "$EMAIL")" "email"
_add_field "Root Password    " "$(_wiz_fmt "$_DSP_PASS")" "password"
_add_field "Timezone         " "$(_wiz_fmt "$TIMEZONE")" "timezone"
_add_field "Keyboard         " "$(_wiz_fmt "$KEYBOARD")" "keyboard"
_add_field "Country          " "$(_wiz_fmt "$COUNTRY")" "country"
;;
1)_add_field "Version          " "$(_wiz_fmt "$_DSP_ISO")" "iso_version"
_add_field "Repository       " "$(_wiz_fmt "$_DSP_REPO")" "repository"
;;
2)if
[[ ${INTERFACE_COUNT:-1} -gt 1 ]]
then
_add_field "Interface        " "$(_wiz_fmt "$INTERFACE_NAME")" "interface"
fi
_add_field "Bridge mode      " "$(_wiz_fmt "$_DSP_BRIDGE")" "bridge_mode"
if [[ $BRIDGE_MODE == "internal" || $BRIDGE_MODE == "both" ]];then
_add_field "Private subnet   " "$(_wiz_fmt "$PRIVATE_SUBNET")" "private_subnet"
_add_field "Bridge MTU       " "$(_wiz_fmt "$_DSP_MTU")" "bridge_mtu"
fi
_add_field "IPv6             " "$(_wiz_fmt "$_DSP_IPV6")" "ipv6"
_add_field "Firewall         " "$(_wiz_fmt "$_DSP_FIREWALL")" "firewall"
;;
3)_add_field "Wipe disks       " "$(_wiz_fmt "$_DSP_WIPE")" "wipe_disks"
if [[ $DRIVE_COUNT -gt 1 ]];then
_add_field "Boot disk        " "$(_wiz_fmt "$_DSP_BOOT")" "boot_disk"
_add_field "Pool mode        " "$(_wiz_fmt "$_DSP_EXISTING_POOL")" "existing_pool"
if [[ $USE_EXISTING_POOL != "yes" ]];then
_add_field "Pool disks       " "$(_wiz_fmt "$_DSP_POOL")" "pool_disks"
_add_field "ZFS mode         " "$(_wiz_fmt "$_DSP_ZFS")" "zfs_mode"
fi
else
_add_field "ZFS mode         " "$(_wiz_fmt "$_DSP_ZFS")" "zfs_mode"
fi
_add_field "ZFS ARC          " "$(_wiz_fmt "$_DSP_ARC")" "zfs_arc"
;;
4)_add_field "Tailscale        " "$(_wiz_fmt "$_DSP_TAILSCALE")" "tailscale"
if [[ $INSTALL_TAILSCALE != "yes" ]];then
_add_field "SSL Certificate  " "$(_wiz_fmt "$_DSP_SSL")" "ssl"
fi
_add_field "Postfix          " "$(_wiz_fmt "$_DSP_POSTFIX")" "postfix"
_add_field "Shell            " "$(_wiz_fmt "$_DSP_SHELL")" "shell"
_add_field "Power profile    " "$(_wiz_fmt "$_DSP_POWER")" "power_profile"
_add_field "Security         " "$(_wiz_fmt "$_DSP_SECURITY")" "security"
_add_field "Monitoring       " "$(_wiz_fmt "$_DSP_MONITORING")" "monitoring"
_add_field "Tools            " "$(_wiz_fmt "$_DSP_TOOLS")" "tools"
;;
5)_add_field "Admin User       " "$(_wiz_fmt "$_DSP_ADMIN_USER")" "admin_username"
_add_field "Admin Password   " "$(_wiz_fmt "$_DSP_ADMIN_PASS")" "admin_password"
_add_field "SSH Key          " "$(_wiz_fmt "$_DSP_SSH")" "ssh_key"
_add_field "API Token        " "$(_wiz_fmt "$_DSP_API")" "api_token"
esac
}
_wiz_render_menu(){
local selection="$1"
local output=""
local banner_output
banner_output=$(show_banner)
_wiz_build_display_values
output+="$banner_output\n\n$(_wiz_render_nav)\n\n"
declare -g -a _WIZ_FIELD_MAP=()
local field_idx=0
_add_field(){
local label="$1"
local value="$2"
local field_name="$3"
_WIZ_FIELD_MAP+=("$field_name")
if [[ $field_idx -eq $selection ]];then
output+="$CLR_ORANGE›$CLR_RESET $CLR_GRAY$label$CLR_RESET$value\n"
else
output+="  $CLR_GRAY$label$CLR_RESET$value\n"
fi
((field_idx++))
}
_wiz_render_screen_content "$WIZ_CURRENT_SCREEN" "$selection"
declare -g _WIZ_FIELD_COUNT="$field_idx"
output+="\n"
local left_clr right_clr start_clr
left_clr=$([[ $WIZ_CURRENT_SCREEN -gt 0 ]]&&echo "$CLR_ORANGE"||echo "$CLR_GRAY")
right_clr=$([[ $WIZ_CURRENT_SCREEN -lt $((${#WIZ_SCREENS[@]}-1)) ]]&&echo "$CLR_ORANGE"||echo "$CLR_GRAY")
start_clr=$(_wiz_config_complete&&echo "$CLR_ORANGE"||echo "$CLR_GRAY")
local nav_hint=""
nav_hint+="[$left_clr←$CLR_GRAY] prev  "
nav_hint+="[$CLR_ORANGE↑↓$CLR_GRAY] navigate  [${CLR_ORANGE}Enter$CLR_GRAY] edit  "
nav_hint+="[$right_clr→$CLR_GRAY] next  "
nav_hint+="[${start_clr}S$CLR_GRAY] start  [${CLR_ORANGE}Q$CLR_GRAY] quit"
output+="$(_wiz_center "$CLR_GRAY$nav_hint$CLR_RESET")"
_wiz_clear
printf '%b' "$output"
}
_wiz_input_validated(){
local var_name="$1"
local validate_func="$2"
local error_msg="$3"
shift 3
while true;do
_wiz_start_edit
_show_input_footer
local value
value=$(_wiz_input "$@")
[[ -z $value ]]&&return 1
if "$validate_func" "$value";then
declare -g "$var_name=$value"
return 0
fi
show_validation_error "$error_msg"
done
}
_wiz_filter_select(){
local var_name="$1"
local prompt="$2"
local data="$3"
local height="${4:-6}"
_wiz_start_edit
_show_input_footer "filter" "$height"
local selected
if ! selected=$(printf '%s' "$data"|_wiz_filter --prompt "$prompt");then
return 1
fi
declare -g "$var_name=$selected"
}
_wiz_password_editor(){
local var_name="$1"
local header="$2"
local success_msg="$3"
local display_label="$4"
local set_generated="${5:-no}"
while true;do
_wiz_start_edit
_show_input_footer "filter" 3
local choice
if ! choice=$(printf '%s\n' "$WIZ_PASSWORD_OPTIONS"|_wiz_choose --header="$header");then
return 1
fi
case "$choice" in
"Generate password")local generated_pass
generated_pass=$(generate_password "$DEFAULT_PASSWORD_LENGTH")
declare -g "$var_name=$generated_pass"
[[ $set_generated == "yes" ]]&&PASSWORD_GENERATED="yes"
_wiz_start_edit
_wiz_hide_cursor
_wiz_warn "Please save this password - $success_msg"
_wiz_blank_line
printf '%s\n' "$WIZ_NOTIFY_INDENT$CLR_CYAN$display_label$CLR_RESET $CLR_ORANGE$generated_pass$CLR_RESET"
_wiz_blank_line
printf '%s\n' "$WIZ_NOTIFY_INDENT${CLR_GRAY}Press any key to continue...$CLR_RESET"
read -n 1 -s -r
return 0
;;
"Manual entry")_wiz_start_edit
_show_input_footer
local new_password
new_password=$(_wiz_input \
--password \
--placeholder "Enter password" \
--prompt "$header ")
if [[ -z $new_password ]];then
continue
fi
local password_error
password_error=$(get_password_error "$new_password")
if [[ -n $password_error ]];then
show_validation_error "$password_error"
continue
fi
declare -g "$var_name=$new_password"
[[ $set_generated == "yes" ]]&&PASSWORD_GENERATED="no"
return 0
esac
done
}
_wiz_choose_mapped(){
local var_name="$1"
local header="$2"
shift 2
local -A mapping=()
local options=""
for pair in "$@";do
local display="${pair%%:*}"
local internal="${pair#*:}"
mapping["$display"]="$internal"
[[ -n $options ]]&&options+=$'\n'
options+="$display"
done
local selected
if ! selected=$(printf '%s\n' "$options"|_wiz_choose --header="$header");then
return 1
fi
local internal_value="${mapping[$selected]:-}"
if [[ -n $internal_value ]];then
declare -g "$var_name=$internal_value"
fi
return 0
}
_wiz_toggle(){
local var_name="$1"
local header="$2"
local default_on_cancel="${3:-no}"
local selected
if ! selected=$(printf '%s\n' "Enabled" "Disabled"|_wiz_choose --header="$header");then
declare -g "$var_name=$default_on_cancel"
return 1
fi
if [[ $selected == "Enabled" ]];then
declare -g "$var_name=yes"
return 2
else
declare -g "$var_name=no"
return 0
fi
}
_wiz_feature_checkbox(){
local header="$1"
local footer_size="$2"
local options_var="$3"
shift 3
_show_input_footer "checkbox" "$footer_size"
local gum_args=(--header="$header")
local feature_map=()
for pair in "$@";do
local feature="${pair%%:*}"
local var_name="${pair#*:}"
feature_map+=("$feature:$var_name")
local current_value
current_value="${!var_name}"
[[ $current_value == "yes" ]]&&gum_args+=(--selected "$feature")
done
local selected
if ! selected=$(printf '%s\n' "${!options_var}"|_wiz_choose_multi "${gum_args[@]}");then
return 1
fi
for pair in "${feature_map[@]}";do
local feature="${pair%%:*}"
local var_name="${pair#*:}"
if [[ $selected == *"$feature"* ]];then
declare -g "$var_name=yes"
else
declare -g "$var_name=no"
fi
done
return 0
}
_country_to_locale(){
local country="${1:-us}"
country="${country,,}"
case "$country" in
us|gb|au|nz|ca|ie)echo "en_${country^^}.UTF-8";;
ru)echo "ru_RU.UTF-8";;
ua)echo "uk_UA.UTF-8";;
de|at)echo "de_${country^^}.UTF-8";;
fr|be)echo "fr_${country^^}.UTF-8";;
es|mx|ar|co|cl|pe)echo "es_${country^^}.UTF-8";;
pt|br)echo "pt_${country^^}.UTF-8";;
it)echo "it_IT.UTF-8";;
nl)echo "nl_NL.UTF-8";;
pl)echo "pl_PL.UTF-8";;
cz)echo "cs_CZ.UTF-8";;
sk)echo "sk_SK.UTF-8";;
hu)echo "hu_HU.UTF-8";;
ro)echo "ro_RO.UTF-8";;
bg)echo "bg_BG.UTF-8";;
hr)echo "hr_HR.UTF-8";;
rs)echo "sr_RS.UTF-8";;
si)echo "sl_SI.UTF-8";;
se)echo "sv_SE.UTF-8";;
no)echo "nb_NO.UTF-8";;
dk)echo "da_DK.UTF-8";;
fi)echo "fi_FI.UTF-8";;
ee)echo "et_EE.UTF-8";;
lv)echo "lv_LV.UTF-8";;
lt)echo "lt_LT.UTF-8";;
gr)echo "el_GR.UTF-8";;
tr)echo "tr_TR.UTF-8";;
il)echo "he_IL.UTF-8";;
jp)echo "ja_JP.UTF-8";;
cn)echo "zh_CN.UTF-8";;
tw)echo "zh_TW.UTF-8";;
kr)echo "ko_KR.UTF-8";;
in)echo "hi_IN.UTF-8";;
th)echo "th_TH.UTF-8";;
vn)echo "vi_VN.UTF-8";;
id)echo "id_ID.UTF-8";;
my)echo "ms_MY.UTF-8";;
ph)echo "en_PH.UTF-8";;
sg)echo "en_SG.UTF-8";;
za)echo "en_ZA.UTF-8";;
eg)echo "ar_EG.UTF-8";;
sa)echo "ar_SA.UTF-8";;
ae)echo "ar_AE.UTF-8";;
ir)echo "fa_IR.UTF-8";;
*)log_warn "Unknown country code '$country', using en_US.UTF-8 fallback"
echo "en_US.UTF-8"
esac
}
_update_locale_from_country(){
declare -g LOCALE
LOCALE=$(_country_to_locale "$COUNTRY")
log_info "Set LOCALE=$LOCALE from COUNTRY=$COUNTRY"
}
_edit_hostname(){
_wiz_input_validated "PVE_HOSTNAME" "validate_hostname" "Invalid hostname format" \
--placeholder "e.g., pve, proxmox, node1" \
--value "$PVE_HOSTNAME" \
--prompt "Hostname: "||return
_wiz_start_edit
_show_input_footer
local new_domain
new_domain=$(_wiz_input \
--placeholder "e.g., local, example.com" \
--value "$DOMAIN_SUFFIX" \
--prompt "Domain: ")
[[ -z $new_domain ]]&&return
declare -g DOMAIN_SUFFIX="$new_domain"
[[ -n $PVE_HOSTNAME ]]&&declare -g FQDN="$PVE_HOSTNAME.$DOMAIN_SUFFIX"
}
_edit_email(){
_wiz_input_validated "EMAIL" "validate_email" "Invalid email format" \
--placeholder "admin@example.com" \
--value "$EMAIL" \
--prompt "Email: "
}
_edit_password(){
_wiz_password_editor \
"NEW_ROOT_PASSWORD" \
"Root Password:" \
"it will be required for login" \
"Generated root password:" \
"yes"
}
_edit_timezone(){
_wiz_filter_select "TIMEZONE" "Timezone: " "$WIZ_TIMEZONES"||return
local country_code="${TZ_TO_COUNTRY[$TIMEZONE]:-}"
if [[ -n $country_code ]];then
declare -g COUNTRY="$country_code"
_update_locale_from_country
fi
}
_edit_keyboard(){
_wiz_filter_select "KEYBOARD" "Keyboard: " "$WIZ_KEYBOARD_LAYOUTS"
}
_edit_country(){
_wiz_filter_select "COUNTRY" "Country: " "$WIZ_COUNTRIES"||return
_update_locale_from_country
}
_edit_iso_version(){
_wiz_start_edit
_wiz_description \
"  Proxmox VE version to install:" \
"" \
"  Latest version recommended for new installations." \
""
local iso_list
iso_list=$(get_available_proxmox_isos 5)
if [[ -z $iso_list ]];then
_wiz_hide_cursor
_wiz_error "Failed to fetch ISO list"
_wiz_blank_line
sleep "${RETRY_DELAY_SECONDS:-2}"
return
fi
_show_input_footer "filter" 6
local selected
if ! selected=$(printf '%s\n' "$iso_list"|_wiz_choose --header="Proxmox Version:");then
return
fi
declare -g PROXMOX_ISO_VERSION="$selected"
}
_edit_repository(){
_wiz_start_edit
_wiz_description \
"  Proxmox VE package repository:" \
"" \
"  {{cyan:No-subscription}}: Free updates, community tested" \
"  {{cyan:Enterprise}}:      Stable updates, requires license" \
"  {{cyan:Test}}:            Latest builds, may be unstable" \
""
_show_input_footer "filter" 4
if ! _wiz_choose_mapped "PVE_REPO_TYPE" "Repository:" \
"${WIZ_MAP_REPO_TYPE[@]}";then
return
fi
if [[ $PVE_REPO_TYPE == "enterprise" ]];then
_wiz_input_screen "Enter Proxmox subscription key"
local sub_key
sub_key=$(_wiz_input \
--placeholder "pve2c-..." \
--value "$PVE_SUBSCRIPTION_KEY" \
--prompt "Subscription Key: ")
declare -g PVE_SUBSCRIPTION_KEY="$sub_key"
if [[ -z $PVE_SUBSCRIPTION_KEY ]];then
declare -g PVE_REPO_TYPE="no-subscription"
_wiz_hide_cursor
_wiz_warn "Enterprise repository requires subscription key"
sleep "${RETRY_DELAY_SECONDS:-2}"
fi
else
declare -g PVE_SUBSCRIPTION_KEY=""
fi
}
_edit_interface(){
_wiz_start_edit
local interface_count=${INTERFACE_COUNT:-1}
local available_interfaces=${AVAILABLE_INTERFACES:-$INTERFACE_NAME}
local footer_size="$((interface_count+1))"
_show_input_footer "filter" "$footer_size"
local selected
if ! selected=$(printf '%s\n' "$available_interfaces"|_wiz_choose --header="Network Interface:");then
return
fi
declare -g INTERFACE_NAME="$selected"
}
_edit_bridge_mode(){
_wiz_start_edit
_wiz_description \
"  Network bridge configuration for VMs:" \
"" \
"  {{cyan:Internal}}: Private network with NAT (10.x.x.x)" \
"  {{cyan:External}}: VMs get public IPs directly (routed mode)" \
"  {{cyan:Both}}:     Internal + External bridges" \
""
_show_input_footer "filter" 4
_wiz_choose_mapped "BRIDGE_MODE" "Bridge mode:" \
"${WIZ_MAP_BRIDGE_MODE[@]}"
}
_edit_private_subnet(){
_wiz_start_edit
_wiz_description \
"  Private network for VMs (NAT to internet):" \
"" \
"  {{cyan:10.0.0.0/24}}:    Class A private (default)" \
"  {{cyan:192.168.1.0/24}}: Class C private (home-style)" \
"  {{cyan:172.16.0.0/24}}:  Class B private" \
""
_show_input_footer "filter" 5
local selected
if ! selected=$(printf '%s\n' "$WIZ_PRIVATE_SUBNETS"|_wiz_choose --header="Private subnet:");then
return
fi
if [[ $selected == "Custom" ]];then
while true;do
_wiz_input_screen \
"Enter private subnet in CIDR notation" \
"Example: 10.0.0.0/24"
local new_subnet
new_subnet=$(_wiz_input \
--placeholder "e.g., 10.10.10.0/24" \
--value "$PRIVATE_SUBNET" \
--prompt "Private subnet: ")
if [[ -z $new_subnet ]];then
return
fi
if validate_subnet "$new_subnet";then
declare -g PRIVATE_SUBNET="$new_subnet"
break
else
show_validation_error "Invalid subnet format. Use CIDR notation like: 10.0.0.0/24"
fi
done
else
declare -g PRIVATE_SUBNET="$selected"
fi
}
_edit_bridge_mtu(){
_wiz_start_edit
_wiz_description \
"  MTU for private bridge (VM-to-VM traffic):" \
"" \
"  {{cyan:9000}}:  Jumbo frames (better VM performance)" \
"  {{cyan:1500}}:  Standard MTU (safe default)" \
""
_show_input_footer "filter" 3
_wiz_choose_mapped "BRIDGE_MTU" "Bridge MTU:" \
"${WIZ_MAP_BRIDGE_MTU[@]}"
}
_edit_ipv6(){
_wiz_start_edit
_wiz_description \
"  IPv6 network configuration:" \
"" \
"  {{cyan:Auto}}:     Use detected IPv6 from provider" \
"  {{cyan:Manual}}:   Specify custom IPv6 address/gateway" \
"  {{cyan:Disabled}}: IPv4 only" \
""
_show_input_footer "filter" 4
local selected
if ! selected=$(printf '%s\n' "$WIZ_IPV6_MODES"|_wiz_choose --header="IPv6:");then
return
fi
local ipv6_mode=""
case "$selected" in
"Auto")ipv6_mode="auto";;
"Manual")ipv6_mode="manual";;
"Disabled")ipv6_mode="disabled"
esac
declare -g IPV6_MODE="$ipv6_mode"
if [[ $ipv6_mode == "manual" ]];then
while true;do
_wiz_input_screen \
"Enter IPv6 address in CIDR notation" \
"Example: 2001:db8::1/64"
local ipv6_addr
ipv6_addr=$(_wiz_input \
--placeholder "2001:db8::1/64" \
--prompt "IPv6 Address: " \
--value "${IPV6_ADDRESS:-${FIRST_IPV6_CIDR:-$MAIN_IPV6}}")
if [[ -z $ipv6_addr ]];then
IPV6_MODE=""
return
fi
if validate_ipv6_cidr "$ipv6_addr";then
declare -g IPV6_ADDRESS="$ipv6_addr"
declare -g MAIN_IPV6="${ipv6_addr%/*}"
break
else
show_validation_error "Invalid IPv6 CIDR notation. Use format like: 2001:db8::1/64"
fi
done
while true;do
_wiz_input_screen \
"Enter IPv6 gateway address" \
"Common default: fe80::1 (link-local)"
local ipv6_gw
ipv6_gw=$(_wiz_input \
--placeholder "fe80::1" \
--prompt "Gateway: " \
--value "${IPV6_GATEWAY:-$DEFAULT_IPV6_GATEWAY}")
if [[ -z $ipv6_gw ]];then
declare -g IPV6_GATEWAY="$DEFAULT_IPV6_GATEWAY"
break
fi
if validate_ipv6_gateway "$ipv6_gw";then
declare -g IPV6_GATEWAY="$ipv6_gw"
break
else
show_validation_error "Invalid IPv6 gateway address"
fi
done
elif [[ $ipv6_mode == "disabled" ]];then
declare -g MAIN_IPV6=""
declare -g IPV6_GATEWAY=""
declare -g FIRST_IPV6_CIDR=""
declare -g IPV6_ADDRESS=""
elif [[ $ipv6_mode == "auto" ]];then
declare -g IPV6_GATEWAY="${IPV6_GATEWAY:-$DEFAULT_IPV6_GATEWAY}"
fi
}
_edit_firewall(){
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
_show_input_footer "filter" 5
local selected
if ! selected=$(printf '%s\n' "$WIZ_FIREWALL_MODES"|_wiz_choose --header="Firewall mode:");then
return
fi
case "$selected" in
"Stealth (Tailscale only)")declare -g INSTALL_FIREWALL="yes"
declare -g FIREWALL_MODE="stealth"
;;
"Strict (SSH only)")declare -g INSTALL_FIREWALL="yes"
declare -g FIREWALL_MODE="strict"
;;
"Standard (SSH + Web UI)")declare -g INSTALL_FIREWALL="yes"
declare -g FIREWALL_MODE="standard"
;;
"Disabled")declare -g INSTALL_FIREWALL="no"
declare -g FIREWALL_MODE=""
esac
}
_edit_wipe_disks(){
_wiz_start_edit
if [[ $USE_EXISTING_POOL == "yes" ]];then
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
_edit_existing_pool(){
_wiz_start_edit
if [[ ${#DETECTED_POOLS[@]} -eq 0 ]];then
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
local options="Create new pool (format disks)"
for pool_info in "${DETECTED_POOLS[@]}";do
local pool_name="${pool_info%%|*}"
local rest="${pool_info#*|}"
local pool_state="${rest%%|*}"
options+=$'\n'"Use existing: $pool_name ($pool_state)"
done
local item_count
item_count=$(wc -l <<<"$options")
_show_input_footer "filter" "$((item_count+1))"
local selected
if ! selected=$(printf '%s\n' "$options"|_wiz_choose --header="Pool mode:");then
return
fi
if [[ $selected == "Create new pool (format disks)" ]];then
declare -g USE_EXISTING_POOL=""
declare -g EXISTING_POOL_NAME=""
declare -g -a EXISTING_POOL_DISKS=()
elif [[ $selected =~ ^Use\ existing:\ (.+)\ \( ]];then
if [[ -z $BOOT_DISK ]];then
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
local disks_csv
disks_csv=$(get_pool_disks "$pool_name")
local pool_disks=()
while IFS= read -r disk;do
[[ -n $disk ]]&&pool_disks+=("$disk")
done < <(tr ',' '\n' <<<"$disks_csv")
local boot_in_pool=false
for disk in "${pool_disks[@]}";do
if [[ $disk == "$BOOT_DISK" ]];then
boot_in_pool=true
break
fi
done
if [[ $boot_in_pool == true ]];then
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
declare -g -a ZFS_POOL_DISKS=()
declare -g ZFS_RAID=""
log_info "Selected existing pool: $EXISTING_POOL_NAME with disks: ${EXISTING_POOL_DISKS[*]}"
fi
}
_edit_zfs_mode(){
_wiz_start_edit
_wiz_description \
"  ZFS RAID level for data pool:" \
"" \
"  {{cyan:RAID-0}}:  Max capacity, no redundancy (all disks)" \
"  {{cyan:RAID-1}}:  Mirror, 50% capacity (2+ disks)" \
"  {{cyan:RAID-Z1}}: Single parity, N-1 capacity (3+ disks)" \
"  {{cyan:RAID-Z2}}: Double parity, N-2 capacity (4+ disks)" \
"  {{cyan:RAID-10}}: Striped mirrors (4+ disks, even count)" \
""
local pool_count="${#ZFS_POOL_DISKS[@]}"
local options=""
if [[ $pool_count -eq 1 ]];then
options="Single disk"
elif [[ $pool_count -eq 2 ]];then
options="RAID-0 (striped)
RAID-1 (mirror)"
elif [[ $pool_count -eq 3 ]];then
options="RAID-0 (striped)
RAID-1 (mirror)
RAID-Z1 (parity)"
elif [[ $pool_count -eq 4 ]];then
options="RAID-0 (striped)
RAID-1 (mirror)
RAID-Z1 (parity)
RAID-Z2 (double parity)
RAID-10 (striped mirrors)"
elif [[ $pool_count -ge 5 ]];then
options="RAID-0 (striped)
RAID-1 (mirror)
RAID-Z1 (parity)
RAID-Z2 (double parity)
RAID-Z3 (triple parity)
RAID-10 (striped mirrors)"
fi
local item_count
item_count=$(wc -l <<<"$options")
_show_input_footer "filter" "$((item_count+1))"
local selected
if ! selected=$(printf '%s\n' "$options"|_wiz_choose --header="ZFS mode ($pool_count disks in pool):");then
return
fi
case "$selected" in
"Single disk")declare -g ZFS_RAID="single";;
"RAID-0 (striped)")declare -g ZFS_RAID="raid0";;
"RAID-1 (mirror)")declare -g ZFS_RAID="raid1";;
"RAID-Z1 (parity)")declare -g ZFS_RAID="raidz1";;
"RAID-Z2 (double parity)")declare -g ZFS_RAID="raidz2";;
"RAID-Z3 (triple parity)")declare -g ZFS_RAID="raidz3";;
"RAID-10 (striped mirrors)")declare -g ZFS_RAID="raid10"
esac
}
_edit_zfs_arc(){
_wiz_start_edit
_wiz_description \
"  ZFS Adaptive Replacement Cache (ARC) memory allocation:" \
"" \
"  {{cyan:VM-focused}}:      Fixed 4GB for ARC (more RAM for VMs)" \
"  {{cyan:Balanced}}:        25-40% of RAM based on total size" \
"  {{cyan:Storage-focused}}: 50% of RAM (maximize ZFS caching)" \
""
_show_input_footer "filter" 4
_wiz_choose_mapped "ZFS_ARC_MODE" "ZFS ARC memory strategy:" \
"${WIZ_MAP_ZFS_ARC[@]}"
}
_ssl_validate_fqdn(){
if [[ -z $FQDN ]];then
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
if [[ $FQDN == *.local ]]||! validate_fqdn "$FQDN";then
_wiz_start_edit
_wiz_hide_cursor
_wiz_description \
"  {{red:✗ Invalid domain name!}}" \
"" \
"  Current hostname: {{orange:$FQDN}}" \
"  Let's Encrypt requires a valid public FQDN (e.g., pve.example.com)." \
"  Domains ending with .local are not supported."
sleep "${WIZARD_MESSAGE_DELAY:-3}"
return 2
fi
return 0
}
_ssl_check_dns_animated(){
_wiz_start_edit
_wiz_hide_cursor
_wiz_blank_line
_wiz_dim "Domain: $CLR_ORANGE$FQDN$CLR_RESET"
_wiz_dim "Expected IP: $CLR_ORANGE$MAIN_IPV4$CLR_RESET"
_wiz_blank_line
local dns_result_file=""
dns_result_file=$(mktemp)||{
log_error "mktemp failed for dns_result_file"
return 1
}
register_temp_file "$dns_result_file"
(validate_dns_resolution "$FQDN" "$MAIN_IPV4"
local result=$?
printf '%s\n' "$DNS_RESOLVED_IP" >"$dns_result_file"
exit $result) > \
/dev/null 2>&1&
local dns_pid="$!"
show_progress "$dns_pid" "Validating DNS resolution" --silent
local dns_result=$?
read -r DNS_RESOLVED_IP <"$dns_result_file"
rm -f "$dns_result_file"
return "$dns_result"
}
_ssl_show_dns_error(){
local error_type="$1"
_wiz_hide_cursor
if [[ $error_type -eq 1 ]];then
_wiz_description \
"  {{red:✗ Domain does not resolve to any IP address}}" \
"" \
"  Please configure DNS A record:" \
"  {{orange:$FQDN}} → {{orange:$MAIN_IPV4}}" \
"" \
"  Falling back to self-signed certificate."
else
_wiz_description \
"  {{red:✗ Domain resolves to wrong IP address}}" \
"" \
"  Current DNS: {{orange:$FQDN}} → {{red:$DNS_RESOLVED_IP}}" \
"  Expected:    {{orange:$FQDN}} → {{orange:$MAIN_IPV4}}" \
"" \
"  Please update DNS A record to point to {{orange:$MAIN_IPV4}}" \
"" \
"  Falling back to self-signed certificate."
fi
sleep "$((${WIZARD_MESSAGE_DELAY:-3}+2))"
}
_ssl_validate_letsencrypt(){
_ssl_validate_fqdn||return 1
local dns_result
_ssl_check_dns_animated
dns_result="$?"
if [[ $dns_result -ne 0 ]];then
_ssl_show_dns_error "$dns_result"
return 1
fi
_wiz_info "DNS resolution successful"
_wiz_dim "$CLR_ORANGE$FQDN$CLR_RESET → $CLR_CYAN$DNS_RESOLVED_IP$CLR_RESET"
sleep "${WIZARD_MESSAGE_DELAY:-3}"
return 0
}
_edit_ssl(){
_wiz_start_edit
_wiz_description \
"  SSL certificate for Proxmox web interface:" \
"" \
"  {{cyan:Self-signed}}:   Works always, browser shows warning" \
"  {{cyan:Let's Encrypt}}: Trusted cert, requires public DNS" \
""
_show_input_footer "filter" 3
if ! _wiz_choose_mapped "SSL_TYPE" "SSL Certificate:" \
"${WIZ_MAP_SSL_TYPE[@]}";then
return
fi
if [[ $SSL_TYPE == "letsencrypt" ]];then
if ! _ssl_validate_letsencrypt;then
declare -g SSL_TYPE="self-signed"
fi
fi
}
_tailscale_get_auth_key(){
declare -g _TAILSCALE_TMP_KEY=""
_wiz_input_validated "_TAILSCALE_TMP_KEY" "validate_tailscale_key" \
"Invalid key format. Expected: tskey-auth-xxx-xxx" \
--placeholder "tskey-auth-..." \
--prompt "Auth Key: "
}
_tailscale_configure_webui(){
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
_tailscale_enable(){
local auth_key="$1"
declare -g INSTALL_TAILSCALE="yes"
declare -g TAILSCALE_AUTH_KEY="$auth_key"
_tailscale_configure_webui
declare -g SSL_TYPE="self-signed"
if [[ -z $INSTALL_FIREWALL ]];then
declare -g INSTALL_FIREWALL="yes"
declare -g FIREWALL_MODE="stealth"
fi
}
_tailscale_disable(){
declare -g INSTALL_TAILSCALE="no"
declare -g TAILSCALE_AUTH_KEY=""
declare -g TAILSCALE_WEBUI=""
declare -g SSL_TYPE=""
if [[ -z $INSTALL_FIREWALL ]];then
declare -g INSTALL_FIREWALL="yes"
declare -g FIREWALL_MODE="standard"
fi
}
_edit_tailscale(){
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
if [[ $result -eq 1 ]];then
return
elif [[ $result -eq 2 ]];then
if _tailscale_get_auth_key&&[[ -n $_TAILSCALE_TMP_KEY ]];then
_tailscale_enable "$_TAILSCALE_TMP_KEY"
else
_tailscale_disable
fi
else
_tailscale_disable
fi
}
_edit_admin_username(){
while true;do
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
new_username=$(_wiz_input \
--placeholder "e.g., sysadmin, deploy, operator" \
--value "$ADMIN_USERNAME" \
--prompt "Admin username: ")
if [[ -z $new_username ]];then
return
fi
if validate_admin_username "$new_username";then
declare -g ADMIN_USERNAME="$new_username"
break
else
show_validation_error "Invalid username. Use lowercase letters/numbers, 1-32 chars. Reserved names (root, admin) not allowed."
fi
done
}
_edit_admin_password(){
_wiz_password_editor \
"ADMIN_PASSWORD" \
"Admin Password:" \
"it will be required for sudo and Proxmox UI" \
"Generated admin password:"
}
_edit_api_token(){
_wiz_start_edit
_wiz_description \
"  Proxmox API token for automation:" \
"" \
"  {{cyan:Enabled}}:  Create privileged token (Terraform, Ansible)" \
"  {{cyan:Disabled}}: No API token" \
"" \
"  Token has full Administrator permissions, no expiration." \
""
_show_input_footer "filter" 3
local result
_wiz_toggle "INSTALL_API_TOKEN" "API Token (privileged, no expiration):"
result="$?"
[[ $result -eq 1 ]]&&return
[[ $result -ne 2 ]]&&return
_wiz_input_screen "Enter API token name (default: automation)"
local token_name
token_name=$(_wiz_input \
--placeholder "automation" \
--prompt "Token name: " \
--no-show-help \
--value="${API_TOKEN_NAME:-automation}")
if [[ -n $token_name && $token_name =~ ^[a-zA-Z0-9_-]+$ ]];then
declare -g API_TOKEN_NAME="$token_name"
else
declare -g API_TOKEN_NAME="automation"
fi
}
_edit_ssh_key(){
while true;do
_wiz_start_edit
local detected_key
detected_key=$(get_rescue_ssh_key)
if [[ -n $detected_key ]];then
parse_ssh_key "$detected_key"
_wiz_hide_cursor
_wiz_warn "Detected SSH key from Rescue System:"
_wiz_blank_line
printf '%s\n' "$WIZ_NOTIFY_INDENT${CLR_GRAY}Type:$CLR_RESET    $SSH_KEY_TYPE"
printf '%s\n' "$WIZ_NOTIFY_INDENT${CLR_GRAY}Key:$CLR_RESET     $SSH_KEY_SHORT"
[[ -n $SSH_KEY_COMMENT ]]&&printf '%s\n' "$WIZ_NOTIFY_INDENT${CLR_GRAY}Comment:$CLR_RESET $SSH_KEY_COMMENT"
_wiz_blank_line
_show_input_footer "filter" 3
local choice
choice=$(printf '%s\n' "$WIZ_SSH_KEY_OPTIONS"|_wiz_choose \
--header="SSH Key:")
if [[ -z $choice ]];then
return
fi
case "$choice" in
"Use detected key")declare -g SSH_PUBLIC_KEY="$detected_key"
break
;;
"Enter different key")
esac
fi
_wiz_input_screen "Paste your SSH public key (ssh-rsa, ssh-ed25519, etc.)"
local new_key
new_key=$(_wiz_input \
--placeholder "ssh-ed25519 AAAA... user@host" \
--value "$SSH_PUBLIC_KEY" \
--prompt "SSH Key: ")
if [[ -z $new_key ]];then
if [[ -n $detected_key ]];then
continue
else
return
fi
fi
if validate_ssh_key_secure "$new_key";then
declare -g SSH_PUBLIC_KEY="$new_key"
break
else
show_validation_error "Invalid SSH key. Must be ED25519, RSA/ECDSA ≥2048 bits"
if [[ -n $detected_key ]];then
continue
fi
fi
done
}
_edit_boot_disk(){
_wiz_start_edit
_wiz_description \
"  Separate boot disk selection (auto-detected by disk size):" \
"" \
"  {{cyan:None}}: All disks in ZFS rpool (system + VMs)" \
"  {{cyan:Disk}}: Boot disk uses ext4 (system + ISO/templates)" \
"       Pool disks use ZFS tank (VMs only)" \
""
local options="None (all in pool)"
for i in "${!DRIVES[@]}";do
local disk_name="${DRIVE_NAMES[$i]}"
local disk_size="${DRIVE_SIZES[$i]}"
local disk_model="${DRIVE_MODELS[$i]:0:25}"
options+=$'\n'"$disk_name - $disk_size  $disk_model"
done
_show_input_footer "filter" "$((DRIVE_COUNT+2))"
local selected
if ! selected=$(printf '%s\n' "$options"|_wiz_choose --header="Boot disk:");then
return
fi
if [[ -n $selected ]];then
local old_boot_disk="$BOOT_DISK"
if [[ $selected == "None (all in pool)" ]];then
declare -g BOOT_DISK=""
else
local disk_name="${selected%% -*}"
declare -g BOOT_DISK="/dev/$disk_name"
fi
_rebuild_pool_disks
if [[ ${#ZFS_POOL_DISKS[@]} -eq 0 ]];then
_wiz_start_edit
_wiz_hide_cursor
_wiz_description \
"  {{red:✗ Cannot use this boot disk: No disks left for ZFS pool}}" \
"" \
"  At least one disk must remain for the ZFS pool."
sleep "${WIZARD_MESSAGE_DELAY:-3}"
declare -g BOOT_DISK="$old_boot_disk"
_rebuild_pool_disks
fi
fi
}
_pool_disks_have_mixed_sizes(){
[[ ${#ZFS_POOL_DISKS[@]} -lt 2 ]]&&return 1
local -A pool_disk_indices=()
for pool_disk in "${ZFS_POOL_DISKS[@]}";do
for i in "${!DRIVES[@]}";do
[[ ${DRIVES[$i]} == "$pool_disk" ]]&&pool_disk_indices[$i]=1
done
done
local -a size_bytes=()
for i in "${!pool_disk_indices[@]}";do
local size_str="${DRIVE_SIZES[$i]}"
local num="${size_str%[TGMK]*}"
local unit="${size_str##*[0-9.]}"
case "$unit" in
T)size_bytes+=("$(echo "$num * 1099511627776"|bc|cut -d. -f1)");;
G)size_bytes+=("$(echo "$num * 1073741824"|bc|cut -d. -f1)");;
M)size_bytes+=("$(echo "$num * 1048576"|bc|cut -d. -f1)");;
*)size_bytes+=("$num")
esac
done
local min_size="${size_bytes[0]}" max_size="${size_bytes[0]}"
for size in "${size_bytes[@]}";do
((size<min_size))&&min_size="$size"
((size>max_size))&&max_size="$size"
done
local size_diff="$((max_size-min_size))"
local threshold="$((min_size/10))"
((size_diff>threshold))
}
_edit_pool_disks(){
while true;do
_wiz_start_edit
_wiz_description \
"  Select disks for ZFS storage pool:" \
"" \
"  These disks will store VMs, containers, and data." \
"  RAID level is auto-selected based on disk count." \
""
local options=""
local preselected=()
local -A pool_disk_set=()
for pool_disk in "${ZFS_POOL_DISKS[@]}";do
pool_disk_set["$pool_disk"]=1
done
for i in "${!DRIVES[@]}";do
if [[ -z $BOOT_DISK || ${DRIVES[$i]} != "$BOOT_DISK" ]];then
local disk_name="${DRIVE_NAMES[$i]}"
local disk_size="${DRIVE_SIZES[$i]}"
local disk_model="${DRIVE_MODELS[$i]:0:25}"
local disk_label="$disk_name - $disk_size  $disk_model"
[[ -n $options ]]&&options+=$'\n'
options+="$disk_label"
[[ -v pool_disk_set["/dev/$disk_name"] ]]&&preselected+=("$disk_label")
fi
done
local available_count
if [[ -n $BOOT_DISK ]];then
available_count="$((DRIVE_COUNT-1))"
else
available_count="$DRIVE_COUNT"
fi
_show_input_footer "checkbox" "$((available_count+1))"
local gum_args=(--header="ZFS pool disks (min 1):")
for item in "${preselected[@]}";do
gum_args+=(--selected "$item")
done
local selected
local gum_exit_code=0
selected=$(printf '%s\n' "$options"|_wiz_choose_multi "${gum_args[@]}")||gum_exit_code="$?"
if [[ $gum_exit_code -ne 0 ]];then
return 0
fi
if [[ -z $selected ]];then
if [[ ${#ZFS_POOL_DISKS[@]} -gt 0 ]];then
return 0
fi
show_validation_error "✗ At least one disk must be selected for ZFS pool"
continue
fi
declare -g -a ZFS_POOL_DISKS=()
while IFS= read -r line;do
local disk_name="${line%% -*}"
ZFS_POOL_DISKS+=("/dev/$disk_name")
done <<<"$selected"
_update_zfs_mode_options
break
done
}
_rebuild_pool_disks(){
if [[ -n $BOOT_DISK ]];then
local -a new_pool=()
for disk in "${ZFS_POOL_DISKS[@]}";do
[[ $disk != "$BOOT_DISK" ]]&&new_pool+=("$disk")
done
declare -g -a ZFS_POOL_DISKS=("${new_pool[@]}")
fi
_update_zfs_mode_options
}
_update_zfs_mode_options(){
local pool_count="${#ZFS_POOL_DISKS[@]}"
case "$ZFS_RAID" in
single)[[ $pool_count -ne 1 ]]&&declare -g ZFS_RAID="";;
raid1|raid0)[[ $pool_count -lt 2 ]]&&declare -g ZFS_RAID="";;
raidz1)[[ $pool_count -lt 3 ]]&&declare -g ZFS_RAID="";;
raid10|raidz2)[[ $pool_count -lt 4 ]]&&declare -g ZFS_RAID="";;
raidz3)[[ $pool_count -lt 5 ]]&&declare -g ZFS_RAID=""
esac
}
_edit_shell(){
_wiz_start_edit
_wiz_description \
"  Default shell for root user:" \
"" \
"  {{cyan:ZSH}}:  Modern shell with gentoo prompt" \
"  {{cyan:Bash}}: Standard shell (minimal changes)" \
""
_show_input_footer "filter" 3
_wiz_choose_mapped "SHELL_TYPE" "Shell:" \
"${WIZ_MAP_SHELL[@]}"
}
_edit_power_profile(){
_wiz_start_edit
local avail_governors=""
if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ]];then
avail_governors=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)
fi
local has_performance=false has_ondemand=false has_powersave=false
local has_schedutil=false has_conservative=false
if [[ -n $avail_governors ]];then
for gov in $avail_governors;do
case "$gov" in
performance)has_performance=true;;
ondemand)has_ondemand=true;;
powersave)has_powersave=true;;
schedutil)has_schedutil=true;;
conservative)has_conservative=true
esac
done
fi
local options=()
local descriptions=()
if [[ -z $avail_governors ]]||$has_performance;then
options+=("Performance")
descriptions+=("  {{cyan:Performance}}:  Max frequency (highest power)")
fi
if $has_ondemand;then
options+=("Balanced")
descriptions+=("  {{cyan:Balanced}}:     Scale based on load")
elif $has_powersave;then
options+=("Balanced")
descriptions+=("  {{cyan:Balanced}}:     Dynamic scaling (power efficient)")
fi
if $has_schedutil;then
options+=("Adaptive")
descriptions+=("  {{cyan:Adaptive}}:     Kernel-managed scaling")
fi
if $has_conservative;then
options+=("Conservative")
descriptions+=("  {{cyan:Conservative}}: Gradual frequency changes")
fi
if [[ ${#options[@]} -eq 0 ]];then
options=("Performance" "Balanced")
descriptions=(
"  {{cyan:Performance}}:  Max frequency (highest power)"
"  {{cyan:Balanced}}:     Dynamic scaling (power efficient)")
fi
_wiz_description \
"  CPU frequency scaling governor:" \
"" \
"${descriptions[@]}" \
""
_show_input_footer "filter" $((${#options[@]}+1))
local options_str
options_str=$(printf '%s\n' "${options[@]}")
local selected
if ! selected=$(printf '%s\n' "$options_str"|_wiz_choose --header="Power profile:");then
return
fi
case "$selected" in
"Performance")declare -g CPU_GOVERNOR="performance";;
"Balanced")if
$has_ondemand
then
declare -g CPU_GOVERNOR="ondemand"
else
declare -g CPU_GOVERNOR="powersave"
fi
;;
"Adaptive")declare -g CPU_GOVERNOR="schedutil";;
"Conservative")declare -g CPU_GOVERNOR="conservative"
esac
}
_edit_features_security(){
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
_edit_features_monitoring(){
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
_edit_features_tools(){
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
_postfix_configure_relay(){
_wiz_start_edit
_wiz_description \
"  SMTP Relay Configuration:" \
"" \
"  Configure external SMTP server for sending mail." \
"  Common providers: Gmail, Mailgun, SendGrid, AWS SES" \
""
_wiz_input_validated "SMTP_RELAY_HOST" "validate_smtp_host" \
"Invalid host. Enter hostname, FQDN, or IP address." \
--placeholder "smtp.example.com" \
--value "${SMTP_RELAY_HOST:-smtp.gmail.com}" \
--prompt "SMTP Host: "||return 1
_wiz_input_validated "SMTP_RELAY_PORT" "validate_smtp_port" \
"Invalid port. Enter a number between 1 and 65535." \
--placeholder "587" \
--value "${SMTP_RELAY_PORT:-587}" \
--prompt "SMTP Port: "||return 1
_wiz_input_validated "SMTP_RELAY_USER" "validate_email" \
"Invalid email format." \
--placeholder "user@example.com" \
--value "$SMTP_RELAY_USER" \
--prompt "Username: "||return 1
_wiz_input_validated "SMTP_RELAY_PASSWORD" "validate_not_empty" \
"Password cannot be empty." \
--password \
--placeholder "App password or API key" \
--value "$SMTP_RELAY_PASSWORD" \
--prompt "Password: "||return 1
return 0
}
_postfix_enable(){
declare -g INSTALL_POSTFIX="yes"
_postfix_configure_relay||{
declare -g INSTALL_POSTFIX="no"
declare -g SMTP_RELAY_HOST=""
declare -g SMTP_RELAY_PORT=""
declare -g SMTP_RELAY_USER=""
declare -g SMTP_RELAY_PASSWORD=""
}
}
_postfix_disable(){
declare -g INSTALL_POSTFIX="no"
declare -g SMTP_RELAY_HOST=""
declare -g SMTP_RELAY_PORT=""
declare -g SMTP_RELAY_USER=""
declare -g SMTP_RELAY_PASSWORD=""
}
_edit_postfix(){
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
if [[ $result -eq 1 ]];then
return
elif [[ $result -eq 2 ]];then
_postfix_enable
else
_postfix_disable
fi
}
prepare_packages(){
log_info "Starting package preparation"
log_info "Adding Proxmox repository"
printf '%s\n' "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" >/etc/apt/sources.list.d/pve.list
log_info "Downloading Proxmox GPG key"
curl -fsSL -o /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg >>"$LOG_FILE" 2>&1&
local bg_pid="$!"
if [[ -z $bg_pid || ! $bg_pid =~ ^[0-9]+$ ]];then
log_error "Failed to start background job for GPG key download"
print_error "Failed to start download process"
exit 1
fi
show_progress "$bg_pid" "Adding Proxmox repository" "Proxmox repository added"
wait "$bg_pid"
local exit_code="$?"
if [[ $exit_code -ne 0 ]];then
log_error "Failed to download Proxmox GPG key"
print_error "Cannot reach Proxmox repository"
exit 1
fi
log_info "Proxmox GPG key downloaded successfully"
if type live_log_subtask &>/dev/null 2>&1;then
live_log_subtask "Configuring APT sources"
fi
log_info "Updating package lists"
apt-get clean >>"$LOG_FILE" 2>&1
apt-get update >>"$LOG_FILE" 2>&1&
bg_pid="$!"
if [[ -z $bg_pid || ! $bg_pid =~ ^[0-9]+$ ]];then
log_error "Failed to start background job for package list update"
exit 1
fi
show_progress "$bg_pid" "Updating package lists" "Package lists updated"
wait "$bg_pid"
exit_code="$?"
if [[ $exit_code -ne 0 ]];then
log_error "Failed to update package lists"
exit 1
fi
log_info "Package lists updated successfully"
if type live_log_subtask &>/dev/null 2>&1;then
live_log_subtask "Downloading package lists"
fi
log_info "Installing required packages: proxmox-auto-install-assistant xorriso ovmf wget sshpass"
apt-get install -yq proxmox-auto-install-assistant xorriso ovmf wget sshpass >>"$LOG_FILE" 2>&1&
bg_pid="$!"
if [[ -z $bg_pid || ! $bg_pid =~ ^[0-9]+$ ]];then
log_error "Failed to start background job for package installation"
exit 1
fi
show_progress "$bg_pid" "Installing required packages" "Required packages installed"
wait "$bg_pid"
exit_code="$?"
if [[ $exit_code -ne 0 ]];then
log_error "Failed to install required packages"
exit 1
fi
log_info "Required packages installed successfully"
if type live_log_subtask &>/dev/null 2>&1;then
live_log_subtask "Installing proxmox-auto-install-assistant"
live_log_subtask "Installing xorriso and ovmf"
fi
}
is_uefi_mode(){
[[ -d /sys/firmware/efi ]]
}
setup_qemu_config(){
log_info "Setting up QEMU configuration"
if is_uefi_mode;then
declare -g UEFI_OPTS="-bios /usr/share/ovmf/OVMF.fd"
log_info "UEFI mode detected"
else
declare -g UEFI_OPTS=""
log_info "Legacy BIOS mode"
fi
declare -g KVM_OPTS="-enable-kvm"
declare -g CPU_OPTS="-cpu host"
log_info "Using KVM acceleration"
local available_cores available_ram_mb
available_cores=$(nproc)
available_ram_mb=$(free -m|awk '/^Mem:/{print $2}')
log_info "Available cores: $available_cores, Available RAM: ${available_ram_mb}MB"
if [[ -n $QEMU_CORES_OVERRIDE ]];then
declare -g QEMU_CORES="$QEMU_CORES_OVERRIDE"
log_info "Using user-specified cores: $QEMU_CORES"
else
declare -g QEMU_CORES="$available_cores"
[[ $QEMU_CORES -lt $MIN_CPU_CORES ]]&&declare -g QEMU_CORES="$MIN_CPU_CORES"
fi
if [[ -n $QEMU_RAM_OVERRIDE ]];then
declare -g QEMU_RAM="$QEMU_RAM_OVERRIDE"
log_info "Using user-specified RAM: ${QEMU_RAM}MB"
if [[ $QEMU_RAM -gt $((available_ram_mb-QEMU_MIN_RAM_RESERVE)) ]];then
print_warning "Requested QEMU RAM (${QEMU_RAM}MB) may exceed safe limits (available: ${available_ram_mb}MB)"
fi
else
declare -g QEMU_RAM="$((available_ram_mb-QEMU_MIN_RAM_RESERVE))"
[[ $QEMU_RAM -lt $MIN_QEMU_RAM ]]&&declare -g QEMU_RAM="$MIN_QEMU_RAM"
fi
log_info "QEMU config: $QEMU_CORES vCPUs, ${QEMU_RAM}MB RAM"
if ! load_virtio_mapping;then
log_error "Failed to load virtio mapping"
return 1
fi
if [[ ${#VIRTIO_MAP[@]} -eq 0 ]];then
log_error "VIRTIO_MAP is empty - no disks mapped for QEMU"
print_error "No disk-to-virtio mappings found. Ensure ZFS pool disks were selected in wizard storage configuration."
return 1
fi
declare -g DRIVE_ARGS=""
declare -A REVERSE_MAP
local disk vdev
for disk in "${!VIRTIO_MAP[@]}";do
vdev="${VIRTIO_MAP[$disk]}"
REVERSE_MAP["$vdev"]="$disk"
done
local sorted_vdevs
sorted_vdevs=$(printf '%s\n' "${!REVERSE_MAP[@]}"|sort)
for vdev in $sorted_vdevs;do
disk="${REVERSE_MAP[$vdev]}"
if [[ ! -b $disk ]];then
log_error "Disk $disk does not exist or is not a block device"
return 1
fi
log_info "QEMU drive order: $vdev -> $disk"
declare -g DRIVE_ARGS="$DRIVE_ARGS -drive file=$disk,format=raw,media=disk,if=virtio"
done
if [[ -z $DRIVE_ARGS ]];then
log_error "No drive arguments built - QEMU would start without disks"
return 1
fi
log_info "Drive args: $DRIVE_ARGS"
}
_signal_process(){
local pid="$1"
local signal="$2"
local message="$3"
if kill -0 "$pid" 2>/dev/null;then
log_info "$message"
kill "-$signal" "$pid" 2>/dev/null||true
fi
}
_kill_processes_by_pattern(){
local pattern="$1"
local pids
pids=$(pgrep -f "$pattern" 2>/dev/null||true)
if [[ -n $pids ]];then
log_info "Found processes matching '$pattern': $pids"
for pid in $pids;do
_signal_process "$pid" "TERM" "Sending TERM to process $pid"
done
sleep "${WIZARD_MESSAGE_DELAY:-3}"
for pid in $pids;do
_signal_process "$pid" "9" "Force killing process $pid"
done
sleep "${PROCESS_KILL_WAIT:-1}"
fi
pkill -f -TERM "$pattern" 2>/dev/null||true
sleep "${PROCESS_KILL_WAIT:-1}"
pkill -f -9 "$pattern" 2>/dev/null||true
}
_stop_mdadm_arrays(){
if ! cmd_exists mdadm;then
return 0
fi
log_info "Stopping mdadm arrays..."
mdadm --stop --scan 2>/dev/null||true
for md in /dev/md*;do
if [[ -b $md ]];then
mdadm --stop "$md" 2>/dev/null||true
fi
done
}
_deactivate_lvm(){
if ! cmd_exists pvs;then
return 0
fi
log_info "Deactivating LVM volume groups..."
vgchange -an &>/dev/null||true
if cmd_exists vgs;then
while IFS= read -r vg;do
if [[ -n $vg ]];then vgchange -an "$vg" &>/dev/null||true;fi
done < <(vgs --noheadings -o vg_name 2>/dev/null)
fi
}
_unmount_drive_filesystems(){
[[ -z ${DRIVES[*]} ]]&&return 0
log_info "Unmounting filesystems on target drives..."
for drive in "${DRIVES[@]}";do
if cmd_exists findmnt;then
while IFS= read -r mountpoint;do
[[ -z $mountpoint ]]&&continue
log_info "Unmounting $mountpoint"
umount -f "$mountpoint" 2>/dev/null||true
done < <(findmnt -rn -o TARGET "$drive"* 2>/dev/null)
else
local drive_name
drive_name=$(basename "$drive")
while IFS= read -r mountpoint;do
[[ -z $mountpoint ]]&&continue
log_info "Unmounting $mountpoint"
umount -f "$mountpoint" 2>/dev/null||true
done < <(mount|grep -E "(^|/)$drive_name"|awk '{print $3}')
fi
done
}
_kill_drive_holders(){
[[ -z ${DRIVES[*]} ]]&&return 0
log_info "Checking for processes using drives..."
for drive in "${DRIVES[@]}";do
if cmd_exists lsof;then
while IFS= read -r pid;do
[[ -z $pid ]]&&continue
_signal_process "$pid" "9" "Killing process $pid using $drive"
done < <(lsof "$drive" 2>/dev/null|awk 'NR>1 {print $2}'|sort -u)
fi
if cmd_exists fuser;then
fuser -k "$drive" 2>/dev/null||true
fi
done
}
release_drives(){
log_info "Releasing drives from locks..."
_kill_processes_by_pattern "qemu-system-x86_64"
_stop_mdadm_arrays
_deactivate_lvm
_unmount_drive_filesystems
sleep "${RETRY_DELAY_SECONDS:-2}"
_kill_drive_holders
log_info "Drives released"
}
_modify_template_files(){
log_info "Starting template modification"
apply_common_template_vars "./templates/hosts"||return 1
if [[ ${IPV6_MODE:-} != "disabled" && -n ${MAIN_IPV6:-} ]];then
printf '%s %s %s\n' "$MAIN_IPV6" "$FQDN" "$PVE_HOSTNAME" >>"./templates/hosts"
fi
generate_interfaces_file "./templates/interfaces"||return 1
apply_common_template_vars "./templates/resolv.conf"||return 1
if [[ ${IPV6_MODE:-} != "disabled" ]];then
printf 'nameserver %s\n' "${DNS6_PRIMARY:-2606:4700:4700::1111}" >>"./templates/resolv.conf"
printf 'nameserver %s\n' "${DNS6_SECONDARY:-2606:4700:4700::1001}" >>"./templates/resolv.conf"
fi
apply_template_vars "./templates/cpupower.service" "CPU_GOVERNOR=${CPU_GOVERNOR:-performance}"||return 1
apply_common_template_vars "./templates/locale.sh"||return 1
apply_common_template_vars "./templates/default-locale"||return 1
apply_common_template_vars "./templates/environment"||return 1
log_info "Template modification complete"
}
_download_templates_parallel(){
local -a templates=("$@")
local input_file=""
input_file=$(mktemp)||{
log_error "mktemp failed for aria2c input file"
return 1
}
register_temp_file "$input_file"
for entry in "${templates[@]}";do
local local_path="${entry%%:*}"
local remote_name="${entry#*:}"
local url="$GITHUB_BASE_URL/templates/$remote_name.tmpl"
printf '%s\n' "$url"
printf '%s\n' "  out=$local_path"
done >"$input_file"
log_info "Downloading ${#templates[@]} templates in parallel"
if cmd_exists aria2c;then
if aria2c -q \
-j 16 \
--max-connection-per-server=4 \
--file-allocation=none \
--max-tries=3 \
--retry-wait=2 \
--timeout=30 \
--connect-timeout=10 \
-i "$input_file" >> \
"$LOG_FILE" 2>&1;then
rm -f "$input_file"
for entry in "${templates[@]}";do
local local_path="${entry%%:*}"
if [[ ! -s $local_path ]];then
log_error "Template $local_path is empty after aria2c download"
return 1
fi
done
return 0
fi
log_warn "aria2c failed, falling back to sequential download"
fi
rm -f "$input_file"
for entry in "${templates[@]}";do
local local_path="${entry%%:*}"
local remote_name="${entry#*:}"
if ! download_template "$local_path" "$remote_name";then
return 1
fi
done
return 0
}
make_templates(){
log_info "Starting template preparation"
mkdir -p ./templates
log_info "Using bridge mode: ${BRIDGE_MODE:-internal}"
local proxmox_sources_template="proxmox.sources"
case "${PVE_REPO_TYPE:-no-subscription}" in
enterprise)proxmox_sources_template="proxmox-enterprise.sources";;
test)proxmox_sources_template="proxmox-test.sources"
esac
log_info "Using repository template: $proxmox_sources_template"
local -a template_list=(
"./templates/99-proxmox.conf:99-proxmox.conf"
"./templates/99-limits.conf:99-limits.conf"
"./templates/hosts:hosts"
"./templates/debian.sources:debian.sources"
"./templates/proxmox.sources:$proxmox_sources_template"
"./templates/sshd_config:sshd_config"
"./templates/resolv.conf:resolv.conf"
"./templates/journald.conf:journald.conf"
"./templates/locale.sh:locale.sh"
"./templates/default-locale:default-locale"
"./templates/environment:environment"
"./templates/zshrc:zshrc"
"./templates/fastfetch.sh:fastfetch.sh"
"./templates/bat-config:bat-config"
"./templates/chrony:chrony"
"./templates/50unattended-upgrades:50unattended-upgrades"
"./templates/20auto-upgrades:20auto-upgrades"
"./templates/cpupower.service:cpupower.service"
"./templates/60-io-scheduler.rules:60-io-scheduler.rules"
"./templates/remove-subscription-nag.sh:remove-subscription-nag.sh"
"./templates/zfs-scrub.service:zfs-scrub.service"
"./templates/zfs-scrub.timer:zfs-scrub.timer"
"./templates/zfs-import-cache.service.d-override.conf:zfs-import-cache.service.d-override.conf"
"./templates/zfs-cachefile-initramfs-hook:zfs-cachefile-initramfs-hook"
"./templates/letsencrypt-deploy-hook.sh:letsencrypt-deploy-hook.sh"
"./templates/letsencrypt-firstboot.sh:letsencrypt-firstboot.sh"
"./templates/letsencrypt-firstboot.service:letsencrypt-firstboot.service"
"./templates/disable-openssh.service:disable-openssh.service"
"./templates/fail2ban-jail.local:fail2ban-jail.local"
"./templates/fail2ban-proxmox.conf:fail2ban-proxmox.conf"
"./templates/apparmor-grub.cfg:apparmor-grub.cfg"
"./templates/auditd-rules:auditd-rules"
"./templates/aide-check.service:aide-check.service"
"./templates/aide-check.timer:aide-check.timer"
"./templates/chkrootkit-scan.service:chkrootkit-scan.service"
"./templates/chkrootkit-scan.timer:chkrootkit-scan.timer"
"./templates/lynis-audit.service:lynis-audit.service"
"./templates/lynis-audit.timer:lynis-audit.timer"
"./templates/needrestart.conf:needrestart.conf"
"./templates/vnstat.conf:vnstat.conf"
"./templates/netdata.conf:netdata.conf"
"./templates/journald-netdata.conf:journald-netdata.conf"
"./templates/promtail.yml:promtail.yml"
"./templates/promtail.service:promtail.service"
"./templates/yazi.toml:yazi.toml"
"./templates/yazi-theme.toml:yazi-theme.toml"
"./templates/yazi-init.lua:yazi-init.lua"
"./templates/yazi-keymap.toml:yazi-keymap.toml"
"./templates/network-ringbuffer.service:network-ringbuffer.service"
"./templates/network-ringbuffer.sh:network-ringbuffer.sh"
"./templates/validation.sh:validation.sh")
if ! run_with_progress "Downloading template files" "Template files downloaded" \
_download_templates_parallel "${template_list[@]}";then
log_error "Failed to download template files"
exit 1
fi
if [[ -n ${PRIVATE_SUBNET:-} && $BRIDGE_MODE != "external" ]];then
if validate_subnet "$PRIVATE_SUBNET";then
declare -g PRIVATE_IP_CIDR="${PRIVATE_SUBNET%.*}.1/${PRIVATE_SUBNET#*/}"
export PRIVATE_IP_CIDR
log_info "Derived PRIVATE_IP_CIDR=$PRIVATE_IP_CIDR from PRIVATE_SUBNET=$PRIVATE_SUBNET"
else
log_error "Invalid PRIVATE_SUBNET format: $PRIVATE_SUBNET (expected CIDR like 10.0.0.0/24)"
return 1
fi
fi
if ! run_with_progress "Modifying template files" "Template files modified" _modify_template_files;then
log_error "Template modification failed"
return 1
fi
}
_download_iso_curl(){
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
_download_iso_wget(){
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
_download_iso_aria2c(){
local url="$1"
local output="$2"
local checksum="$3"
local max_retries="${DOWNLOAD_RETRY_COUNT:-3}"
log_info "Downloading with aria2c (4 connections, with retries)"
local aria2_args=(
-x 4
-s 4
-k 4M
--max-tries="$max_retries"
--retry-wait=5
--timeout=60
--connect-timeout=30
--max-connection-per-server=4
--allow-overwrite=true
--auto-file-renaming=false
-o "$output"
--console-log-level=error
--summary-interval=0)
if [[ -n $checksum ]];then
aria2_args+=(--checksum=sha-256="$checksum")
log_info "aria2c will verify checksum automatically"
fi
aria2c "${aria2_args[@]}" "$url" >>"$LOG_FILE" 2>&1
}
_download_iso_with_fallback(){
local url="$1"
local output="$2"
local checksum="$3"
local method_file="${4:-}"
if cmd_exists aria2c;then
log_info "Trying aria2c (parallel download)..."
if _download_iso_aria2c "$url" "$output" "$checksum"&&[[ -s $output ]];then
[[ -n $method_file ]]&&printf '%s\n' "aria2c" >"$method_file"
return 0
fi
log_info "aria2c failed, trying fallback..."
rm -f "$output" 2>/dev/null
fi
log_info "Trying curl..."
if _download_iso_curl "$url" "$output"&&[[ -s $output ]];then
[[ -n $method_file ]]&&printf '%s\n' "curl" >"$method_file"
return 0
fi
log_info "curl failed, trying fallback..."
rm -f "$output" 2>/dev/null
if cmd_exists wget;then
log_info "Trying wget..."
if _download_iso_wget "$url" "$output"&&[[ -s $output ]];then
[[ -n $method_file ]]&&printf '%s\n' "wget" >"$method_file"
return 0
fi
rm -f "$output" 2>/dev/null
fi
log_info "All download methods failed"
return 1
}
_ISO_LIST_CACHE=""
_CHECKSUM_CACHE=""
prefetch_proxmox_iso_info(){
declare -g _ISO_LIST_CACHE
declare -g _CHECKSUM_CACHE
_ISO_LIST_CACHE="$(curl -s "$PROXMOX_ISO_BASE_URL" 2>/dev/null|grep -oE 'proxmox-ve_[0-9]+\.[0-9]+-[0-9]+\.iso'|sort -uV)"||true
_CHECKSUM_CACHE="$(curl -s "$PROXMOX_CHECKSUM_URL" 2>/dev/null)"||true
}
get_available_proxmox_isos(){
local count="${1:-5}"
printf '%s\n' "$_ISO_LIST_CACHE"|grep -E '^proxmox-ve_(9|[1-9][0-9]+)\.'|tail -n "$count"|tac
}
get_proxmox_iso_url(){
local iso_filename="$1"
printf '%s\n' "$PROXMOX_ISO_BASE_URL$iso_filename"
}
get_iso_version(){
local iso_filename="$1"
printf '%s\n' "$iso_filename"|sed -E 's/proxmox-ve_([0-9]+\.[0-9]+-[0-9]+)\.iso/\1/'
}
_download_iso(){
log_info "Starting Proxmox ISO download"
if [[ -f "pve.iso" ]];then
log_info "Proxmox ISO already exists, skipping download"
return 0
fi
if [[ -z $PROXMOX_ISO_VERSION ]];then
log_error "PROXMOX_ISO_VERSION not set"
return 1
fi
log_info "Using selected ISO: $PROXMOX_ISO_VERSION"
declare -g PROXMOX_ISO_URL
PROXMOX_ISO_URL="$(get_proxmox_iso_url "$PROXMOX_ISO_VERSION")"
log_info "Found ISO URL: $PROXMOX_ISO_URL"
declare -g ISO_FILENAME
ISO_FILENAME="$(basename "$PROXMOX_ISO_URL")"
local expected_checksum=""
if [[ -n $_CHECKSUM_CACHE ]];then
expected_checksum="$(printf '%s\n' "$_CHECKSUM_CACHE"|grep "$ISO_FILENAME"|awk '{print $1}')"
fi
log_info "Expected checksum: ${expected_checksum:-not available}"
log_info "Downloading ISO: $ISO_FILENAME"
local method_file=""
method_file=$(mktemp)||{
log_error "mktemp failed for method_file"
return 1
}
register_temp_file "$method_file"
_download_iso_with_fallback "$PROXMOX_ISO_URL" "pve.iso" "$expected_checksum" "$method_file"
local exit_code="$?"
declare -g DOWNLOAD_METHOD
DOWNLOAD_METHOD="$(cat "$method_file" 2>/dev/null)"
rm -f "$method_file"
if [[ $exit_code -ne 0 ]]||[[ ! -s "pve.iso" ]];then
log_error "All download methods failed for Proxmox ISO"
rm -f pve.iso
return 1
fi
log_info "Download successful via $DOWNLOAD_METHOD"
local iso_size
iso_size="$(stat -c%s pve.iso 2>/dev/null)"||iso_size=0
log_info "ISO file size: $(printf '%s\n' "$iso_size"|awk '{printf "%.1fG", $1/1024/1024/1024}')"
if [[ -n $expected_checksum ]];then
if [[ $DOWNLOAD_METHOD == "aria2c" ]];then
log_info "Checksum already verified by aria2c"
else
log_info "Verifying ISO checksum"
local actual_checksum
actual_checksum=$(sha256sum pve.iso|awk '{print $1}')
if [[ $actual_checksum != "$expected_checksum" ]];then
log_error "Checksum mismatch! Expected: $expected_checksum, Got: $actual_checksum"
rm -f pve.iso
return 1
fi
log_info "Checksum verification passed"
fi
else
log_warn "Could not find checksum for $ISO_FILENAME"
fi
log_info "Cleaning up temporary files in /tmp"
rm -rf /tmp/pve-* /tmp/aria2-* 2>/dev/null||true
log_info "Temporary files cleaned"
}
_parallel_download_iso(){
_download_iso||return 1
parallel_mark_configured "ISO downloaded"
}
validate_answer_toml(){
local file="$1"
local required_fields=("fqdn" "mailto" "timezone" "root-password")
for field in "${required_fields[@]}";do
if ! grep -q "^\s*$field\s*=" "$file" 2>/dev/null;then
log_error "Missing required field in answer.toml: $field"
return 1
fi
done
if ! grep -q "\[global\]" "$file" 2>/dev/null;then
log_error "Missing [global] section in answer.toml"
return 1
fi
if cmd_exists proxmox-auto-install-assistant;then
log_info "Validating answer.toml with proxmox-auto-install-assistant"
if ! proxmox-auto-install-assistant validate-answer "$file" >>"$LOG_FILE" 2>&1;then
log_error "answer.toml validation failed"
proxmox-auto-install-assistant validate-answer "$file" >>"$LOG_FILE" 2>&1||true
return 1
fi
log_info "answer.toml validation passed"
else
log_warn "proxmox-auto-install-assistant not found, skipping advanced validation"
fi
return 0
}
_make_answer_toml(){
log_info "Creating answer.toml for autoinstall"
log_debug "ZFS_RAID=$ZFS_RAID, BOOT_DISK=$BOOT_DISK"
log_debug "ZFS_POOL_DISKS=(${ZFS_POOL_DISKS[*]})"
log_debug "USE_EXISTING_POOL=$USE_EXISTING_POOL, EXISTING_POOL_NAME=$EXISTING_POOL_NAME"
log_debug "EXISTING_POOL_DISKS=(${EXISTING_POOL_DISKS[*]})"
local virtio_pool_disks=()
if [[ $USE_EXISTING_POOL == "yes" ]];then
log_info "Using existing pool mode - existing pool disks will be passed to QEMU for import"
for disk in "${EXISTING_POOL_DISKS[@]}";do
if [[ -b $disk ]];then
virtio_pool_disks+=("$disk")
else
log_warn "Pool disk $disk does not exist on host, skipping"
fi
done
else
virtio_pool_disks=("${ZFS_POOL_DISKS[@]}")
fi
log_info "Creating virtio disk mapping"
create_virtio_mapping "$BOOT_DISK" "${virtio_pool_disks[@]}"||{
log_error "Failed to create virtio mapping"
return 1
}
load_virtio_mapping||{
log_error "Failed to load virtio mapping"
return 1
}
local FILESYSTEM
local all_disks=()
if [[ -n $BOOT_DISK ]];then
FILESYSTEM="ext4"
all_disks=("$BOOT_DISK")
if [[ $USE_EXISTING_POOL == "yes" ]];then
if [[ -z $EXISTING_POOL_NAME ]];then
log_error "USE_EXISTING_POOL=yes but EXISTING_POOL_NAME is empty"
return 1
fi
log_info "Boot disk mode: ext4 on boot disk, existing pool '$EXISTING_POOL_NAME' will be imported"
else
if [[ ${#ZFS_POOL_DISKS[@]} -eq 0 ]];then
log_info "Boot disk mode: ext4 on boot disk only, no separate ZFS pool"
else
log_info "Boot disk mode: ext4 on boot disk, ZFS 'tank' pool will be created from ${#ZFS_POOL_DISKS[@]} pool disk(s)"
fi
fi
else
FILESYSTEM="zfs"
all_disks=("${ZFS_POOL_DISKS[@]}")
log_info "All-ZFS mode: ${#all_disks[@]} disk(s) in ZFS rpool ($ZFS_RAID)"
fi
declare -g DISK_LIST
DISK_LIST=$(map_disks_to_virtio "toml_array" "${all_disks[@]}")
if [[ -z $DISK_LIST ]];then
log_error "Failed to map disks to virtio devices"
return 1
fi
log_debug "FILESYSTEM=$FILESYSTEM, DISK_LIST=$DISK_LIST"
log_info "Generating answer.toml for autoinstall"
local escaped_password="$NEW_ROOT_PASSWORD" test_pwd="$NEW_ROOT_PASSWORD"
for c in $'\t' $'\n' $'\r' $'\b' $'\f';do test_pwd="${test_pwd//$c/}";done
[[ $test_pwd =~ [[:cntrl:]] ]]&&{
log_error "Password has unsupported control chars"
return 1
}
escaped_password="${escaped_password//\\/\\\\}"
escaped_password="${escaped_password//\"/\\\"}"
escaped_password="${escaped_password//$'\t'/\\t}"
escaped_password="${escaped_password//$'\n'/\\n}"
escaped_password="${escaped_password//$'\r'/\\r}"
escaped_password="${escaped_password//$'\b'/\\b}"
escaped_password="${escaped_password//$'\f'/\\f}"
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
if [[ $FILESYSTEM == "zfs" ]];then
local zfs_raid_value
zfs_raid_value=$(map_raid_to_toml "$ZFS_RAID")
log_info "Using ZFS raid: $zfs_raid_value"
cat >>./answer.toml <<EOF
    zfs.raid = "$zfs_raid_value"
    zfs.compress = "lz4"
    zfs.checksum = "on"
EOF
elif [[ $FILESYSTEM == "ext4" ]]||[[ $FILESYSTEM == "xfs" ]];then
cat >>./answer.toml <<EOF
    lvm.swapsize = 0
    lvm.maxroot = 0
    lvm.maxvz = 0
EOF
fi
if ! validate_answer_toml "./answer.toml";then
log_error "answer.toml validation failed"
return 1
fi
log_info "answer.toml created and validated:"
sed 's/^\([[:space:]]*root-password[[:space:]]*=[[:space:]]*\).*/\1"[REDACTED]"/' answer.toml >>"$LOG_FILE"
}
_parallel_make_toml(){
_make_answer_toml||return 1
parallel_mark_configured "answer.toml created"
}
make_autoinstall_iso(){
log_info "Creating autoinstall ISO"
log_info "Input: pve.iso exists: $(test -f pve.iso&&echo 'yes'||echo 'no')"
log_info "Input: answer.toml exists: $(test -f answer.toml&&echo 'yes'||echo 'no')"
log_info "Current directory: $(pwd)"
proxmox-auto-install-assistant prepare-iso pve.iso --fetch-from iso --answer-file answer.toml --output pve-autoinstall.iso >>"$LOG_FILE" 2>&1&
show_progress "$!" "Creating autoinstall ISO" "Autoinstall ISO created"
local exit_code="$?"
if [[ $exit_code -ne 0 ]];then
log_warn "proxmox-auto-install-assistant exited with code $exit_code"
fi
if [[ ! -f "./pve-autoinstall.iso" ]];then
log_error "Autoinstall ISO not found after creation attempt"
exit 1
fi
log_info "Autoinstall ISO created successfully: $(stat -c%s pve-autoinstall.iso 2>/dev/null|awk '{printf "%.1fM", $1/1024/1024}')"
if type live_log_subtask &>/dev/null 2>&1;then
live_log_subtask "Packed ISO with xorriso"
fi
log_info "Removing original ISO to save disk space"
rm -f pve.iso
}
install_proxmox(){
local qemu_config_file
qemu_config_file=$(mktemp)||{
log_error "Failed to create temp file for QEMU config"
exit 1
}
register_temp_file "$qemu_config_file"
(if
! setup_qemu_config
then
log_error "QEMU configuration failed"
exit 1
fi
cat >"$qemu_config_file" <<EOF
QEMU_CORES=$QEMU_CORES
QEMU_RAM=$QEMU_RAM
UEFI_MODE=$(is_uefi_mode&&echo "yes"||echo "no")
KVM_OPTS='$KVM_OPTS'
UEFI_OPTS='$UEFI_OPTS'
CPU_OPTS='$CPU_OPTS'
DRIVE_ARGS='$DRIVE_ARGS'
EOF
if [[ ! -f "./pve-autoinstall.iso" ]];then
print_error "Autoinstall ISO not found!"
exit 1
fi
release_drives) \
&
local prep_pid="$!"
local timeout=10
while [[ ! -s $qemu_config_file ]]&&((timeout>0));do
sleep 0.1
((timeout--))
done
if [[ -s $qemu_config_file ]];then
if grep -qvE '^(QEMU_CORES|QEMU_RAM|UEFI_MODE|KVM_OPTS|UEFI_OPTS|CPU_OPTS|DRIVE_ARGS)=' "$qemu_config_file";then
log_error "QEMU config file contains unexpected content"
rm -f "$qemu_config_file"
exit 1
fi
source "$qemu_config_file"
rm -f "$qemu_config_file"
fi
show_progress "$prep_pid" "Starting QEMU ($QEMU_CORES vCPUs, ${QEMU_RAM}MB RAM)" "QEMU started ($QEMU_CORES vCPUs, ${QEMU_RAM}MB RAM)"
if [[ $UEFI_MODE == "yes" ]];then
live_log_subtask "UEFI mode detected"
else
live_log_subtask "Legacy BIOS mode"
fi
live_log_subtask "KVM acceleration enabled"
live_log_subtask "Configured $QEMU_CORES vCPUs, ${QEMU_RAM}MB RAM"
qemu-system-x86_64 $KVM_OPTS $UEFI_OPTS \
$CPU_OPTS -smp "$QEMU_CORES" -m "$QEMU_RAM" \
-boot d -cdrom ./pve-autoinstall.iso \
$DRIVE_ARGS -no-reboot -display none >qemu_install.log 2>&1&
local qemu_pid="$!"
sleep "${RETRY_DELAY_SECONDS:-2}"
if ! kill -0 "$qemu_pid" 2>/dev/null;then
log_error "QEMU failed to start"
log_info "QEMU install log:"
cat qemu_install.log >>"$LOG_FILE" 2>&1
exit 1
fi
local install_timeout="${QEMU_INSTALL_TIMEOUT:-300}"
local check_interval=5
(elapsed=0
while kill -0 "$qemu_pid" 2>/dev/null&&((elapsed<install_timeout));do
sleep "$check_interval"
((elapsed+=check_interval))
done
if kill -0 "$qemu_pid" 2>/dev/null;then
log_error "Installation timeout after ${install_timeout}s - killing QEMU"
kill -TERM "$qemu_pid" 2>/dev/null
sleep 2
kill -KILL "$qemu_pid" 2>/dev/null
exit 1
fi
exit 0) \
&
local wait_pid="$!"
show_progress "$wait_pid" "Installing Proxmox VE" "Proxmox VE installed"
local exit_code="$?"
if [[ $exit_code -ne 0 ]];then
log_error "QEMU installation failed (timeout or error)"
log_info "QEMU install log:"
cat qemu_install.log >>"$LOG_FILE" 2>&1
exit 1
fi
}
boot_proxmox_with_port_forwarding(){
_deactivate_lvm
if ! setup_qemu_config;then
log_error "QEMU configuration failed in boot_proxmox_with_port_forwarding"
return 1
fi
if ! check_port_available "$SSH_PORT";then
print_error "Port $SSH_PORT is already in use"
log_error "Port $SSH_PORT is already in use"
exit 1
fi
nohup qemu-system-x86_64 $KVM_OPTS $UEFI_OPTS \
$CPU_OPTS -device e1000,netdev=net0 \
-netdev user,id=net0,hostfwd=tcp::$SSH_PORT_QEMU-:22 \
-smp "$QEMU_CORES" -m "$QEMU_RAM" \
$DRIVE_ARGS -display none > \
qemu_output.log 2>&1&
declare -g QEMU_PID="$!"
local timeout="${QEMU_BOOT_TIMEOUT:-300}"
local check_interval="${QEMU_PORT_CHECK_INTERVAL:-3}"
(elapsed=0
while ((elapsed<timeout));do
if exec 3<>/dev/tcp/localhost/"$SSH_PORT_QEMU" 2>/dev/null;then
exec 3<&-
exit 0
fi
sleep "$check_interval"
((elapsed+=check_interval))
done
exit 1) 2> \
/dev/null&
local wait_pid="$!"
show_progress "$wait_pid" "Booting installed Proxmox" "Proxmox booted"
local exit_code="$?"
if [[ $exit_code -ne 0 ]];then
log_error "Timeout waiting for SSH port"
log_info "QEMU output log:"
cat qemu_output.log >>"$LOG_FILE" 2>&1
return 1
fi
wait_for_ssh_ready "${QEMU_SSH_READY_TIMEOUT:-120}"||{
log_error "SSH connection failed"
log_info "QEMU output log:"
cat qemu_output.log >>"$LOG_FILE" 2>&1
return 1
}
}
_escape_regex(){
printf '%s' "$1"|sed 's/[[\.*^$(){}?+|]/\\&/g'
}
_get_disks_to_wipe(){
local disks=()
local -A seen=()
if [[ $USE_EXISTING_POOL == "yes" ]];then
[[ -n $BOOT_DISK ]]&&disks+=("$BOOT_DISK")
else
if [[ -n $BOOT_DISK ]];then
disks+=("$BOOT_DISK")
seen["$BOOT_DISK"]=1
fi
for disk in "${ZFS_POOL_DISKS[@]}";do
[[ -z ${seen["$disk"]+x} ]]&&disks+=("$disk")&&seen["$disk"]=1
done
fi
printf '%s\n' "${disks[@]}"
}
_wipe_zfs_on_disk(){
local disk="$1"
local disk_name escaped_disk_name
disk_name=$(basename "$disk")
escaped_disk_name=$(_escape_regex "$disk_name")
cmd_exists zpool||return 0
local pools_to_destroy=()
while IFS= read -r pool;do
[[ -z $pool ]]&&continue
if zpool status "$pool" 2>/dev/null|grep -qE "(^|[[:space:]])$escaped_disk_name([p0-9]*)?([[:space:]]|$)";then
pools_to_destroy+=("$pool")
fi
done < <(zpool list -H -o name 2>/dev/null)
local import_output
import_output=$(zpool import 2>&1)||true
if [[ -n $import_output && $import_output != *"no pools available"* ]];then
local current_pool=""
local pool_has_disk=false
while IFS= read -r line;do
if [[ $line =~ ^[[:space:]]*pool:[[:space:]]*(.+)$ ]];then
if [[ $pool_has_disk == true && -n $current_pool ]];then
local already=false
for p in "${pools_to_destroy[@]}";do
[[ $p == "$current_pool" ]]&&already=true&&break
done
[[ $already == false ]]&&pools_to_destroy+=("$current_pool")
fi
current_pool="${BASH_REMATCH[1]}"
pool_has_disk=false
elif [[ $line =~ $escaped_disk_name ]];then
pool_has_disk=true
fi
done <<<"$import_output"
if [[ $pool_has_disk == true && -n $current_pool ]];then
local already=false
for p in "${pools_to_destroy[@]}";do
[[ $p == "$current_pool" ]]&&already=true&&break
done
[[ $already == false ]]&&pools_to_destroy+=("$current_pool")
fi
fi
for pool in "${pools_to_destroy[@]}";do
log_info "Destroying ZFS pool: $pool (contains $disk)"
zpool export -f "$pool" 2>/dev/null||true
zpool destroy -f "$pool" 2>/dev/null||true
done
for part in "$disk"*;do
[[ -b $part ]]&&zpool labelclear -f "$part" 2>/dev/null||true
done
}
_wipe_lvm_on_disk(){
local disk="$1"
cmd_exists pvs||return 0
local pvs_on_disk=()
while IFS= read -r pv;do
[[ -z $pv ]]&&continue
[[ $pv == "$disk"* ]]&&pvs_on_disk+=("$pv")
done < <(pvs --noheadings -o pv_name 2>/dev/null|tr -d ' ')
for pv in "${pvs_on_disk[@]}";do
local vg
vg=$(pvs --noheadings -o vg_name "$pv" 2>/dev/null|tr -d ' ')
if [[ -n $vg ]];then
log_info "Removing LVM VG: $vg (on $pv)"
vgchange -an "$vg" 2>/dev/null||true
vgremove -f "$vg" 2>/dev/null||true
fi
log_info "Removing LVM PV: $pv"
pvremove -f "$pv" 2>/dev/null||true
done
}
_wipe_mdadm_on_disk(){
local disk="$1"
local disk_name escaped_disk_name
disk_name=$(basename "$disk")
escaped_disk_name=$(_escape_regex "$disk_name")
cmd_exists mdadm||return 0
while IFS= read -r md;do
[[ -z $md ]]&&continue
if mdadm --detail "$md" 2>/dev/null|grep -q "$escaped_disk_name";then
log_info "Stopping mdadm array: $md (contains $disk)"
mdadm --stop "$md" 2>/dev/null||true
fi
done < <(ls /dev/md* 2>/dev/null)
for part in "$disk"*;do
[[ -b $part ]]&&mdadm --zero-superblock "$part" 2>/dev/null||true
done
}
_wipe_partition_table(){
local disk="$1"
log_info "Wiping partition table: $disk"
if cmd_exists wipefs;then
wipefs -a -f "$disk" 2>/dev/null||true
fi
if cmd_exists sgdisk;then
sgdisk --zap-all "$disk" 2>/dev/null||true
fi
dd if=/dev/zero of="$disk" bs=1M count=1 conv=notrunc 2>/dev/null||true
local disk_size
disk_size=$(blockdev --getsize64 "$disk" 2>/dev/null||echo 0)
if [[ $disk_size -gt 1048576 ]];then
dd if=/dev/zero of="$disk" bs=1M count=1 seek=$((disk_size/1048576-1)) conv=notrunc 2>/dev/null||true
fi
partprobe "$disk" 2>/dev/null||true
blockdev --rereadpt "$disk" 2>/dev/null||true
}
_wipe_disk(){
local disk="$1"
[[ ! -b $disk ]]&&{
log_warn "Disk not found: $disk"
return 0
}
log_info "Wiping disk: $disk"
_wipe_zfs_on_disk "$disk"
_wipe_lvm_on_disk "$disk"
_wipe_mdadm_on_disk "$disk"
_wipe_partition_table "$disk"
}
wipe_installation_disks(){
[[ $WIPE_DISKS != "yes" ]]&&{
log_info "Disk wipe disabled, skipping"
return 0
}
local disks
mapfile -t disks < <(_get_disks_to_wipe)
if [[ ${#disks[@]} -eq 0 ]];then
log_warn "No disks to wipe"
return 0
fi
if [[ $USE_EXISTING_POOL == "yes" ]];then
log_info "Wiping boot disk only (preserving existing pool): ${disks[*]}"
else
log_info "Wiping ${#disks[@]} disk(s): ${disks[*]}"
fi
for disk in "${disks[@]}";do
_wipe_disk "$disk"
done
sync
sleep 1
log_info "Disk wipe complete"
}
_copy_config_files(){
remote_exec "mkdir -p /etc/systemd/journald.conf.d"||return 1
run_batch_copies \
"templates/hosts:/etc/hosts" \
"templates/interfaces:/etc/network/interfaces" \
"templates/99-proxmox.conf:/etc/sysctl.d/99-proxmox.conf" \
"templates/debian.sources:/etc/apt/sources.list.d/debian.sources" \
"templates/proxmox.sources:/etc/apt/sources.list.d/proxmox.sources" \
"templates/resolv.conf:/etc/resolv.conf" \
"templates/journald.conf:/etc/systemd/journald.conf.d/00-proxmox.conf"
}
_apply_basic_settings(){
remote_exec "[ -f /etc/apt/sources.list ] && mv /etc/apt/sources.list /etc/apt/sources.list.bak"||return 1
remote_exec "echo '$PVE_HOSTNAME' > /etc/hostname"||return 1
remote_exec "systemctl disable --now rpcbind rpcbind.socket nfs-blkmap.service 2>/dev/null"||{
log_warn "Failed to disable rpcbind/nfs-blkmap"
}
remote_exec "systemctl mask nfs-blkmap.service 2>/dev/null"||true
}
_config_base_system(){
run_with_progress "Copying configuration files" "Configuration files copied" _copy_config_files
run_with_progress "Applying sysctl settings" "Sysctl settings applied" remote_exec "sysctl --system"
run_with_progress "Applying basic system settings" "Basic system settings applied" _apply_basic_settings
log_debug "configure_base_system: PVE_REPO_TYPE=${PVE_REPO_TYPE:-no-subscription}"
if [[ ${PVE_REPO_TYPE:-no-subscription} == "enterprise" ]];then
log_info "configure_base_system: configuring enterprise repository"
remote_run "Configuring enterprise repository" '
            for repo_file in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
                [[ -f "$repo_file" ]] || continue
                if grep -q "pve-no-subscription\|pvetest" "$repo_file" 2>/dev/null; then
                    mv "$repo_file" "${repo_file}.disabled"
                fi
            done
        ' "Enterprise repository configured"
if [[ -n $PVE_SUBSCRIPTION_KEY ]];then
log_info "configure_base_system: registering subscription key"
remote_run "Registering subscription key" \
"pvesubscription set '$PVE_SUBSCRIPTION_KEY' 2>/dev/null || true" \
"Subscription key registered"
fi
else
log_info "configure_base_system: configuring ${PVE_REPO_TYPE:-no-subscription} repository"
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
install_base_packages
local locale_name="${LOCALE%%.UTF-8}"
remote_run "Configuring UTF-8 locales" "
        set -e
        sed -i 's/# $locale_name.UTF-8/$locale_name.UTF-8/' /etc/locale.gen
        sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
        locale-gen
        update-locale LANG=$LOCALE LC_ALL=$LOCALE
    " "UTF-8 locales configured"
run_with_progress "Installing locale configuration files" "Locale files installed" _install_locale_files
run_with_progress "Configuring fastfetch" "Fastfetch configured" _configure_fastfetch
run_with_progress "Configuring bat" "Bat configured" _configure_bat
}
configure_base_system(){
_config_base_system
}
_install_locale_files(){
remote_copy "templates/locale.sh" "/etc/profile.d/locale.sh"||return 1
remote_exec "chmod +x /etc/profile.d/locale.sh"||return 1
remote_copy "templates/default-locale" "/etc/default/locale"||return 1
remote_copy "templates/environment" "/etc/environment"||return 1
remote_exec "grep -q 'profile.d/locale.sh' /etc/bash.bashrc || echo '[ -f /etc/profile.d/locale.sh ] && . /etc/profile.d/locale.sh' >> /etc/bash.bashrc"||return 1
}
_config_tailscale(){
remote_run "Starting Tailscale" '
        set -e
        systemctl daemon-reload
        systemctl enable --now tailscaled
        systemctl start tailscaled
        for i in {1..3}; do tailscale status &>/dev/null && break; sleep 1; done
        true
    ' "Tailscale started"
if [[ -n $TAILSCALE_AUTH_KEY ]];then
local tmp_ip="" tmp_hostname="" tmp_result=""
tmp_ip=$(mktemp)||{
log_error "mktemp failed for tmp_ip"
return 1
}
tmp_hostname=$(mktemp)||{
rm -f "$tmp_ip"
log_error "mktemp failed for tmp_hostname"
return 1
}
tmp_result=$(mktemp)||{
rm -f "$tmp_ip" "$tmp_hostname"
log_error "mktemp failed for tmp_result"
return 1
}
trap "rm -f '$tmp_ip' '$tmp_hostname' '$tmp_result'" RETURN
(if
remote_exec "tailscale up --authkey='$TAILSCALE_AUTH_KEY' --ssh"
then
echo "success" >"$tmp_result"
remote_exec "tailscale status --json | jq -r '[(.Self.TailscaleIPs[0] // \"pending\"), (.Self.DNSName // \"\" | rtrimstr(\".\"))] | @tsv'"|{
IFS=$'\t' read -r ip hostname
echo "$ip" >"$tmp_ip"
echo "$hostname" >"$tmp_hostname"
}||true
else
echo "failed" >"$tmp_result"
log_error "tailscale up command failed"
fi) > \
/dev/null 2>&1&
show_progress "$!" "Authenticating Tailscale"
local auth_result
auth_result=$(cat "$tmp_result" 2>/dev/null||echo "failed")
if [[ $auth_result == "success" ]];then
declare -g TAILSCALE_IP
TAILSCALE_IP=$(cat "$tmp_ip" 2>/dev/null||echo "pending")
declare -g TAILSCALE_HOSTNAME
TAILSCALE_HOSTNAME=$(cat "$tmp_hostname" 2>/dev/null||printf '\n')
complete_task "$TASK_INDEX" "$TREE_BRANCH Tailscale authenticated. IP: $TAILSCALE_IP"
if [[ $TAILSCALE_WEBUI == "yes" ]];then
remote_run "Configuring Tailscale Serve" \
'tailscale serve --bg --https=443 https://127.0.0.1:8006' \
"Proxmox Web UI available via Tailscale Serve"
fi
if [[ ${FIREWALL_MODE:-standard} == "stealth" ]];then
log_info "Deploying disable-openssh.service (FIREWALL_MODE=$FIREWALL_MODE)"
(log_info "Using pre-downloaded disable-openssh.service, size: $(wc -c <./templates/disable-openssh.service 2>/dev/null||echo 'failed')"
remote_copy "templates/disable-openssh.service" "/etc/systemd/system/disable-openssh.service"||exit 1
remote_exec "chmod 644 /etc/systemd/system/disable-openssh.service"||exit 1
log_info "Copied disable-openssh.service to VM"
remote_exec "systemctl daemon-reload && systemctl enable disable-openssh.service" >/dev/null||exit 1
log_info "Enabled disable-openssh.service") \
&
show_progress "$!" "Configuring OpenSSH disable on boot" "OpenSSH disable configured"
else
log_info "Skipping disable-openssh.service (FIREWALL_MODE=${FIREWALL_MODE:-standard})"
fi
else
declare -g TAILSCALE_IP="auth failed"
declare -g TAILSCALE_HOSTNAME=""
complete_task "$TASK_INDEX" "$TREE_BRANCH ${CLR_YELLOW}Tailscale auth failed - check auth key$CLR_RESET" "warning"
log_warn "Tailscale authentication failed. Auth key may be invalid or expired."
if [[ ${FIREWALL_MODE:-standard} == "stealth" ]];then
add_log "$TREE_VERT   ${CLR_YELLOW}SSH will remain enabled (Tailscale auth failed)$CLR_RESET"
log_warn "Stealth mode requested but Tailscale auth failed - SSH will remain enabled to prevent lockout"
fi
fi
else
declare -g TAILSCALE_IP="not authenticated"
declare -g TAILSCALE_HOSTNAME=""
add_log "$TREE_BRANCH $CLR_YELLOW⚠️$CLR_RESET Tailscale installed but not authenticated"
add_subtask_log "After reboot: tailscale up --ssh"
fi
}
configure_tailscale(){
[[ $INSTALL_TAILSCALE != "yes" ]]&&return 0
_config_tailscale
}
_config_admin_user(){
require_admin_username "create admin user"||return 1
remote_exec 'useradd -m -s /bin/bash -G sudo '"$ADMIN_USERNAME"''||return 1
local encoded_creds
encoded_creds=$(printf '%s:%s' "$ADMIN_USERNAME" "$ADMIN_PASSWORD"|base64|tr -d '\n')
remote_exec "echo '$encoded_creds' | base64 -d | chpasswd"||return 1
remote_exec "mkdir -p /home/$ADMIN_USERNAME/.ssh && chmod 700 /home/$ADMIN_USERNAME/.ssh"||return 1
local escaped_key="${SSH_PUBLIC_KEY//\'/\'\\\'\'}"
remote_exec "echo '$escaped_key' > /home/$ADMIN_USERNAME/.ssh/authorized_keys"||return 1
remote_exec "chmod 600 /home/$ADMIN_USERNAME/.ssh/authorized_keys"||return 1
remote_exec "chown -R $ADMIN_USERNAME:$ADMIN_USERNAME /home/$ADMIN_USERNAME/.ssh"||return 1
remote_exec "echo '$ADMIN_USERNAME ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$ADMIN_USERNAME"||return 1
remote_exec "chmod 440 /etc/sudoers.d/$ADMIN_USERNAME"||return 1
remote_exec "pveum user list 2>/dev/null | grep -q '$ADMIN_USERNAME@pam' || pveum user add '$ADMIN_USERNAME@pam'"
remote_exec "pveum acl modify / -user '$ADMIN_USERNAME@pam' -role Administrator"||{
log_warn "Failed to grant Proxmox Administrator role"
}
remote_exec "pveum user modify root@pam -enable 0"||{
log_warn "Failed to disable root user in Proxmox UI"
}
}
configure_admin_user(){
log_info "Creating admin user: $ADMIN_USERNAME"
if ! run_with_progress "Creating admin user" "Admin user created" _config_admin_user;then
log_error "Failed to create admin user"
return 1
fi
log_info "Admin user $ADMIN_USERNAME created successfully"
return 0
}
_configure_chrony(){
remote_exec "systemctl stop chrony"||true
remote_copy "templates/chrony" "/etc/chrony/chrony.conf"||return 1
remote_exec "systemctl enable --now chrony"||return 1
}
_configure_unattended_upgrades(){
remote_copy "templates/50unattended-upgrades" "/etc/apt/apt.conf.d/50unattended-upgrades"||return 1
remote_copy "templates/20auto-upgrades" "/etc/apt/apt.conf.d/20auto-upgrades"||return 1
remote_exec "systemctl enable --now unattended-upgrades"||return 1
}
_configure_cpu_governor(){
local governor="${CPU_GOVERNOR:-performance}"
remote_copy "templates/cpupower.service" "/etc/systemd/system/cpupower.service"||return 1
remote_exec "chmod 644 /etc/systemd/system/cpupower.service"||return 1
remote_exec "
    systemctl daemon-reload
    systemctl enable --now cpupower.service
    cpupower frequency-set -g \"$governor\" 2>/dev/null || true
  "||return 1
}
_configure_io_scheduler(){
remote_copy "templates/60-io-scheduler.rules" "/etc/udev/rules.d/60-io-scheduler.rules"||return 1
remote_exec "udevadm control --reload-rules && udevadm trigger"||return 1
}
_remove_subscription_notice(){
remote_copy "templates/remove-subscription-nag.sh" "/tmp/remove-subscription-nag.sh"||return 1
remote_exec "chmod +x /tmp/remove-subscription-nag.sh && /tmp/remove-subscription-nag.sh && rm -f /tmp/remove-subscription-nag.sh"||return 1
}
_config_system_services(){
log_info "Configuring chrony"
_configure_chrony||{
log_error "Failed to configure chrony"
return 1
}
log_info "Configuring unattended-upgrades"
_configure_unattended_upgrades||{
log_error "Failed to configure unattended-upgrades"
return 1
}
log_info "Configuring kernel modules"
remote_exec '
    for mod in nf_conntrack tcp_bbr; do
      if ! grep -q "^${mod}$" /etc/modules 2>/dev/null; then
        echo "$mod" >> /etc/modules
      fi
    done
    modprobe tcp_bbr 2>/dev/null || true
  ' >>"$LOG_FILE" 2>&1||{
log_error "Failed to configure kernel modules"
return 1
}
log_info "Configuring system limits"
remote_copy "templates/99-limits.conf" "/etc/security/limits.d/99-proxmox.conf"||{
log_error "Failed to configure system limits"
return 1
}
log_info "Optimizing APT configuration"
remote_exec 'echo "Acquire::Languages \"none\";" > /etc/apt/apt.conf.d/99-disable-translations' >> \
"$LOG_FILE" 2>&1||{
log_error "Failed to optimize APT configuration"
return 1
}
local governor="${CPU_GOVERNOR:-performance}"
log_info "Configuring CPU governor ($governor)"
_configure_cpu_governor||{
log_error "Failed to configure CPU governor"
return 1
}
log_info "Configuring I/O scheduler"
_configure_io_scheduler||{
log_error "Failed to configure I/O scheduler"
return 1
}
if [[ ${PVE_REPO_TYPE:-no-subscription} != "enterprise" ]];then
log_info "Removing Proxmox subscription notice (non-enterprise)"
_remove_subscription_notice||{
log_error "Failed to remove subscription notice"
return 1
}
fi
parallel_mark_configured "services"
}
configure_system_services(){
_config_system_services
}
_generate_port_rules(){
local mode="${1:-standard}"
local ssh="${PORT_SSH:-22}"
case "$mode" in
stealth)cat <<'EOF'
        # Stealth mode: all public ports blocked
        # Access only via Tailscale VPN or VM bridges
EOF
;;
strict)cat <<EOF
        # SSH access (port $ssh)
        tcp dport $ssh ct state new accept
EOF
;;
standard|*)cat <<EOF
        # SSH access (port $ssh)
        tcp dport $ssh ct state new accept

        # Proxmox Web UI (port 8006, after DNAT from 443)
        tcp dport 8006 ct state new accept
EOF
esac
if [[ $SSL_TYPE == "letsencrypt" && $mode != "stealth" ]];then
cat <<'EOF'

        # HTTP for Let's Encrypt ACME challenge
        tcp dport 80 ct state new accept
EOF
fi
}
_generate_bridge_input_rules(){
local mode="${BRIDGE_MODE:-internal}"
case "$mode" in
internal)cat <<'EOF'
        # Allow traffic from vmbr0 (private NAT network)
        iifname "vmbr0" accept
EOF
;;
external)cat <<'EOF'
        # Allow traffic from vmbr1 (external bridge)
        iifname "vmbr1" accept
EOF
;;
both)cat <<'EOF'
        # Allow traffic from vmbr0 (private NAT network)
        iifname "vmbr0" accept

        # Allow traffic from vmbr1 (public IPs)
        iifname "vmbr1" accept
EOF
esac
}
_generate_bridge_forward_rules(){
local mode="${BRIDGE_MODE:-internal}"
case "$mode" in
internal)cat <<'EOF'
        # Allow forwarding for vmbr0 (private NAT network)
        iifname "vmbr0" accept
        oifname "vmbr0" accept
EOF
;;
external)cat <<'EOF'
        # Allow forwarding for vmbr1 (external bridge)
        iifname "vmbr1" accept
        oifname "vmbr1" accept
EOF
;;
both)cat <<'EOF'
        # Allow forwarding for vmbr0 (private NAT network)
        iifname "vmbr0" accept
        oifname "vmbr0" accept

        # Allow forwarding for vmbr1 (public IPs)
        iifname "vmbr1" accept
        oifname "vmbr1" accept
EOF
esac
}
_generate_tailscale_rules(){
if [[ $INSTALL_TAILSCALE == "yes" ]];then
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
_generate_nat_rules(){
local mode="${BRIDGE_MODE:-internal}"
local subnet="${PRIVATE_SUBNET:-10.0.0.0/24}"
case "$mode" in
internal|both)cat <<EOF
        # Masquerade traffic from private subnet to internet
        oifname != "lo" ip saddr $subnet masquerade
EOF
;;
external)echo "        # External mode: no NAT needed (VMs have public IPs)"
esac
}
_generate_prerouting_rules(){
local mode="${1:-standard}"
local webui="${PORT_PROXMOX_UI:-443}"
case "$mode" in
stealth)echo "        # Stealth mode: no public port redirects"
;;
strict)echo "        # Strict mode: no web UI redirect"
;;
standard|*)cat <<EOF
        # Redirect HTTPS (port $webui) to pveproxy (port 8006)
        tcp dport $webui redirect to :8006
EOF
esac
}
_generate_nftables_conf(){
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
_config_nftables(){
log_info "Setting up iptables-nft compatibility layer"
remote_exec '
    update-alternatives --set iptables /usr/sbin/iptables-nft
    update-alternatives --set ip6tables /usr/sbin/ip6tables-nft
  ' >>"$LOG_FILE" 2>&1||log_warn "Could not set iptables-nft alternatives"
local config_file="./templates/nftables.conf.generated"
if ! _generate_nftables_conf >"$config_file";then
log_error "Failed to generate nftables config"
return 1
fi
log_info "Generated nftables config (mode: $FIREWALL_MODE, bridge: $BRIDGE_MODE)"
remote_copy "$config_file" "/etc/nftables.conf"||{
log_error "Failed to deploy nftables config"
rm -f "$config_file"
return 1
}
remote_exec "nft -c -f /etc/nftables.conf"||{
log_error "nftables config syntax validation failed"
rm -f "$config_file"
return 1
}
remote_exec "systemctl enable --now nftables"||{
log_error "Failed to enable nftables"
rm -f "$config_file"
return 1
}
rm -f "$config_file"
}
configure_firewall(){
if [[ $INSTALL_FIREWALL != "yes" ]];then
log_info "Skipping firewall configuration (INSTALL_FIREWALL=$INSTALL_FIREWALL)"
return 0
fi
log_info "Configuring nftables firewall (mode: $FIREWALL_MODE, bridge: $BRIDGE_MODE)"
local mode_display=""
case "$FIREWALL_MODE" in
stealth)mode_display="stealth (Tailscale only)";;
strict)mode_display="strict (SSH only)";;
standard)mode_display="standard (SSH + Web UI)";;
*)mode_display="$FIREWALL_MODE"
esac
if ! run_with_progress "Configuring nftables firewall" "Firewall configured ($mode_display)" _config_nftables;then
log_warn "Firewall setup failed"
fi
return 0
}
_config_fail2ban(){
deploy_template "templates/fail2ban-jail.local" "/etc/fail2ban/jail.local" \
"EMAIL=$EMAIL" "HOSTNAME=$PVE_HOSTNAME"||return 1
remote_copy "templates/fail2ban-proxmox.conf" "/etc/fail2ban/filter.d/proxmox.conf"||{
log_error "Failed to deploy fail2ban filter"
return 1
}
remote_enable_services "fail2ban"
parallel_mark_configured "fail2ban"
}
configure_fail2ban(){
[[ ${INSTALL_FIREWALL:-} != "yes" || ${FIREWALL_MODE:-standard} == "stealth" ]]&&return 0
_config_fail2ban
}
_config_apparmor(){
deploy_template "templates/apparmor-grub.cfg" "/etc/default/grub.d/apparmor.cfg"
log_info "Updating boot configuration and enabling AppArmor"
remote_exec '
    if proxmox-boot-tool status &>/dev/null; then
      proxmox-boot-tool refresh
    else
      update-grub
    fi
    systemctl enable --now apparmor.service
  ' >>"$LOG_FILE" 2>&1||{
log_error "Failed to configure AppArmor"
return 1
}
parallel_mark_configured "apparmor"
}
make_feature_wrapper "apparmor" "INSTALL_APPARMOR"
_config_auditd(){
deploy_template "templates/auditd-rules" "/etc/audit/rules.d/proxmox.rules" \
"ADMIN_USERNAME=$ADMIN_USERNAME"||{
log_error "Failed to deploy auditd rules"
return 1
}
remote_exec '
    mkdir -p /var/log/audit
    # Create directories that audit rules will watch (rules fail if paths dont exist)
    mkdir -p /etc/ssh/sshd_config.d /root/.ssh /etc/network/interfaces.d
    mkdir -p /etc/pve/firewall /var/lib/pve-cluster
    mkdir -p /etc/modprobe.d /etc/cron.d /etc/cron.daily /etc/cron.hourly
    mkdir -p /etc/cron.monthly /etc/cron.weekly /var/spool/cron/crontabs
    mkdir -p /etc/sudoers.d /etc/pam.d /etc/security /etc/init.d
    mkdir -p /etc/systemd/system /etc/fail2ban
    mkdir -p /home/'"$ADMIN_USERNAME"'/.ssh
    chmod 700 /root/.ssh /home/'"$ADMIN_USERNAME"'/.ssh
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
  '||{
log_error "Failed to configure auditd"
return 1
}
parallel_mark_configured "auditd"
}
make_feature_wrapper "auditd" "INSTALL_AUDITD"
_config_aide(){
deploy_systemd_timer "aide-check"||return 1
remote_exec '
    aideinit -y -f
    [[ -f /var/lib/aide/aide.db.new ]] && mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
  '||{
log_error "Failed to initialize AIDE"
return 1
}
parallel_mark_configured "aide"
}
make_feature_wrapper "aide" "INSTALL_AIDE"
_config_chkrootkit(){
deploy_timer_with_logdir "chkrootkit-scan" "/var/log/chkrootkit"||return 1
parallel_mark_configured "chkrootkit"
}
make_feature_wrapper "chkrootkit" "INSTALL_CHKROOTKIT"
_config_lynis(){
deploy_timer_with_logdir "lynis-audit" "/var/log/lynis"||return 1
parallel_mark_configured "lynis"
}
make_feature_wrapper "lynis" "INSTALL_LYNIS"
_config_needrestart(){
deploy_template "templates/needrestart.conf" "/etc/needrestart/conf.d/50-autorestart.conf"||{
log_error "Failed to deploy needrestart config"
return 1
}
parallel_mark_configured "needrestart"
}
make_feature_wrapper "needrestart" "INSTALL_NEEDRESTART"
_config_vnstat(){
local iface="${INTERFACE_NAME:-eth0}"
deploy_template "templates/vnstat.conf" "/etc/vnstat.conf" "INTERFACE_NAME=$iface"||return 1
remote_exec "
    mkdir -p /var/lib/vnstat
    vnstat --add -i '$iface'
    for bridge in vmbr0 vmbr1; do
      ip link show \"\$bridge\" &>/dev/null && vnstat --add -i \"\$bridge\"
    done
    systemctl enable --now vnstat
  "||{
log_error "Failed to configure vnstat"
return 1
}
parallel_mark_configured "vnstat"
}
make_feature_wrapper "vnstat" "INSTALL_VNSTAT"
_config_promtail(){
deploy_template "templates/promtail.yml" "/etc/promtail/promtail.yml" \
"HOSTNAME=$PVE_HOSTNAME"||return 1
deploy_template "templates/promtail.service" "/etc/systemd/system/promtail.service"||return 1
remote_exec 'mkdir -p /var/lib/promtail'||return 1
remote_enable_services "promtail"
parallel_mark_configured "promtail"
}
make_feature_wrapper "promtail" "INSTALL_PROMTAIL"
_config_netdata(){
local bind_to="127.0.0.1"
if [[ $INSTALL_TAILSCALE == "yes" ]];then
bind_to="127.0.0.1 100.*"
fi
deploy_template "templates/netdata.conf" "/etc/netdata/netdata.conf" \
"NETDATA_BIND_TO=$bind_to"||return 1
deploy_template "templates/journald-netdata.conf" \
"/etc/systemd/journald@netdata.conf"||return 1
remote_enable_services "netdata"
}
make_feature_wrapper "netdata" "INSTALL_NETDATA"
_config_postfix_relay(){
local relay_host="$SMTP_RELAY_HOST"
local relay_port="${SMTP_RELAY_PORT:-587}"
local relay_user="$SMTP_RELAY_USER"
local relay_pass="$SMTP_RELAY_PASSWORD"
deploy_template "postfix-main.cf.tmpl" "/etc/postfix/main.cf" \
"SMTP_RELAY_HOST=$relay_host" \
"SMTP_RELAY_PORT=$relay_port" \
"HOSTNAME=$PVE_HOSTNAME" \
"DOMAIN_SUFFIX=$DOMAIN_SUFFIX"||return 1
local tmp_passwd
tmp_passwd=$(mktemp)||return 1
printf '[%s]:%s %s:%s\n' "$relay_host" "$relay_port" "$relay_user" "$relay_pass" >"$tmp_passwd"
remote_copy "$tmp_passwd" "/etc/postfix/sasl_passwd"||{
rm -f "$tmp_passwd"
return 1
}
rm -f "$tmp_passwd"
remote_exec '
    umask 077
    chmod 600 /etc/postfix/sasl_passwd
    chown root:root /etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd
    chmod 600 /etc/postfix/sasl_passwd.db
    chown root:root /etc/postfix/sasl_passwd.db
  '||return 1
remote_run "Restarting Postfix" \
'systemctl restart postfix' \
"Postfix relay configured"
parallel_mark_configured "postfix"
}
_config_postfix_disable(){
remote_exec 'systemctl stop postfix 2>/dev/null; systemctl disable postfix 2>/dev/null'||true
log_info "Postfix disabled"
parallel_mark_configured "postfix disabled"
}
configure_postfix(){
if [[ $INSTALL_POSTFIX == "yes" ]];then
if [[ -n $SMTP_RELAY_HOST && -n $SMTP_RELAY_USER && -n $SMTP_RELAY_PASSWORD ]];then
_config_postfix_relay
else
log_warn "Postfix enabled but SMTP relay not configured, skipping"
fi
elif [[ $INSTALL_POSTFIX == "no" ]];then
_config_postfix_disable
fi
}
_config_ringbuffer(){
remote_copy "templates/network-ringbuffer.sh" "/usr/local/bin/network-ringbuffer.sh"||return 1
remote_exec "chmod +x /usr/local/bin/network-ringbuffer.sh"||return 1
deploy_systemd_service "network-ringbuffer"||return 1
parallel_mark_configured "ringbuffer"
}
make_feature_wrapper "ringbuffer" "INSTALL_RINGBUFFER"
_config_yazi(){
remote_exec 'su - '"$ADMIN_USERNAME"' -c "
    ya pkg add kalidyasin/yazi-flavors:tokyonight-night || echo \"WARNING: Failed to install yazi flavor\" >&2
    ya pkg add yazi-rs/plugins:chmod || echo \"WARNING: Failed to install chmod plugin\" >&2
    ya pkg add yazi-rs/plugins:smart-enter || echo \"WARNING: Failed to install smart-enter plugin\" >&2
    ya pkg add yazi-rs/plugins:smart-filter || echo \"WARNING: Failed to install smart-filter plugin\" >&2
    ya pkg add yazi-rs/plugins:full-border || echo \"WARNING: Failed to install full-border plugin\" >&2
  "'||{
log_warn "Failed to install some yazi plugins (yazi will still work)"
}
deploy_user_configs \
"templates/yazi.toml:.config/yazi/yazi.toml" \
"templates/yazi-theme.toml:.config/yazi/theme.toml" \
"templates/yazi-init.lua:.config/yazi/init.lua" \
"templates/yazi-keymap.toml:.config/yazi/keymap.toml"||{
log_error "Failed to deploy yazi configs"
return 1
}
}
make_feature_wrapper "yazi" "INSTALL_YAZI"
_config_nvim(){
remote_exec '
    update-alternatives --install /usr/bin/vi vi /usr/bin/nvim 60
    update-alternatives --install /usr/bin/vim vim /usr/bin/nvim 60
    update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 60
    update-alternatives --set vi /usr/bin/nvim
    update-alternatives --set vim /usr/bin/nvim
    update-alternatives --set editor /usr/bin/nvim
  '||{
log_error "Failed to configure nvim alternatives"
return 1
}
parallel_mark_configured "nvim"
}
make_feature_wrapper "nvim" "INSTALL_NVIM"
_configure_fastfetch(){
remote_copy "templates/fastfetch.sh" "/etc/profile.d/fastfetch.sh"||return 1
remote_exec "chmod +x /etc/profile.d/fastfetch.sh"||return 1
}
_configure_bat(){
remote_exec "ln -sf /usr/bin/batcat /usr/local/bin/bat"||return 1
deploy_user_config "templates/bat-config" ".config/bat/config"||return 1
}
_configure_zsh_files(){
require_admin_username "configure ZSH files"||return 1
deploy_user_config "templates/zshrc" ".zshrc" "LOCALE=$LOCALE"||return 1
remote_exec "chsh -s /bin/zsh $ADMIN_USERNAME"||return 1
}
_config_shell(){
if [[ $SHELL_TYPE == "zsh" ]];then
require_admin_username "configure shell"||return 1
log_info "Installing Oh-My-Zsh for $ADMIN_USERNAME"
remote_exec '
      set -e
      export RUNZSH=no
      export CHSH=no
      export HOME=/home/'"$ADMIN_USERNAME"'
      su - '"$ADMIN_USERNAME"' -c "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended"
    ' >>"$LOG_FILE" 2>&1||{
log_error "Failed to install Oh-My-Zsh"
return 1
}
log_info "Installing ZSH plugins"
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
    ' >>"$LOG_FILE" 2>&1||{
log_error "Failed to install ZSH plugins"
return 1
}
_configure_zsh_files||{
log_error "Failed to configure ZSH files"
return 1
}
parallel_mark_configured "zsh"
else
parallel_mark_configured "bash"
fi
}
configure_shell(){
_config_shell
}
_config_ssl(){
log_debug "_config_ssl: SSL_TYPE=$SSL_TYPE"
local cert_domain="${FQDN:-$PVE_HOSTNAME.$DOMAIN_SUFFIX}"
log_debug "_config_ssl: domain=$cert_domain, email=$EMAIL"
deploy_template "templates/letsencrypt-firstboot.sh" "/tmp/letsencrypt-firstboot.sh" \
"CERT_DOMAIN=$cert_domain" "CERT_EMAIL=$EMAIL"||return 1
remote_copy "templates/letsencrypt-deploy-hook.sh" "/tmp/letsencrypt-deploy-hook.sh"||return 1
remote_copy "templates/letsencrypt-firstboot.service" "/tmp/letsencrypt-firstboot.service"||return 1
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
  ' >>"$LOG_FILE" 2>&1||{
log_error "Failed to configure Let's Encrypt"
return 1
}
declare -g LETSENCRYPT_DOMAIN="$cert_domain"
declare -g LETSENCRYPT_FIRSTBOOT=true
parallel_mark_configured "ssl"
}
make_condition_wrapper "ssl" "SSL_TYPE" "letsencrypt"
_config_api_token(){
log_info "Creating Proxmox API token for $ADMIN_USERNAME: $API_TOKEN_NAME"
local existing
existing=$(remote_exec "pveum user token list '$ADMIN_USERNAME@pam' 2>/dev/null | grep -q '$API_TOKEN_NAME' && echo 'exists' || echo ''")
if [[ $existing == "exists" ]];then
log_warn "Token $API_TOKEN_NAME exists, removing first"
remote_exec "pveum user token remove '$ADMIN_USERNAME@pam' '$API_TOKEN_NAME'"||{
log_error "Failed to remove existing token"
return 1
}
fi
local output
output=$(remote_exec "pveum user token add '$ADMIN_USERNAME@pam' '$API_TOKEN_NAME' --privsep 0 --expire 0 --output-format json 2>&1")
if [[ -z $output ]];then
log_error "Failed to create API token - empty output"
return 1
fi
local token_value
token_value=$(printf '%s\n' "$output"|jq -R 'try (fromjson | .value) // empty' 2>/dev/null|grep -v '^$'|head -1)
if [[ -z $token_value ]];then
log_error "Failed to extract token value from pveum output"
log_debug "pveum output: $output"
return 1
fi
declare -g API_TOKEN_VALUE="$token_value"
declare -g API_TOKEN_ID="$ADMIN_USERNAME@pam!$API_TOKEN_NAME"
(umask 0077
cat >"$_TEMP_API_TOKEN_FILE" <<EOF
API_TOKEN_VALUE=$token_value
API_TOKEN_ID=$API_TOKEN_ID
API_TOKEN_NAME=$API_TOKEN_NAME
EOF
)
register_temp_file "$_TEMP_API_TOKEN_FILE"
log_info "API token created successfully: $API_TOKEN_ID"
parallel_mark_configured "api-token"
return 0
}
make_feature_wrapper "api_token" "INSTALL_API_TOKEN"
_config_zfs_arc(){
log_info "Configuring ZFS ARC memory allocation (mode: $ZFS_ARC_MODE)"
local total_ram_mb
total_ram_mb=$(free -m|awk 'NR==2 {print $2}')
if [[ ! $total_ram_mb =~ ^[0-9]+$ ]]||[[ $total_ram_mb -eq 0 ]];then
log_error "Failed to detect RAM size (got: '$total_ram_mb')"
return 1
fi
local arc_max_mb
case "$ZFS_ARC_MODE" in
vm-focused)arc_max_mb=4096
;;
balanced)if
[[ $total_ram_mb -lt 16384 ]]
then
arc_max_mb="$((total_ram_mb*25/100))"
elif [[ $total_ram_mb -lt 65536 ]];then
arc_max_mb="$((total_ram_mb*40/100))"
else
arc_max_mb="$((total_ram_mb/2))"
fi
;;
storage-focused)arc_max_mb="$((total_ram_mb/2))"
;;
*)log_error "Invalid ZFS_ARC_MODE: $ZFS_ARC_MODE"
return 1
esac
local arc_max_bytes="$((arc_max_mb*1024*1024))"
log_info "ZFS ARC: ${arc_max_mb}MB (Total RAM: ${total_ram_mb}MB, Mode: $ZFS_ARC_MODE)"
remote_run "Configuring ZFS ARC memory" "
    echo 'options zfs zfs_arc_max=$arc_max_bytes' >/etc/modprobe.d/zfs.conf
    if [[ -f /sys/module/zfs/parameters/zfs_arc_max ]]; then
      echo '$arc_max_bytes' >/sys/module/zfs/parameters/zfs_arc_max 2>/dev/null || true
    fi
  "
log_info "ZFS ARC memory limit configured: ${arc_max_mb}MB"
}
_config_zfs_cachefile(){
log_info "Configuring ZFS cachefile import fixes"
remote_run "Creating systemd drop-in for zfs-import-cache.service" "
    mkdir -p /etc/systemd/system/zfs-import-cache.service.d
  "||return 1
deploy_template "templates/zfs-import-cache.service.d-override.conf" \
"/etc/systemd/system/zfs-import-cache.service.d/override.conf"||return 1
deploy_template "templates/zfs-cachefile-initramfs-hook" \
"/etc/initramfs-tools/hooks/zfs-cachefile"||return 1
remote_exec "chmod +x /etc/initramfs-tools/hooks/zfs-cachefile"||{
log_error "Failed to make initramfs hook executable"
return 1
}
remote_run "Regenerating ZFS cachefile" '
    rm -f /etc/zfs/zpool.cache
    for pool in $(zpool list -H -o name 2>/dev/null); do
      zpool set cachefile=/etc/zfs/zpool.cache "$pool"
    done
  ' "ZFS cachefile regenerated"
log_info "ZFS cachefile import fixes configured"
}
_config_zfs_scrub(){
log_info "Configuring ZFS scrub schedule"
remote_copy "templates/zfs-scrub.service" "/etc/systemd/system/zfs-scrub@.service"||{
log_error "Failed to deploy ZFS scrub service"
return 1
}
remote_exec "chmod 644 /etc/systemd/system/zfs-scrub@.service"||return 1
remote_copy "templates/zfs-scrub.timer" "/etc/systemd/system/zfs-scrub@.timer"||{
log_error "Failed to deploy ZFS scrub timer"
return 1
}
remote_exec "chmod 644 /etc/systemd/system/zfs-scrub@.timer"||return 1
local data_pool="tank"
if [[ $USE_EXISTING_POOL == "yes" && -n $EXISTING_POOL_NAME ]];then
data_pool="$EXISTING_POOL_NAME"
fi
log_info "Enabling scrub timers for pools: rpool (if exists), $data_pool"
remote_run "Enabling ZFS scrub timers" '
    systemctl daemon-reload
    for pool in $(zpool list -H -o name 2>/dev/null); do
      systemctl enable --now zfs-scrub@$pool.timer 2>/dev/null || true
    done
  '
log_info "ZFS scrub schedule configured (monthly, 1st Sunday at 2:00 AM)"
}
configure_zfs_arc(){
_config_zfs_arc
parallel_mark_configured "ZFS ARC $ZFS_ARC_MODE"
}
configure_zfs_cachefile(){
_config_zfs_cachefile
}
configure_zfs_scrub(){
_config_zfs_scrub
}
_config_import_existing_pool(){
local pool_name="$EXISTING_POOL_NAME"
log_info "Importing existing ZFS pool '$pool_name'"
if ! remote_run "Importing ZFS pool '$pool_name'" \
"zpool import -f '$pool_name' 2>/dev/null || zpool import -f -d /dev '$pool_name'" \
"ZFS pool '$pool_name' imported";then
log_error "Failed to import ZFS pool '$pool_name'"
return 1
fi
if ! remote_run "Configuring Proxmox storage for '$pool_name'" "
    if zfs list '$pool_name/vm-disks' >/dev/null 2>&1; then
      ds='$pool_name/vm-disks'
    else
      ds=\$(zfs list -H -o name -r '$pool_name' 2>/dev/null | grep -v '^$pool_name\$' | head -1)
      [[ -z \$ds ]] && { zfs create '$pool_name/vm-disks'; ds='$pool_name/vm-disks'; }
    fi
    pvesm status '$pool_name' >/dev/null 2>&1 || pvesm add zfspool '$pool_name' --pool \"\$ds\" --content images,rootdir
    pvesm set local --content iso,vztmpl,backup,snippets
  " "Proxmox storage configured for '$pool_name'";then
log_error "Failed to configure Proxmox storage for '$pool_name'"
return 1
fi
log_info "Existing ZFS pool '$pool_name' imported and configured"
return 0
}
_config_create_new_pool(){
local pool_name="$DEFAULT_ZFS_POOL_NAME"
log_info "Creating separate ZFS pool '$pool_name' from pool disks"
log_info "ZFS_POOL_DISKS=(${ZFS_POOL_DISKS[*]}), count=${#ZFS_POOL_DISKS[@]}"
log_info "ZFS_RAID=$ZFS_RAID, BOOT_DISK=$BOOT_DISK"
if [[ ${#ZFS_POOL_DISKS[@]} -eq 0 ]];then
log_error "ZFS_POOL_DISKS is empty - no disks to create pool from"
return 1
fi
if [[ -z $ZFS_RAID ]];then
log_error "ZFS_RAID is empty - RAID level not specified"
return 1
fi
if ! load_virtio_mapping;then
log_error "Failed to load virtio mapping"
return 1
fi
local vdevs_str
vdevs_str=$(map_disks_to_virtio "space_separated" "${ZFS_POOL_DISKS[@]}")
if [[ -z $vdevs_str ]];then
log_error "Failed to map pool disks to virtio devices"
return 1
fi
read -ra vdevs <<<"$vdevs_str"
log_info "Pool disks: ${vdevs[*]} (RAID: $ZFS_RAID)"
local pool_cmd
pool_cmd=$(build_zpool_command "$pool_name" "$ZFS_RAID" "${vdevs[@]}")
if [[ -z $pool_cmd ]];then
log_error "Failed to build zpool create command"
return 1
fi
log_info "ZFS pool command: $pool_cmd"
if [[ $pool_cmd != zpool\ create* ]];then
log_error "Invalid pool command format: $pool_cmd"
return 1
fi
if ! remote_run "Creating ZFS pool '$pool_name'" "
    set -e
    $pool_cmd
    zfs set compression=lz4 '$pool_name'
    zfs set atime=off '$pool_name'
    zfs set xattr=sa '$pool_name'
    zfs set dnodesize=auto '$pool_name'
    zfs create '$pool_name'/vm-disks
    pvesm add zfspool '$pool_name' --pool '$pool_name'/vm-disks --content images,rootdir
    pvesm set local --content iso,vztmpl,backup,snippets
  " "ZFS pool '$pool_name' created";then
log_error "Failed to create ZFS pool '$pool_name'"
return 1
fi
log_info "ZFS pool '$pool_name' created successfully"
return 0
}
_config_ensure_rpool_storage(){
log_info "Ensuring rpool storage is configured for Proxmox"
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
  ' "rpool storage configured";then
log_warn "rpool storage configuration had issues"
fi
return 0
}
_config_zfs_pool(){
if [[ -z $BOOT_DISK ]];then
log_info "BOOT_DISK not set, all-ZFS mode - ensuring rpool storage"
_config_ensure_rpool_storage
return 0
fi
if [[ ${#ZFS_POOL_DISKS[@]} -eq 0 && $USE_EXISTING_POOL != "yes" ]];then
log_info "No ZFS pool disks - using expanded local storage only"
return 0
fi
if [[ $USE_EXISTING_POOL == "yes" ]];then
_config_import_existing_pool
else
_config_create_new_pool
fi
}
configure_zfs_pool(){
_config_zfs_pool
}
_config_expand_lvm_root(){
log_info "Expanding LVM root to use all disk space"
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
  ' "LVM root filesystem expanded";then
log_warn "LVM expansion had issues, continuing"
fi
return 0
}
configure_lvm_storage(){
[[ -z $BOOT_DISK ]]&&return 0
_config_expand_lvm_root
parallel_mark_configured "LVM root expanded"
}
cleanup_installation_logs(){
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
configure_efi_fallback_boot(){
if ! remote_exec 'test -d /sys/firmware/efi' 2>/dev/null;then
log_info "Legacy BIOS mode - skipping EFI fallback configuration"
return 0
fi
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
_deploy_ssh_config(){
deploy_template "templates/sshd_config" "/etc/ssh/sshd_config" \
"ADMIN_USERNAME=$ADMIN_USERNAME"||return 1
}
deploy_ssh_hardening_config(){
if ! run_with_progress "Deploying SSH hardening config" "SSH config deployed" _deploy_ssh_config;then
log_error "SSH config deploy failed"
return 1
fi
}
restart_ssh_service(){
log_info "Restarting SSH to apply hardening"
if ! run_with_progress "Applying SSH hardening" "SSH hardening active" \
remote_exec "systemctl restart sshd";then
log_warn "SSH restart failed - config will apply on reboot"
fi
}
validate_installation(){
log_info "Generating validation script from template..."
local staged
staged=$(mktemp)||{
log_error "Failed to create temp file for validation.sh"
return 1
}
register_temp_file "$staged"
cp "./templates/validation.sh" "$staged"||{
log_error "Failed to stage validation.sh"
rm -f "$staged"
return 1
}
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
"ADMIN_USERNAME=$ADMIN_USERNAME" \
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
start_task "$TREE_BRANCH Validating installation"
local task_idx="$TASK_INDEX"
local validation_output
validation_output=$(printf '%s\n' "$validation_script"|remote_exec 'bash -s' 2>&1)||true
printf '%s\n' "$validation_output" >>"$LOG_FILE"
local errors=0 warnings=0
while IFS= read -r line;do
case "$line" in
FAIL:*)add_subtask_log "$line" "$CLR_RED"
((errors++))
;;
WARN:*)add_subtask_log "$line" "$CLR_YELLOW"
((warnings++))
esac
done <<<"$validation_output"
if ((errors>0));then
complete_task "$task_idx" "$TREE_BRANCH Validation: $CLR_RED$errors error(s)$CLR_RESET, $CLR_YELLOW$warnings warning(s)$CLR_RESET" "error"
log_error "Installation validation failed with $errors error(s)"
elif ((warnings>0));then
complete_task "$task_idx" "$TREE_BRANCH Validation passed with $CLR_YELLOW$warnings warning(s)$CLR_RESET" "warning"
else
complete_task "$task_idx" "$TREE_BRANCH Validation passed"
fi
}
finalize_vm(){
(if
kill -0 "$QEMU_PID" 2>/dev/null
then
kill -TERM "$QEMU_PID" 2>/dev/null||true
fi) \
&
show_progress "$!" "Powering off the VM"
(timeout="${VM_SHUTDOWN_TIMEOUT:-120}"
wait_interval="${PROCESS_KILL_WAIT:-1}"
elapsed=0
while ((elapsed<timeout));do
if ! kill -0 "$QEMU_PID" 2>/dev/null;then
exit 0
fi
sleep "$wait_interval"
((elapsed+=wait_interval))
done
exit 1) \
&
local wait_pid="$!"
show_progress "$wait_pid" "Waiting for QEMU process to exit" "QEMU process exited"
local exit_code="$?"
if [[ $exit_code -ne 0 ]];then
log_warn "QEMU process did not exit cleanly within 120 seconds"
kill -9 "$QEMU_PID" 2>/dev/null||true
fi
}
configure_proxmox_via_ssh(){
log_info "Starting Proxmox configuration via SSH"
_phase_base_configuration||{
log_error "Base configuration failed"
return 1
}
_phase_storage_configuration||{
log_error "Storage configuration failed"
return 1
}
_phase_security_configuration||{
log_error "Security configuration failed"
return 1
}
_phase_monitoring_tools||{
log_warn "Monitoring tools configuration had issues"
}
_phase_ssl_api||{
log_warn "SSL/API configuration had issues"
}
_phase_finalization||{
log_error "Finalization failed"
return 1
}
}
_phase_base_configuration(){
make_templates||{
log_error "make_templates failed"
return 1
}
configure_admin_user||{
log_error "configure_admin_user failed"
return 1
}
configure_base_system||{
log_error "configure_base_system failed"
return 1
}
run_parallel_group "Configuring shell & services" "Shell & services configured" \
configure_shell \
configure_system_services
}
_phase_storage_configuration(){
if [[ -n $BOOT_DISK ]];then
run_parallel_group "Configuring LVM & ZFS memory" "LVM & ZFS memory configured" \
configure_lvm_storage \
configure_zfs_arc
else
(configure_zfs_arc)||log_warn "configure_zfs_arc failed"
fi
configure_zfs_pool||{
log_error "configure_zfs_pool failed"
return 1
}
(configure_zfs_cachefile)||log_warn "configure_zfs_cachefile failed"
(configure_zfs_scrub)||log_warn "configure_zfs_scrub failed"
(remote_run "Updating initramfs" "update-initramfs -u -k all")||log_warn "update-initramfs failed"
}
_phase_security_configuration(){
batch_install_packages
configure_tailscale
configure_firewall
if ! run_parallel_group "Configuring security" "Security features configured" \
configure_apparmor \
configure_fail2ban \
configure_auditd \
configure_aide \
configure_chkrootkit \
configure_lynis \
configure_needrestart;then
log_error "Security configuration failed - aborting installation"
print_error "Security hardening failed. Check $LOG_FILE for details."
return 1
fi
}
_phase_monitoring_tools(){
local netdata_pid yazi_pid
start_async_feature "netdata" "INSTALL_NETDATA"
netdata_pid="$REPLY"
start_async_feature "yazi" "INSTALL_YAZI"
yazi_pid="$REPLY"
run_parallel_group "Configuring tools" "Tools configured" \
configure_promtail \
configure_vnstat \
configure_ringbuffer \
configure_nvim \
configure_postfix
wait_async_feature "netdata" "$netdata_pid"
wait_async_feature "yazi" "$yazi_pid"
}
_phase_ssl_api(){
if ! run_parallel_group "Configuring SSL & API" "SSL & API configured" \
configure_ssl \
configure_api_token;then
log_warn "SSL/API configuration had failures - check $LOG_FILE for details"
fi
}
_phase_finalization(){
deploy_ssh_hardening_config||{
log_error "deploy_ssh_hardening_config failed"
return 1
}
validate_installation||{ log_warn "validate_installation reported issues";}
(configure_efi_fallback_boot)||log_warn "configure_efi_fallback_boot failed"
(cleanup_installation_logs)||log_warn "cleanup_installation_logs failed"
restart_ssh_service||{ log_warn "restart_ssh_service failed";}
finalize_vm||{ log_warn "finalize_vm did not complete cleanly";}
}
_render_completion_screen(){
local output=""
local banner_output
banner_output=$(show_banner)
output+="$banner_output\n\n"
output+="$(format_wizard_header "Installation Complete")\n\n"
output+="  $CLR_YELLOW⚠ SAVE THESE CREDENTIALS$CLR_RESET\n\n"
_cred_field(){
local label="$1" value="$2" note="${3:-}"
if [[ -n $label ]];then
output+="  $CLR_GRAY$label$CLR_RESET$value"
else
output+="                   $value"
fi
[[ -n $note ]]&&output+=" $CLR_GRAY$note$CLR_RESET"
output+="\n"
}
_cred_field "Hostname         " "$CLR_CYAN$PVE_HOSTNAME.$DOMAIN_SUFFIX$CLR_RESET"
output+="\n"
_cred_field "Admin User       " "$CLR_CYAN$ADMIN_USERNAME$CLR_RESET"
_cred_field "Admin Password   " "$CLR_ORANGE$ADMIN_PASSWORD$CLR_RESET" "(SSH + Proxmox UI)"
output+="\n"
_cred_field "Root Password    " "$CLR_ORANGE$NEW_ROOT_PASSWORD$CLR_RESET" "(console/KVM only)"
output+="\n"
local has_tailscale=""
[[ -n $TAILSCALE_IP && $TAILSCALE_IP != "pending" && $TAILSCALE_IP != "not authenticated" ]]&&has_tailscale="yes"
case "${FIREWALL_MODE:-standard}" in
stealth)if
[[ $has_tailscale == "yes" ]]
then
_cred_field "SSH              " "${CLR_CYAN}ssh $ADMIN_USERNAME@$TAILSCALE_IP$CLR_RESET" "(Tailscale)"
_cred_field "Web UI           " "${CLR_CYAN}https://$TAILSCALE_IP$CLR_RESET" "(Tailscale)"
else
_cred_field "SSH              " "${CLR_YELLOW}blocked$CLR_RESET" "(stealth mode)"
_cred_field "Web UI           " "${CLR_YELLOW}blocked$CLR_RESET" "(stealth mode)"
fi
;;
strict)_cred_field "SSH              " "${CLR_CYAN}ssh $ADMIN_USERNAME@$MAIN_IPV4$CLR_RESET"
if [[ $has_tailscale == "yes" ]];then
_cred_field "" "${CLR_CYAN}ssh $ADMIN_USERNAME@$TAILSCALE_IP$CLR_RESET" "(Tailscale)"
_cred_field "Web UI           " "${CLR_CYAN}https://$TAILSCALE_IP$CLR_RESET" "(Tailscale)"
else
_cred_field "Web UI           " "${CLR_YELLOW}blocked$CLR_RESET" "(strict mode)"
fi
;;
*)_cred_field "SSH              " "${CLR_CYAN}ssh $ADMIN_USERNAME@$MAIN_IPV4$CLR_RESET"
[[ $has_tailscale == "yes" ]]&&_cred_field "" "${CLR_CYAN}ssh $ADMIN_USERNAME@$TAILSCALE_IP$CLR_RESET" "(Tailscale)"
_cred_field "Web UI           " "${CLR_CYAN}https://$MAIN_IPV4$CLR_RESET"
[[ $has_tailscale == "yes" ]]&&_cred_field "" "${CLR_CYAN}https://$TAILSCALE_IP$CLR_RESET" "(Tailscale)"
esac
if [[ -f $_TEMP_API_TOKEN_FILE ]];then
if grep -qvE '^API_TOKEN_(VALUE|ID|NAME)=' "$_TEMP_API_TOKEN_FILE";then
log_error "API token file contains unexpected content"
else
source "$_TEMP_API_TOKEN_FILE"
fi
if [[ -n $API_TOKEN_VALUE ]];then
output+="\n"
_cred_field "API Token ID     " "$CLR_CYAN$API_TOKEN_ID$CLR_RESET"
_cred_field "API Secret       " "$CLR_ORANGE$API_TOKEN_VALUE$CLR_RESET"
fi
fi
output+="\n"
local footer_text="$CLR_GRAY[${CLR_ORANGE}Enter$CLR_GRAY] reboot  [${CLR_ORANGE}Q$CLR_GRAY] quit without reboot$CLR_RESET"
output+="$(_wiz_center "$footer_text")"
_wiz_clear
printf '%b' "$output"
}
_completion_screen_input(){
while true;do
_render_completion_screen
local key
IFS= read -rsn1 key
case "$key" in
q|Q)printf '\n'
print_info "Exiting without reboot."
printf '\n'
print_info "You can reboot manually when ready with: ${CLR_CYAN}reboot$CLR_RESET"
exit 0
;;
"")printf '\n'
print_info "Rebooting the system..."
if ! reboot;then
log_error "Failed to reboot - system may require manual restart"
print_error "Failed to reboot the system"
exit 1
fi
esac
done
}
reboot_to_main_os(){
finish_live_installation
_completion_screen_input
}
log_info "==================== Qoxi Automated Installer v$VERSION ===================="
log_debug "QEMU_RAM_OVERRIDE=$QEMU_RAM_OVERRIDE QEMU_CORES_OVERRIDE=$QEMU_CORES_OVERRIDE"
log_debug "PVE_REPO_TYPE=${PVE_REPO_TYPE:-no-subscription} SSL_TYPE=${SSL_TYPE:-self-signed}"
metrics_start
log_info "Step: collect_system_info"
show_banner_animated_start 0.1
SYSTEM_INFO_CACHE=$(mktemp)||{
log_error "Failed to create temp file"
exit 1
}
register_temp_file "$SYSTEM_INFO_CACHE"
{
collect_system_info
log_info "Step: prefetch_proxmox_iso_info"
prefetch_proxmox_iso_info
declare -p|grep -E "^declare -[^ ]* (PREFLIGHT_|DRIVE_|INTERFACE_|CURRENT_INTERFACE|PREDICTABLE_NAME|DEFAULT_INTERFACE|AVAILABLE_|MAC_ADDRESS|MAIN_IPV|IPV6_|FIRST_IPV6_|_ISO_|_CHECKSUM_|WIZ_TIMEZONES|WIZ_COUNTRIES|TZ_TO_COUNTRY|DETECTED_POOLS)" >"$SYSTEM_INFO_CACHE.tmp"&&mv "$SYSTEM_INFO_CACHE.tmp" "$SYSTEM_INFO_CACHE"
} >/dev/null 2>&1&
wait "$!"
cmd_cache_clear
_missing_cmds=()
for _cmd in gum jq aria2c curl;do
command -v "$_cmd" &>/dev/null||_missing_cmds+=("$_cmd")
done
if [[ ${#_missing_cmds[@]} -gt 0 ]];then
log_error "Required packages not installed: ${_missing_cmds[*]}"
print_error "Required packages not installed: ${_missing_cmds[*]}"
exit 1
fi
unset _missing_cmds _cmd
show_banner_animated_stop
if [[ -s $SYSTEM_INFO_CACHE ]];then
if grep -qvE '^declare -' "$SYSTEM_INFO_CACHE";then
log_error "SYSTEM_INFO_CACHE contains invalid content, skipping import"
else
source "$SYSTEM_INFO_CACHE"
fi
rm -f "$SYSTEM_INFO_CACHE"
fi
log_info "Step: show_system_status"
show_system_status
log_metric "system_info"
log_info "Step: show_gum_config_editor"
show_gum_config_editor
log_metric "config_wizard"
start_live_installation
log_info "Step: prepare_packages"
prepare_packages
log_metric "packages"
log_info "Step: prepare_iso_and_toml (parallel)"
if ! run_parallel_group "Preparing ISO & TOML" "ISO & TOML ready" \
_parallel_download_iso \
_parallel_make_toml;then
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
boot_proxmox_with_port_forwarding||{
log_error "Failed to boot Proxmox with port forwarding"
exit 1
}
log_metric "qemu_boot"
log_info "Step: configure_proxmox_via_ssh"
configure_proxmox_via_ssh||{
log_error "configure_proxmox_via_ssh failed"
exit 1
}
log_metric "system_config"
metrics_finish
INSTALL_COMPLETED=true
log_info "Step: reboot_to_main_os"
reboot_to_main_os
