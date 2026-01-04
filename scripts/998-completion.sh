# shellcheck shell=bash
# Completion screen - shows credentials and handles reboot

_render_completion_screen() {
  local output=""
  local banner_output

  # Capture banner output
  banner_output=$(show_banner)

  # Start output with banner
  output+="${banner_output}\n\n"

  # Success header (wizard step continuation style)
  output+="$(format_wizard_header "Installation Complete")\n\n"

  # Warning to save credentials
  output+="  ${CLR_YELLOW}⚠ SAVE THESE CREDENTIALS${CLR_RESET}\n\n"

  # Helper to add field (wizard style)
  _cred_field() {
    local label="$1" value="$2" note="${3:-}"
    if [[ -n $label ]]; then
      output+="  ${CLR_GRAY}${label}${CLR_RESET}${value}"
    else
      output+="                   ${value}"
    fi
    [[ -n $note ]] && output+=" ${CLR_GRAY}${note}${CLR_RESET}"
    output+="\n"
  }

  # System info
  _cred_field "Hostname         " "${CLR_CYAN}${PVE_HOSTNAME}.${DOMAIN_SUFFIX}${CLR_RESET}"
  output+="\n"

  # Admin credentials (SSH + Proxmox UI)
  _cred_field "Admin User       " "${CLR_CYAN}${ADMIN_USERNAME}${CLR_RESET}"
  _cred_field "Admin Password   " "${CLR_ORANGE}${ADMIN_PASSWORD}${CLR_RESET}" "(SSH + Proxmox UI)"
  output+="\n"

  # Root credentials (console/KVM only - SSH blocked)
  _cred_field "Root Password    " "${CLR_ORANGE}${NEW_ROOT_PASSWORD}${CLR_RESET}" "(console/KVM only)"
  output+="\n"

  # Determine access based on firewall mode
  local has_tailscale=""
  [[ -n $TAILSCALE_IP && $TAILSCALE_IP != "pending" && $TAILSCALE_IP != "not authenticated" ]] && has_tailscale="yes"

  case "${FIREWALL_MODE:-standard}" in
    stealth)
      if [[ $has_tailscale == "yes" ]]; then
        _cred_field "SSH              " "${CLR_CYAN}ssh ${ADMIN_USERNAME}@${TAILSCALE_IP}${CLR_RESET}" "(Tailscale)"
        _cred_field "Web UI           " "${CLR_CYAN}https://${TAILSCALE_IP}${CLR_RESET}" "(Tailscale)"
      else
        _cred_field "SSH              " "${CLR_YELLOW}blocked${CLR_RESET}" "(stealth mode)"
        _cred_field "Web UI           " "${CLR_YELLOW}blocked${CLR_RESET}" "(stealth mode)"
      fi
      ;;
    strict)
      _cred_field "SSH              " "${CLR_CYAN}ssh ${ADMIN_USERNAME}@${MAIN_IPV4}${CLR_RESET}"
      if [[ $has_tailscale == "yes" ]]; then
        _cred_field "" "${CLR_CYAN}ssh ${ADMIN_USERNAME}@${TAILSCALE_IP}${CLR_RESET}" "(Tailscale)"
        _cred_field "Web UI           " "${CLR_CYAN}https://${TAILSCALE_IP}${CLR_RESET}" "(Tailscale)"
      else
        _cred_field "Web UI           " "${CLR_YELLOW}blocked${CLR_RESET}" "(strict mode)"
      fi
      ;;
    *)
      _cred_field "SSH              " "${CLR_CYAN}ssh ${ADMIN_USERNAME}@${MAIN_IPV4}${CLR_RESET}"
      [[ $has_tailscale == "yes" ]] && _cred_field "" "${CLR_CYAN}ssh ${ADMIN_USERNAME}@${TAILSCALE_IP}${CLR_RESET}" "(Tailscale)"
      _cred_field "Web UI           " "${CLR_CYAN}https://${MAIN_IPV4}${CLR_RESET}"
      [[ $has_tailscale == "yes" ]] && _cred_field "" "${CLR_CYAN}https://${TAILSCALE_IP}${CLR_RESET}" "(Tailscale)"
      ;;
  esac

  # API Token (if created) - uses centralized path constant from 003-init.sh
  if [[ -f "$_TEMP_API_TOKEN_FILE" ]]; then
    # Validate file contains only expected API token variables (defense in depth)
    if grep -qvE '^API_TOKEN_(VALUE|ID|NAME)=' "$_TEMP_API_TOKEN_FILE"; then
      log_error "API token file contains unexpected content"
    else
      # shellcheck disable=SC1090,SC1091
      source "$_TEMP_API_TOKEN_FILE"
    fi

    if [[ -n $API_TOKEN_VALUE ]]; then
      output+="\n"
      _cred_field "API Token ID     " "${CLR_CYAN}${API_TOKEN_ID}${CLR_RESET}"
      _cred_field "API Secret       " "${CLR_ORANGE}${API_TOKEN_VALUE}${CLR_RESET}"
    fi
  fi

  output+="\n"

  # Centered footer
  local footer_text="${CLR_GRAY}[${CLR_ORANGE}Enter${CLR_GRAY}] reboot  [${CLR_ORANGE}Q${CLR_GRAY}] quit without reboot${CLR_RESET}"
  output+="$(_wiz_center "$footer_text")"

  # Clear and render
  _wiz_clear
  printf '%b' "$output"
}

# Handle completion screen input (Enter=reboot, Q=exit)
_completion_screen_input() {
  while true; do
    _render_completion_screen

    # Read single keypress
    local key
    IFS= read -rsn1 key

    case "$key" in
      q | Q)
        printf '\n'
        print_info "Exiting without reboot."
        printf '\n'
        print_info "You can reboot manually when ready with: ${CLR_CYAN}reboot${CLR_RESET}"
        exit 0
        ;;
      "")
        # Enter pressed - reboot
        printf '\n'
        print_info "Rebooting the system..."
        if ! reboot; then
          log_error "Failed to reboot - system may require manual restart"
          print_error "Failed to reboot the system"
          exit 1
        fi
        ;;
    esac
  done
}

# Finishes live installation display and shows completion screen.
# Prompts user to reboot or exit without reboot.
reboot_to_main_os() {
  # Finish live installation display
  finish_live_installation

  # Show completion screen with wizard style
  _completion_screen_input
}
