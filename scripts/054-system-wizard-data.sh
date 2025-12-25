# shellcheck shell=bash
# =============================================================================
# Wizard data loading (timezones, countries, mappings)
# =============================================================================

# Loads available timezones from system for wizard selection.
# Uses timedatectl if available, falls back to parsing zoneinfo directory.
# Side effects: Sets WIZ_TIMEZONES global variable
_load_timezones() {
  if command -v timedatectl &>/dev/null; then
    WIZ_TIMEZONES=$(timedatectl list-timezones 2>/dev/null)
  else
    # Fallback: parse zoneinfo directory
    WIZ_TIMEZONES=$(find /usr/share/zoneinfo -type f 2>/dev/null \
      | sed 's|/usr/share/zoneinfo/||' \
      | grep -E '^(Africa|America|Antarctica|Asia|Atlantic|Australia|Europe|Indian|Pacific)/' \
      | sort)
  fi
  # Add UTC at the end
  WIZ_TIMEZONES+=$'\nUTC'
}

# Loads ISO 3166-1 alpha-2 country codes for wizard selection.
# Uses iso-codes package if available, falls back to locale data.
# Side effects: Sets WIZ_COUNTRIES global variable
_load_countries() {
  local iso_file="/usr/share/iso-codes/json/iso_3166-1.json"
  if [[ -f $iso_file ]]; then
    # Parse JSON with grep (no jq dependency for this)
    WIZ_COUNTRIES=$(grep -oP '"alpha_2":\s*"\K[^"]+' "$iso_file" | tr '[:upper:]' '[:lower:]' | sort)
  else
    # Fallback: extract from locale data
    WIZ_COUNTRIES=$(locale -a 2>/dev/null | grep -oP '^[a-z]{2}(?=_)' | sort -u)
  fi
}

# Builds timezone to country mapping from zone.tab file.
# Used for auto-selecting country based on timezone selection.
# Side effects: Sets TZ_TO_COUNTRY associative array
_build_tz_to_country() {
  declare -gA TZ_TO_COUNTRY
  local zone_tab="/usr/share/zoneinfo/zone.tab"
  [[ -f $zone_tab ]] || return 0

  while IFS=$'\t' read -r country _ tz _; do
    [[ $country == \#* ]] && continue
    [[ -z $tz ]] && continue
    TZ_TO_COUNTRY["$tz"]="${country,,}" # lowercase
  done <"$zone_tab"
}

# Detects existing ZFS pools for wizard display.
# Side effects: Populates DETECTED_POOLS array
_detect_pools() {
  DETECTED_POOLS=()
  while IFS= read -r line; do
    [[ -n $line ]] && DETECTED_POOLS+=("$line")
  done < <(detect_existing_pools 2>/dev/null)

  if [[ ${#DETECTED_POOLS[@]} -gt 0 ]]; then
    log "Detected ${#DETECTED_POOLS[@]} existing ZFS pool(s):"
    for pool in "${DETECTED_POOLS[@]}"; do
      log "  - $pool"
    done
  fi
}

# Loads all dynamic wizard data from system.
# Orchestrates loading of timezones, countries, and TZ-to-country mapping.
# Called by collect_system_info() during initialization.
_load_wizard_data() {
  _load_timezones
  _load_countries
  _build_tz_to_country
  _detect_pools
}
