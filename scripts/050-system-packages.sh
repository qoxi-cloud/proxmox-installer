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
  # Need to run it with 'y' to accept license
  if cmd_exists zpool; then
    log_info "Found zpool wrapper, triggering ZFS compilation..."
    echo "y" | zpool version &>/dev/null || true
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
      echo "y" | "$script" >/dev/null 2>&1 || true
      if _zfs_functional; then
        log_info "ZFS installed successfully via $script"
        return 0
      fi
    fi
  done

  # Fallback: try apt on Debian-based systems
  if [[ -f /etc/debian_version ]]; then
    log_info "Trying apt install zfsutils-linux..."
    apt-get install -qq -y zfsutils-linux >/dev/null 2>&1 || true
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
    DEBIAN_FRONTEND=noninteractive apt-get install -qq -y "${packages_to_install[@]}" >/dev/null 2>&1
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
