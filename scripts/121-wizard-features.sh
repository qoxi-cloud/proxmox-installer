# shellcheck shell=bash
# =============================================================================
# Configuration Wizard - Shell, Power, and Features Editors
# shell, power_profile, features (security, monitoring, tools)
# =============================================================================

# Edits default shell for root user.
# Options: zsh (with Powerlevel10k) or bash.
# Updates SHELL_TYPE global.
_edit_shell() {
  _wiz_start_edit

  _wiz_description \
    "  Default shell for root user:" \
    "" \
    "  {{cyan:ZSH}}:  Modern shell with Powerlevel10k prompt" \
    "  {{cyan:Bash}}: Standard shell (minimal changes)" \
    ""

  # 1 header + 2 items for gum choose
  _show_input_footer "filter" 3

  local selected
  if ! selected=$(printf '%s\n' "$WIZ_SHELL_OPTIONS" | _wiz_choose --header="Shell:"); then
    return
  fi

  case "$selected" in
    "ZSH") SHELL_TYPE="zsh" ;;
    "Bash") SHELL_TYPE="bash" ;;
  esac
}

# Edits CPU frequency scaling governor.
# Dynamically detects available governors from sysfs.
# Updates CPU_GOVERNOR global.
_edit_power_profile() {
  _wiz_start_edit

  # Detect available governors from sysfs
  local avail_governors=""
  if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ]]; then
    avail_governors=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)
  fi

  # Build dynamic options based on available governors
  local options=()
  local descriptions=()

  # Always show Performance if available
  if [[ -z $avail_governors ]] || printf '%s\n' "$avail_governors" | grep -qw "performance"; then
    options+=("Performance")
    descriptions+=("  {{cyan:Performance}}:  Max frequency (highest power)")
  fi

  # Show governor-specific options
  if printf '%s\n' "$avail_governors" | grep -qw "ondemand"; then
    options+=("Balanced")
    descriptions+=("  {{cyan:Balanced}}:     Scale based on load")
  elif printf '%s\n' "$avail_governors" | grep -qw "powersave"; then
    # intel_pstate powersave is actually dynamic scaling
    options+=("Balanced")
    descriptions+=("  {{cyan:Balanced}}:     Dynamic scaling (power efficient)")
  fi

  if printf '%s\n' "$avail_governors" | grep -qw "schedutil"; then
    options+=("Adaptive")
    descriptions+=("  {{cyan:Adaptive}}:     Kernel-managed scaling")
  fi

  if printf '%s\n' "$avail_governors" | grep -qw "conservative"; then
    options+=("Conservative")
    descriptions+=("  {{cyan:Conservative}}: Gradual frequency changes")
  fi

  # Fallback if no governors detected
  if [[ ${#options[@]} -eq 0 ]]; then
    options=("Performance" "Balanced")
    descriptions=(
      "  {{cyan:Performance}}:  Max frequency (highest power)"
      "  {{cyan:Balanced}}:     Dynamic scaling (power efficient)"
    )
  fi

  _wiz_description \
    "  CPU frequency scaling governor:" \
    "" \
    "${descriptions[@]}" \
    ""

  # 1 header + N items for gum choose
  _show_input_footer "filter" $((${#options[@]} + 1))

  local options_str
  options_str=$(printf '%s\n' "${options[@]}")

  local selected
  if ! selected=$(printf '%s\n' "$options_str" | _wiz_choose --header="Power profile:"); then
    return
  fi

  case "$selected" in
    "Performance") CPU_GOVERNOR="performance" ;;
    "Balanced")
      # Use ondemand if available, otherwise powersave
      if printf '%s\n' "$avail_governors" | grep -qw "ondemand"; then
        CPU_GOVERNOR="ondemand"
      else
        CPU_GOVERNOR="powersave"
      fi
      ;;
    "Adaptive") CPU_GOVERNOR="schedutil" ;;
    "Conservative") CPU_GOVERNOR="conservative" ;;
  esac
}

# =============================================================================
# Features - Security
# =============================================================================

# Edits security feature toggles via multi-select checkbox.
# Options: apparmor, auditd, aide, chkrootkit, lynis, needrestart.
# Updates corresponding INSTALL_* globals.
_edit_features_security() {
  _wiz_start_edit

  _wiz_description \
    "  Security features (use Space to toggle):" \
    "" \
    "  {{cyan:apparmor}}:    Mandatory access control (MAC)" \
    "  {{cyan:auditd}}:      Security audit logging" \
    "  {{cyan:aide}}:        File integrity monitoring (daily)" \
    "  {{cyan:chkrootkit}}:  Rootkit scanning (weekly)" \
    "  {{cyan:lynis}}:       Security auditing (weekly)" \
    "  {{cyan:needrestart}}: Auto-restart services after updates" \
    ""

  _show_input_footer "checkbox" 7

  local gum_args=(--header="Security:")
  [[ $INSTALL_APPARMOR == "yes" ]] && gum_args+=(--selected "apparmor")
  [[ $INSTALL_AUDITD == "yes" ]] && gum_args+=(--selected "auditd")
  [[ $INSTALL_AIDE == "yes" ]] && gum_args+=(--selected "aide")
  [[ $INSTALL_CHKROOTKIT == "yes" ]] && gum_args+=(--selected "chkrootkit")
  [[ $INSTALL_LYNIS == "yes" ]] && gum_args+=(--selected "lynis")
  [[ $INSTALL_NEEDRESTART == "yes" ]] && gum_args+=(--selected "needrestart")

  local selected
  if ! selected=$(printf '%s\n' "$WIZ_FEATURES_SECURITY" | _wiz_choose_multi "${gum_args[@]}"); then
    return
  fi

  INSTALL_APPARMOR=$([[ $selected == *apparmor* ]] && echo "yes" || echo "no")
  INSTALL_AUDITD=$([[ $selected == *auditd* ]] && echo "yes" || echo "no")
  INSTALL_AIDE=$([[ $selected == *aide* ]] && echo "yes" || echo "no")
  INSTALL_CHKROOTKIT=$([[ $selected == *chkrootkit* ]] && echo "yes" || echo "no")
  INSTALL_LYNIS=$([[ $selected == *lynis* ]] && echo "yes" || echo "no")
  INSTALL_NEEDRESTART=$([[ $selected == *needrestart* ]] && echo "yes" || echo "no")
}

# =============================================================================
# Features - Monitoring
# =============================================================================

# Edits monitoring feature toggles via multi-select checkbox.
# Options: vnstat, netdata, promtail.
# Updates corresponding INSTALL_* globals.
_edit_features_monitoring() {
  _wiz_start_edit

  _wiz_description \
    "  Monitoring features (use Space to toggle):" \
    "" \
    "  {{cyan:vnstat}}:   Network traffic monitoring" \
    "  {{cyan:netdata}}:  Real-time monitoring (port 19999)" \
    "  {{cyan:promtail}}: Log collector for Loki" \
    ""

  _show_input_footer "checkbox" 4

  local gum_args=(--header="Monitoring:")
  [[ $INSTALL_VNSTAT == "yes" ]] && gum_args+=(--selected "vnstat")
  [[ $INSTALL_NETDATA == "yes" ]] && gum_args+=(--selected "netdata")
  [[ $INSTALL_PROMTAIL == "yes" ]] && gum_args+=(--selected "promtail")

  local selected
  if ! selected=$(printf '%s\n' "$WIZ_FEATURES_MONITORING" | _wiz_choose_multi "${gum_args[@]}"); then
    return
  fi

  INSTALL_VNSTAT=$([[ $selected == *vnstat* ]] && echo "yes" || echo "no")
  INSTALL_NETDATA=$([[ $selected == *netdata* ]] && echo "yes" || echo "no")
  INSTALL_PROMTAIL=$([[ $selected == *promtail* ]] && echo "yes" || echo "no")
}

# =============================================================================
# Features - Tools
# =============================================================================

# Edits tools feature toggles via multi-select checkbox.
# Options: yazi (file manager), nvim (editor), ringbuffer (network tuning).
# Updates corresponding INSTALL_* globals.
_edit_features_tools() {
  _wiz_start_edit

  _wiz_description \
    "  Tools (use Space to toggle):" \
    "" \
    "  {{cyan:yazi}}:       Terminal file manager (Catppuccin theme)" \
    "  {{cyan:nvim}}:       Neovim as default editor" \
    "  {{cyan:ringbuffer}}: Network ring buffer tuning" \
    ""

  _show_input_footer "checkbox" 4

  local gum_args=(--header="Tools:")
  [[ $INSTALL_YAZI == "yes" ]] && gum_args+=(--selected "yazi")
  [[ $INSTALL_NVIM == "yes" ]] && gum_args+=(--selected "nvim")
  [[ $INSTALL_RINGBUFFER == "yes" ]] && gum_args+=(--selected "ringbuffer")

  local selected
  if ! selected=$(printf '%s\n' "$WIZ_FEATURES_TOOLS" | _wiz_choose_multi "${gum_args[@]}"); then
    return
  fi

  INSTALL_YAZI=$([[ $selected == *yazi* ]] && echo "yes" || echo "no")
  INSTALL_NVIM=$([[ $selected == *nvim* ]] && echo "yes" || echo "no")
  INSTALL_RINGBUFFER=$([[ $selected == *ringbuffer* ]] && echo "yes" || echo "no")
}
