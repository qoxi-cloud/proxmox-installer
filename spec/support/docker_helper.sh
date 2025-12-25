# shellcheck shell=bash
# =============================================================================
# Docker container management for integration tests
# =============================================================================

DOCKER_COMPOSE_FILE="${SPEC_ROOT}/spec/docker/docker-compose.yml"
INTEGRATION_SSHD_CONTAINER="integration-sshd"
INTEGRATION_TARGET_CONTAINER="integration-target"
INTEGRATION_HTTP_CONTAINER="integration-httpserver"
INTEGRATION_SSH_PORT="${INTEGRATION_SSH_PORT:-2222}"
INTEGRATION_HTTP_PORT="${INTEGRATION_HTTP_PORT:-8888}"
INTEGRATION_SSH_PASSWORD="testpass123"

# =============================================================================
# Container lifecycle
# =============================================================================

# Start integration test containers
# Returns: 0 on success, 1 on failure
start_integration_containers() {
  if ! command -v docker &>/dev/null; then
    echo "ERROR: docker not found" >&2
    return 1
  fi

  docker compose -f "$DOCKER_COMPOSE_FILE" up -d --build --wait 2>/dev/null
}

# Stop and remove integration test containers
stop_integration_containers() {
  docker compose -f "$DOCKER_COMPOSE_FILE" down -v 2>/dev/null || true
}

# Check if containers are running
containers_running() {
  local sshd_running target_running
  sshd_running=$(docker inspect -f '{{.State.Running}}' "$INTEGRATION_SSHD_CONTAINER" 2>/dev/null || echo "false")
  target_running=$(docker inspect -f '{{.State.Running}}' "$INTEGRATION_TARGET_CONTAINER" 2>/dev/null || echo "false")
  [[ $sshd_running == "true" ]] && [[ $target_running == "true" ]]
}

# Check if HTTP server container is running
http_server_running() {
  local http_running
  http_running=$(docker inspect -f '{{.State.Running}}' "$INTEGRATION_HTTP_CONTAINER" 2>/dev/null || echo "false")
  [[ $http_running == "true" ]]
}

# Wait for HTTP server to be ready
wait_for_http_server() {
  local timeout="${1:-30}"
  local elapsed=0

  while ((elapsed < timeout)); do
    if curl -sf "http://localhost:$INTEGRATION_HTTP_PORT/iso/" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    ((elapsed++))
  done
  return 1
}

# Get HTTP server base URL
http_server_url() {
  printf '%s\n' "http://localhost:$INTEGRATION_HTTP_PORT"
}

# =============================================================================
# ZFS tools container helpers
# =============================================================================
INTEGRATION_ZFS_CONTAINER="integration-zfstools"

# Check if ZFS tools container is running
zfs_tools_running() {
  local zfs_running
  zfs_running=$(docker inspect -f '{{.State.Running}}' "$INTEGRATION_ZFS_CONTAINER" 2>/dev/null || echo "false")
  [[ $zfs_running == "true" ]]
}

# Execute command in ZFS tools container
zfs_tools_exec() {
  docker exec "$INTEGRATION_ZFS_CONTAINER" bash -c "$*"
}

# Validate zpool command syntax
validate_zpool_command() {
  local cmd="$1"
  docker exec "$INTEGRATION_ZFS_CONTAINER" /usr/local/bin/validate-zpool-cmd.sh "$cmd"
}

# Run mock zpool command
mock_zpool() {
  docker exec "$INTEGRATION_ZFS_CONTAINER" /usr/local/bin/mock-zpool "$@"
}

# =============================================================================
# SSH connection helpers
# =============================================================================

# Wait for SSHD to accept connections
# Parameters:
#   $1 - Timeout in seconds (default: 30)
wait_for_sshd() {
  local timeout="${1:-30}"
  local elapsed=0

  while ((elapsed < timeout)); do
    if (echo >/dev/tcp/localhost/"$INTEGRATION_SSH_PORT") 2>/dev/null; then
      # Also verify SSH banner
      if timeout 2 bash -c "echo '' | nc localhost $INTEGRATION_SSH_PORT" 2>/dev/null | grep -q SSH; then
        return 0
      fi
    fi
    sleep 1
    ((elapsed++))
  done
  return 1
}

# Execute command in sshd container via SSH
# Parameters:
#   $* - Command to execute
integration_ssh_exec() {
  local passfile
  passfile=$(mktemp)
  echo "$INTEGRATION_SSH_PASSWORD" >"$passfile"
  chmod 600 "$passfile"

  local result=0
  # shellcheck disable=SC2086
  sshpass -f "$passfile" ssh -p "$INTEGRATION_SSH_PORT" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -o ConnectTimeout=5 \
    root@localhost "$@" || result=$?

  rm -f "$passfile"
  return $result
}

# Copy file to sshd container via SCP
# Parameters:
#   $1 - Source path
#   $2 - Destination path
integration_ssh_copy() {
  local src="$1"
  local dst="$2"
  local passfile
  passfile=$(mktemp)
  echo "$INTEGRATION_SSH_PASSWORD" >"$passfile"
  chmod 600 "$passfile"

  local result=0
  # shellcheck disable=SC2086
  sshpass -f "$passfile" scp -P "$INTEGRATION_SSH_PORT" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    "$src" "root@localhost:$dst" || result=$?

  rm -f "$passfile"
  return $result
}

# =============================================================================
# Target container helpers (for config deployment tests)
# =============================================================================

# Execute command in target container directly (via docker exec)
# Parameters:
#   $* - Command to execute
target_exec() {
  docker exec "$INTEGRATION_TARGET_CONTAINER" bash -c "$*"
}

# Copy file to target container
# Parameters:
#   $1 - Source path
#   $2 - Destination path
target_copy() {
  docker cp "$1" "${INTEGRATION_TARGET_CONTAINER}:$2"
}

# Reset target container to clean state
reset_target_container() {
  docker compose -f "$DOCKER_COMPOSE_FILE" restart target 2>/dev/null
  sleep 3
}

# Check if file exists in target container
# Parameters:
#   $1 - File path
target_file_exists() {
  docker exec "$INTEGRATION_TARGET_CONTAINER" test -f "$1"
}

# Get file contents from target container
# Parameters:
#   $1 - File path
target_cat() {
  docker exec "$INTEGRATION_TARGET_CONTAINER" cat "$1"
}

# Check if systemd service is enabled
# Parameters:
#   $1 - Service name
target_service_enabled() {
  docker exec "$INTEGRATION_TARGET_CONTAINER" systemctl is-enabled "$1" >/dev/null 2>&1
}

