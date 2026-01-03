# shellcheck shell=bash
# Systemd units deployment helpers

# Deploy .service + .timer and enable. $1=timer_name, $2=template_dir (optional)
deploy_systemd_timer() {
  local timer_name="$1"
  local template_dir="${2:+$2/}"

  remote_copy "templates/${template_dir}${timer_name}.service" \
    "/etc/systemd/system/${timer_name}.service" || {
    log_error "Failed to deploy ${timer_name} service"
    return 1
  }

  remote_copy "templates/${template_dir}${timer_name}.timer" \
    "/etc/systemd/system/${timer_name}.timer" || {
    log_error "Failed to deploy ${timer_name} timer"
    return 1
  }

  # Set proper permissions to avoid systemd warnings
  remote_exec "chmod 644 /etc/systemd/system/${timer_name}.service /etc/systemd/system/${timer_name}.timer" || {
    log_warn "Failed to set permissions on ${timer_name} unit files"
  }

  remote_exec "systemctl daemon-reload && systemctl enable --now ${timer_name}.timer" || {
    log_error "Failed to enable ${timer_name} timer"
    return 1
  }
}

# Deploy .service with template vars and enable. $1=service_name, $@=VAR=value
# Wrapper around deploy_template that also enables the service
deploy_systemd_service() {
  local service_name="$1"
  shift
  local template="templates/${service_name}.service"
  local dest="/etc/systemd/system/${service_name}.service"

  # Deploy using common function
  deploy_template "$template" "$dest" "$@" || return 1

  # Set proper permissions to avoid systemd warnings
  remote_exec "chmod 644 '$dest'" || {
    log_warn "Failed to set permissions on $dest"
  }

  remote_enable_services "${service_name}.service"
}

# Enable multiple systemd services (with daemon-reload). $@=service names
remote_enable_services() {
  local services=("$@")

  if [[ ${#services[@]} -eq 0 ]]; then
    return 0
  fi

  remote_exec "systemctl daemon-reload && systemctl enable --now ${services[*]}" || {
    log_error "Failed to enable services: ${services[*]}"
    return 1
  }
}
