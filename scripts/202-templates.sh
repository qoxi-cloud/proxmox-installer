# shellcheck shell=bash
# =============================================================================
# Template preparation and download
# =============================================================================

# Downloads all templates in parallel using aria2c.
# Falls back to sequential wget if aria2c unavailable.
# Parameters:
#   $@ - List of "local_path:remote_name" pairs
# Returns: 0 on success, 1 on failure
_download_templates_parallel() {
  local -a templates=("$@")
  local input_file
  input_file=$(mktemp)

  # Build aria2c input file
  for entry in "${templates[@]}"; do
    local local_path="${entry%%:*}"
    local remote_name="${entry#*:}"
    local url="${GITHUB_BASE_URL}/templates/${remote_name}.tmpl"
    echo "$url"
    echo "  out=$local_path"
  done >"$input_file"

  log "Downloading ${#templates[@]} templates in parallel"

  # Use aria2c for parallel download if available
  if command -v aria2c &>/dev/null; then
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
      return 0
    fi
    log "WARNING: aria2c failed, falling back to sequential download"
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

# Downloads and prepares all template files for Proxmox configuration.
# Selects appropriate templates based on bridge mode and repository type.
# Side effects: Creates templates directory, downloads and modifies templates
make_templates() {
  log "Starting template preparation"
  mkdir -p ./templates
  local interfaces_template="interfaces.${BRIDGE_MODE:-internal}"
  log "Using interfaces template: $interfaces_template"

  # Select Proxmox repository template based on PVE_REPO_TYPE
  local proxmox_sources_template="proxmox.sources"
  case "${PVE_REPO_TYPE:-no-subscription}" in
    enterprise) proxmox_sources_template="proxmox-enterprise.sources" ;;
    test) proxmox_sources_template="proxmox-test.sources" ;;
  esac
  log "Using repository template: $proxmox_sources_template"

  # Build list of templates: "local_path:remote_name"
  local -a template_list=(
    "./templates/99-proxmox.conf:99-proxmox.conf"
    "./templates/hosts:hosts"
    "./templates/debian.sources:debian.sources"
    "./templates/proxmox.sources:${proxmox_sources_template}"
    "./templates/sshd_config:sshd_config"
    "./templates/zshrc:zshrc"
    "./templates/p10k.zsh:p10k.zsh"
    "./templates/chrony:chrony"
    "./templates/50unattended-upgrades:50unattended-upgrades"
    "./templates/20auto-upgrades:20auto-upgrades"
    "./templates/interfaces:${interfaces_template}"
    "./templates/resolv.conf:resolv.conf"
    "./templates/configure-zfs-arc.sh:configure-zfs-arc.sh"
    "./templates/locale.sh:locale.sh"
    "./templates/default-locale:default-locale"
    "./templates/environment:environment"
    "./templates/cpufrequtils:cpufrequtils"
    "./templates/remove-subscription-nag.sh:remove-subscription-nag.sh"
    # Let's Encrypt
    "./templates/letsencrypt-deploy-hook.sh:letsencrypt-deploy-hook.sh"
    "./templates/letsencrypt-firstboot.sh:letsencrypt-firstboot.sh"
    "./templates/letsencrypt-firstboot.service:letsencrypt-firstboot.service"
    # Shell startup and tools
    "./templates/fastfetch.sh:fastfetch.sh"
    "./templates/bat-config:bat-config"
    # Security
    "./templates/fail2ban-jail.local:fail2ban-jail.local"
    "./templates/fail2ban-proxmox.conf:fail2ban-proxmox.conf"
    "./templates/auditd-rules:auditd-rules"
    "./templates/apparmor-grub.cfg:apparmor-grub.cfg"
    # Tailscale
    "./templates/disable-openssh.service:disable-openssh.service"
    # Firewall
    "./templates/nftables.conf:nftables.conf"
    # Optional tools
    "./templates/yazi-theme.toml:yazi-theme.toml"
    # Prometheus
    "./templates/prometheus-node-exporter:prometheus-node-exporter"
    "./templates/proxmox-metrics.sh:proxmox-metrics.sh"
    "./templates/proxmox-metrics.cron:proxmox-metrics.cron"
  )

  # Download all templates in parallel
  (
    _download_templates_parallel "${template_list[@]}" || exit 1
  ) >/dev/null 2>&1 &
  if ! show_progress $! "Downloading template files"; then
    log "ERROR: Failed to download template files"
    exit 1
  fi

  # Modify template files in background with progress
  (
    apply_common_template_vars "./templates/hosts"
    apply_common_template_vars "./templates/interfaces"
    postprocess_interfaces_ipv6 "./templates/interfaces"
    apply_common_template_vars "./templates/resolv.conf"
    apply_template_vars "./templates/cpufrequtils" "CPU_GOVERNOR=${CPU_GOVERNOR:-performance}"
    # Locale templates - substitute {{LOCALE}} with actual locale value
    apply_common_template_vars "./templates/locale.sh"
    apply_common_template_vars "./templates/default-locale"
    apply_common_template_vars "./templates/environment"
  ) &
  show_progress $! "Modifying template files"
}
