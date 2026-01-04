# shellcheck shell=bash
# Yazi file manager configuration
# Modern terminal file manager with image preview support
# Package and dependencies installed via batch_install_packages() in 033-parallel-helpers.sh
# Config is deployed to admin user's home directory (not root)

# Configuration function for yazi - deploys theme and plugins
_config_yazi() {

  # Install flavor and plugins as admin user
  # Note: ya pkg may fail if network is unavailable - log warning but don't fail
  # Yazi still works without plugins, user can install later
  # shellcheck disable=SC2016
  remote_exec 'su - '"${ADMIN_USERNAME}"' -c "
    ya pkg add kalidyasin/yazi-flavors:tokyonight-night || echo \"WARNING: Failed to install yazi flavor\" >&2
    ya pkg add yazi-rs/plugins:chmod || echo \"WARNING: Failed to install chmod plugin\" >&2
    ya pkg add yazi-rs/plugins:smart-enter || echo \"WARNING: Failed to install smart-enter plugin\" >&2
    ya pkg add yazi-rs/plugins:smart-filter || echo \"WARNING: Failed to install smart-filter plugin\" >&2
    ya pkg add yazi-rs/plugins:full-border || echo \"WARNING: Failed to install full-border plugin\" >&2
  "' || {
    log_warn "Failed to install some yazi plugins (yazi will still work)"
  }

  deploy_user_configs \
    "templates/yazi.toml:.config/yazi/yazi.toml" \
    "templates/yazi-theme.toml:.config/yazi/theme.toml" \
    "templates/yazi-init.lua:.config/yazi/init.lua" \
    "templates/yazi-keymap.toml:.config/yazi/keymap.toml" || {
    log_error "Failed to deploy yazi configs"
    return 1
  }

  parallel_mark_configured "yazi"
}

# Public wrapper (generated via factory)
# Installs yazi file manager with Tokyo Night theme
make_feature_wrapper "yazi" "INSTALL_YAZI"
