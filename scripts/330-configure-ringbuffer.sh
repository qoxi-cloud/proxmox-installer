# shellcheck shell=bash
# Network Ring Buffer Tuning
# Increases ring buffer size for better throughput and reduced packet drops
# Package (ethtool) installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for ring buffer tuning
# Deploys systemd service and script to maximize RX/TX ring buffer size
_config_ringbuffer() {
  # Deploy the script (auto-detects physical interfaces at runtime)
  remote_copy "templates/network-ringbuffer.sh" "/usr/local/bin/network-ringbuffer.sh" || return 1
  remote_exec "chmod +x /usr/local/bin/network-ringbuffer.sh" || return 1

  deploy_systemd_service "network-ringbuffer" || return 1
  parallel_mark_configured "ringbuffer"
}

# Public wrapper (generated via factory)
make_feature_wrapper "ringbuffer" "INSTALL_RINGBUFFER"
