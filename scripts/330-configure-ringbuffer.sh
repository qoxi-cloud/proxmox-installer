# shellcheck shell=bash
# Network Ring Buffer Tuning
# Increases ring buffer size for better throughput and reduced packet drops
# Package (ethtool) installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for ring buffer tuning
# Deploys systemd service and script to maximize RX/TX ring buffer size
# Requires: INTERFACE_NAME (set by 052-system-network.sh)
_config_ringbuffer() {
  local ringbuffer_interface="${INTERFACE_NAME:-eth0}"

  # Deploy the script first
  deploy_template "templates/network-ringbuffer.sh" "/usr/local/bin/network-ringbuffer.sh" \
    "RINGBUFFER_INTERFACE=${ringbuffer_interface}" || return 1
  remote_exec "chmod +x /usr/local/bin/network-ringbuffer.sh" || return 1

  # Deploy the service (no longer needs interface var - script handles it)
  deploy_systemd_service "network-ringbuffer" || return 1
  parallel_mark_configured "ringbuffer"
}

# Public wrapper (generated via factory)
make_feature_wrapper "ringbuffer" "INSTALL_RINGBUFFER"
