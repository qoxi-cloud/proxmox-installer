# shellcheck shell=bash
# Bat syntax highlighting configuration

# Configure bat with theme and symlink
_configure_bat() {
  remote_exec "ln -sf /usr/bin/batcat /usr/local/bin/bat" || return 1
  deploy_user_config "templates/bat-config" ".config/bat/config" || return 1
}
