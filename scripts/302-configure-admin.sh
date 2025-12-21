# shellcheck shell=bash
# =============================================================================
# Configure non-root admin user
# Creates admin user with sudo privileges, sets up SSH key access
# Root SSH is disabled - all access via admin user
# =============================================================================

# Configuration function for admin user
_config_admin_user() {
  # Create user with home directory and bash shell, add to sudo group
  # shellcheck disable=SC2016
  remote_exec 'useradd -m -s /bin/bash -G sudo '"'$ADMIN_USERNAME'"'' || return 1

  # Set admin password
  # shellcheck disable=SC2016
  remote_exec 'echo '"'${ADMIN_USERNAME}:${ADMIN_PASSWORD}'"' | chpasswd' || return 1

  # Set up SSH directory for admin
  # shellcheck disable=SC2016
  remote_exec 'mkdir -p /home/'"'$ADMIN_USERNAME'"'/.ssh && chmod 700 /home/'"'$ADMIN_USERNAME'"'/.ssh' || return 1

  # Copy SSH key from root to admin user
  # shellcheck disable=SC2016
  remote_exec 'cp /root/.ssh/authorized_keys /home/'"'$ADMIN_USERNAME'"'/.ssh/authorized_keys' || return 1

  # Set correct permissions and ownership
  # shellcheck disable=SC2016
  remote_exec 'chmod 600 /home/'"'$ADMIN_USERNAME'"'/.ssh/authorized_keys' || return 1
  # shellcheck disable=SC2016
  remote_exec 'chown -R '"'$ADMIN_USERNAME:$ADMIN_USERNAME'"' /home/'"'$ADMIN_USERNAME'"'/.ssh' || return 1

  # Configure passwordless sudo for admin
  # shellcheck disable=SC2016
  remote_exec 'echo '"'$ADMIN_USERNAME ALL=(ALL) NOPASSWD:ALL'"' > /etc/sudoers.d/'"'$ADMIN_USERNAME'"'' || return 1
  # shellcheck disable=SC2016
  remote_exec 'chmod 440 /etc/sudoers.d/'"'$ADMIN_USERNAME'"'' || return 1
}

# Creates admin user with sudo privileges and SSH key access.
# Parameters: Uses global ADMIN_USERNAME, ADMIN_PASSWORD, SSH_PUBLIC_KEY
# Called before SSH hardening (which blocks root login)
configure_admin_user() {
  log "Creating admin user: $ADMIN_USERNAME"
  if ! run_with_progress "Creating admin user" "Admin user created" _config_admin_user; then
    log "ERROR: Failed to create admin user"
    return 1
  fi
  log "Admin user ${ADMIN_USERNAME} created successfully"
  return 0
}
