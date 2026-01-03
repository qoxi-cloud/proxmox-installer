# shellcheck shell=bash
# User config deployment helpers

# Deploy config to admin home. Creates dirs, sets ownership, applies template vars.
# $1=template, $2=relative_path (e.g. ".config/bat/config"), $@=VAR=value (optional)
deploy_user_config() {
  require_admin_username "deploy user config" || return 1

  local template="$1"
  local relative_path="$2"
  shift 2
  local home_dir="/home/${ADMIN_USERNAME}"
  local dest="${home_dir}/${relative_path}"
  local dest_dir staged
  dest_dir="$(dirname "$dest")"

  # Stage template to temp location to preserve original
  staged=$(mktemp) || {
    log_error "Failed to create temp file for $template"
    return 1
  }
  register_temp_file "$staged"
  cp "$template" "$staged" || {
    log_error "Failed to stage template $template"
    rm -f "$staged"
    return 1
  }

  # Apply template vars (also validates no unsubstituted placeholders remain)
  apply_template_vars "$staged" "$@" || {
    log_error "Template substitution failed for $template"
    rm -f "$staged"
    return 1
  }

  # Create parent directory if needed (skip if deploying to home root)
  if [[ "$dest_dir" != "$home_dir" ]]; then
    remote_exec "mkdir -p '$dest_dir'" || {
      log_error "Failed to create directory $dest_dir"
      rm -f "$staged"
      return 1
    }
    # Fix ownership of ALL directories created by mkdir -p (they're created as root)
    # Walk up from dest_dir to home, collecting all intermediate directories
    local dirs_to_chown=""
    local dir="$dest_dir"
    while [[ "$dir" != "$home_dir" && "$dir" != "/" ]]; do
      # Escape single quotes in path for safe shell quoting
      local escaped_dir="${dir//\'/\'\\\'\'}"
      dirs_to_chown+="'$escaped_dir' "
      dir="$(dirname "$dir")"
    done
    [[ -n $dirs_to_chown ]] && {
      remote_exec "chown ${ADMIN_USERNAME}:${ADMIN_USERNAME} $dirs_to_chown" || {
        log_error "Failed to set ownership on $dirs_to_chown"
        rm -f "$staged"
        return 1
      }
    }
  fi

  # Copy file
  remote_copy "$staged" "$dest" || {
    log_error "Failed to copy $template to $dest"
    rm -f "$staged"
    return 1
  }
  rm -f "$staged"

  # Set ownership
  remote_exec "chown ${ADMIN_USERNAME}:${ADMIN_USERNAME} '$dest'" || {
    log_error "Failed to set ownership on $dest"
    return 1
  }
}

# Batch deploy configs to admin home. $@="template:relative_dest" pairs
deploy_user_configs() {
  for pair in "$@"; do
    local template="${pair%%:*}"
    local relative="${pair#*:}"
    deploy_user_config "$template" "$relative" || return 1
  done
}
