# shellcheck shell=bash
# =============================================================================
# Test data fixtures
# =============================================================================

# =============================================================================
# SSH Key Fixtures
# =============================================================================
FIXTURE_SSH_ED25519="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example.com"
FIXTURE_SSH_RSA_4096="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8gJmY7E8GBi7lJX9vxKzTqK+jXmwIjJY3K3CnZHEIPp9f+8oQnM4qL3WwK1yGYJxZHcMnxJmKqQ3hZ8X/qFKBhFv2bqJfGkWxdZOyJfMJ7K7Kqp7PjKn9VfxVK3LqKvQC4N1p8z3nQyT1QH5y7M8RnU0vZ3J5Y2n5f9K7QwP8v3WfFxVc4q1P6B3N9qK7M8ZnXfJ5Y2n5f9K7QwP8v3WfFxVc4q1P6B3N9qK7M8ZnX test@example.com"
FIXTURE_SSH_INVALID="not-a-valid-ssh-key"
FIXTURE_SSH_DSA="ssh-dss AAAAB3NzaC1kc3MAAACBALKc test@example.com"

# =============================================================================
# Hostname Fixtures
# =============================================================================
FIXTURE_VALID_HOSTNAME="pve-server-01"
FIXTURE_VALID_HOSTNAME_SHORT="a"
FIXTURE_VALID_HOSTNAME_MAX="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
FIXTURE_INVALID_HOSTNAME_HYPHEN_START="-invalid"
FIXTURE_INVALID_HOSTNAME_HYPHEN_END="invalid-"
FIXTURE_INVALID_HOSTNAME_UNDERSCORE="invalid_host"
FIXTURE_INVALID_HOSTNAME_TOO_LONG="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

# =============================================================================
# Email Fixtures
# =============================================================================
FIXTURE_VALID_EMAIL="admin@example.com"
FIXTURE_VALID_EMAIL_SUBDOMAIN="user@mail.example.co.uk"
FIXTURE_VALID_EMAIL_PLUS="user+tag@example.com"
FIXTURE_INVALID_EMAIL_NO_AT="notanemail"
FIXTURE_INVALID_EMAIL_NO_DOMAIN="user@"
FIXTURE_INVALID_EMAIL_SPACE="user @example.com"

# =============================================================================
# Password Fixtures
# =============================================================================
FIXTURE_VALID_PASSWORD="SecurePass123!"
FIXTURE_VALID_PASSWORD_MIN="12345678"
FIXTURE_VALID_PASSWORD_SPECIAL="P@ssw0rd!#$%"
FIXTURE_INVALID_PASSWORD_SHORT="short"
FIXTURE_INVALID_PASSWORD_EMPTY=""
FIXTURE_INVALID_PASSWORD_UNICODE="pароль123"

# =============================================================================
# Network Fixtures - IPv4
# =============================================================================
FIXTURE_VALID_SUBNET_24="10.0.0.0/24"
FIXTURE_VALID_SUBNET_32="192.168.1.1/32"
FIXTURE_VALID_SUBNET_0="0.0.0.0/0"
FIXTURE_VALID_SUBNET_16="172.16.0.0/16"
FIXTURE_INVALID_SUBNET_PREFIX="10.0.0.0/33"
FIXTURE_INVALID_SUBNET_OCTET="256.0.0.0/24"
FIXTURE_INVALID_SUBNET_NO_PREFIX="10.0.0.0"

# =============================================================================
# Network Fixtures - IPv6
# =============================================================================
FIXTURE_VALID_IPV6_FULL="2001:0db8:85a3:0000:0000:8a2e:0370:7334"
FIXTURE_VALID_IPV6_COMPRESSED="2001:db8::1"
FIXTURE_VALID_IPV6_LOOPBACK="::1"
FIXTURE_VALID_IPV6_LINK_LOCAL="fe80::1"
FIXTURE_VALID_IPV6_CIDR="2001:db8::1/64"
FIXTURE_INVALID_IPV6_DOUBLE_COLON="2001::db8::1"
FIXTURE_INVALID_IPV6_LONG_GROUP="2001:db8:12345::1"
FIXTURE_INVALID_IPV6_IPV4="192.168.1.1"

# =============================================================================
# ZFS Fixtures
# =============================================================================
fixture_zfs_disks() {
  local count="${1:-2}"
  local disks=()
  for i in $(seq 1 "$count"); do
    disks+=("/dev/nvme$((i - 1))n1")
  done
  echo "${disks[@]}"
}

FIXTURE_ZFS_DISK_SINGLE="/dev/nvme0n1"
FIXTURE_ZFS_DISKS_2="/dev/nvme0n1 /dev/nvme1n1"
FIXTURE_ZFS_DISKS_3="/dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1"
FIXTURE_ZFS_DISKS_4="/dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1"

# =============================================================================
# Template Fixtures
# =============================================================================
fixture_template_with_vars() {
  cat <<'EOF'
[global]
hostname = "{{HOSTNAME}}"
ip_address = "{{MAIN_IPV4}}"
gateway = "{{MAIN_IPV4_GW}}"
EOF
}

fixture_template_no_vars() {
  cat <<'EOF'
[global]
hostname = "pve-test"
ip_address = "192.168.1.1"
EOF
}

fixture_interfaces_with_ipv6() {
  cat <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.168.1.1/24

iface eth0 inet6 static
    address 2001:db8::1/64
EOF
}

# =============================================================================
# FQDN Fixtures
# =============================================================================
FIXTURE_VALID_FQDN="server.example.com"
FIXTURE_VALID_FQDN_SUBDOMAIN="pve.dc1.example.co.uk"
FIXTURE_INVALID_FQDN_NO_DOT="localhost"
FIXTURE_INVALID_FQDN_HYPHEN="-server.example.com"

# =============================================================================
# Timezone Fixtures
# =============================================================================
FIXTURE_VALID_TIMEZONE="Europe/London"
FIXTURE_VALID_TIMEZONE_US="America/New_York"
FIXTURE_VALID_TIMEZONE_UTC="UTC"
FIXTURE_INVALID_TIMEZONE="Invalid/Timezone"
