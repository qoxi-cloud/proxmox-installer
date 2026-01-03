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
