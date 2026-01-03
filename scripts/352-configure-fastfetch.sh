# shellcheck shell=bash
# Fastfetch shell integration

# Configure fastfetch shell integration
_configure_fastfetch() {
  remote_copy "templates/fastfetch.sh" "/etc/profile.d/fastfetch.sh" || return 1
  remote_exec "chmod +x /etc/profile.d/fastfetch.sh" || return 1
}
