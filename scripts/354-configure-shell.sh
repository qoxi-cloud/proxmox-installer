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
