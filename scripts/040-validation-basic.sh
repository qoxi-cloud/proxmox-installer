# shellcheck shell=bash
# =============================================================================
# Basic validation functions (hostname, user, email, password)
# =============================================================================

# Validates hostname format (alphanumeric, hyphens, 1-63 chars).
# Parameters:
#   $1 - Hostname to validate
# Returns: 0 if valid, 1 otherwise
validate_hostname() {
  local hostname="$1"
  # Reject reserved hostname "localhost"
  [[ ${hostname,,} == "localhost" ]] && return 1
  # Hostname: alphanumeric and hyphens, 1-63 chars, cannot start/end with hyphen
  [[ $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]
}

# Validates admin username format for Linux systems.
# Must be lowercase, start with letter, 1-32 chars.
# Blocks reserved system usernames.
# Parameters:
#   $1 - Username to validate
# Returns: 0 if valid, 1 otherwise
validate_admin_username() {
  local username="$1"

  # Must be lowercase alphanumeric, can contain underscore/hyphen, 1-32 chars
  # Must start with a letter
  [[ ! $username =~ ^[a-z][a-z0-9_-]{0,31}$ ]] && return 1

  # Block reserved system usernames
  case "$username" in
    root | nobody | daemon | bin | sys | sync | games | man | lp | mail | \
      news | uucp | proxy | www-data | backup | list | irc | gnats | \
      sshd | systemd-network | systemd-resolve | messagebus | \
      polkitd | postfix | syslog | _apt | tss | uuidd | avahi | colord | \
      cups-pk-helper | dnsmasq | geoclue | hplip | kernoops | lightdm | \
      nm-openconnect | nm-openvpn | pulse | rtkit | saned | speech-dispatcher | \
      whoopsie | admin | administrator | operator | guest)
      return 1
      ;;
  esac

  return 0
}

# Validates fully qualified domain name format.
# Parameters:
#   $1 - FQDN to validate
# Returns: 0 if valid, 1 otherwise
validate_fqdn() {
  local fqdn="$1"
  # FQDN: valid hostname labels separated by dots
  [[ $fqdn =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]]
}

# Validates email address format (basic check).
# Parameters:
#   $1 - Email address to validate
# Returns: 0 if valid, 1 otherwise
validate_email() {
  local email="$1"
  # Basic email validation
  [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

# Checks if string contains only ASCII printable characters.
# Parameters:
#   $1 - String to check
# Returns: 0 if all ASCII printable, 1 otherwise
is_ascii_printable() {
  LC_ALL=C bash -c '[[ "$1" =~ ^[[:print:]]+$ ]]' _ "$1"
}

# Returns descriptive error message for invalid password.
# Parameters:
#   $1 - Password to check
# Returns: Error message via stdout, empty if valid
get_password_error() {
  local password="$1"
  if [[ -z $password ]]; then
    printf '%s\n' "Password cannot be empty!"
  elif [[ ${#password} -lt 8 ]]; then
    printf '%s\n' "Password must be at least 8 characters long."
  elif ! is_ascii_printable "$password"; then
    printf '%s\n' "Password contains invalid characters (Cyrillic or non-ASCII). Only Latin letters, digits, and special characters are allowed."
  fi
}
