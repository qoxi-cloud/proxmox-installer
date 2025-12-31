# shellcheck shell=bash
# Basic validation functions (hostname, user, email, password)

# Validate hostname format. $1=hostname
validate_hostname() {
  local hostname="$1"
  # Reject reserved hostname "localhost"
  [[ ${hostname,,} == "localhost" ]] && return 1
  # Hostname: alphanumeric and hyphens, 1-63 chars, cannot start/end with hyphen
  [[ $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]
}

# Validate admin username (lowercase, starts with letter, 1-32 chars). $1=username
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

# Validate FQDN format. $1=fqdn
validate_fqdn() {
  local fqdn="$1"
  # FQDN: valid hostname labels separated by dots
  [[ $fqdn =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]]
}

# Validate email format. $1=email
validate_email() {
  local email="$1"
  # Basic email validation
  [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

# Validate SMTP host (hostname, FQDN, or IP). $1=host
validate_smtp_host() {
  local host="$1"
  [[ -z $host ]] && return 1
  # Accept: hostname, FQDN, IPv4, or IPv6
  # Relaxed: alphanumeric, dots, hyphens, colons (IPv6), brackets
  # Note: ] must be first in class, - must be last for literal matching
  [[ $host =~ ^[][a-zA-Z0-9.:-]+$ ]] && [[ ${#host} -le 253 ]]
}

# Validate SMTP port (1-65535). $1=port
validate_smtp_port() {
  local port="$1"
  [[ $port =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535))
}

# Validate non-empty string. $1=string
validate_not_empty() {
  [[ -n $1 ]]
}

# Check if string is ASCII printable. $1=string
is_ascii_printable() {
  local LC_ALL=C
  [[ $1 =~ ^[[:print:]]+$ ]]
}

# Get password error message (empty if valid). $1=password → error_msg
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
