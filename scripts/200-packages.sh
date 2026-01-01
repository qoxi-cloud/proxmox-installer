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
  local bg_pid=$!
  if [[ -z $bg_pid || ! $bg_pid =~ ^[0-9]+$ ]]; then
    log_error "Failed to start background job for GPG key download"
    print_error "Failed to start download process"
    exit 1
  fi
  show_progress "$bg_pid" "Adding Proxmox repository" "Proxmox repository added"
  wait "$bg_pid"
  local exit_code=$?
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
  bg_pid=$!
  if [[ -z $bg_pid || ! $bg_pid =~ ^[0-9]+$ ]]; then
    log_error "Failed to start background job for package list update"
    exit 1
  fi
  show_progress "$bg_pid" "Updating package lists" "Package lists updated"
  wait "$bg_pid"
  exit_code=$?
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
  bg_pid=$!
  if [[ -z $bg_pid || ! $bg_pid =~ ^[0-9]+$ ]]; then
    log_error "Failed to start background job for package installation"
    exit 1
  fi
  show_progress "$bg_pid" "Installing required packages" "Required packages installed"
  wait "$bg_pid"
  exit_code=$?
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
