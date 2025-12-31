#!/usr/bin/env bash
# shellcheck shell=bash
# Configure Proxmox API Token

# Create Proxmox API token for automation (Terraform, Ansible)
create_api_token() {
  [[ $INSTALL_API_TOKEN != "yes" ]] && return 0

  log "INFO: Creating Proxmox API token for ${ADMIN_USERNAME}: ${API_TOKEN_NAME}"

  # Note: PAM user and Administrator role are set up in 302-configure-admin.sh

  # Check if token already exists and remove
  local existing
  existing=$(remote_exec "pveum user token list '${ADMIN_USERNAME}@pam' 2>/dev/null | grep -q '${API_TOKEN_NAME}' && echo 'exists' || echo ''")

  if [[ $existing == "exists" ]]; then
    log "WARNING: Token ${API_TOKEN_NAME} exists, removing first"
    remote_exec "pveum user token remove '${ADMIN_USERNAME}@pam' '${API_TOKEN_NAME}'" || {
      log "ERROR: Failed to remove existing token"
      return 1
    }
  fi

  # Create privileged token without expiration using JSON output
  local output
  output=$(remote_exec "pveum user token add '${ADMIN_USERNAME}@pam' '${API_TOKEN_NAME}' --privsep 0 --expire 0 --output-format json 2>&1")

  if [[ -z $output ]]; then
    log "ERROR: Failed to create API token - empty output"
    return 1
  fi

  # Extract token value from JSON output, skipping any non-JSON lines (perl warnings, etc.)
  # jq's try/fromjson handles invalid JSON gracefully
  local token_value
  token_value=$(printf '%s\n' "$output" | jq -R 'try (fromjson | .value) // empty' 2>/dev/null | grep -v '^$' | head -1)

  if [[ -z $token_value ]]; then
    log "ERROR: Failed to extract token value from pveum output"
    log "DEBUG: pveum output: $output"
    return 1
  fi

  # Store for final display
  API_TOKEN_VALUE="$token_value"
  API_TOKEN_ID="${ADMIN_USERNAME}@pam!${API_TOKEN_NAME}"

  # Save to temp file for display after installation (restricted permissions)
  # Uses centralized path constant from 003-init.sh, registered for cleanup
  (
    umask 0077
    cat >"$_TEMP_API_TOKEN_FILE" <<EOF
API_TOKEN_VALUE=$token_value
API_TOKEN_ID=$API_TOKEN_ID
API_TOKEN_NAME=$API_TOKEN_NAME
EOF
  )
  register_temp_file "$_TEMP_API_TOKEN_FILE"

  log "INFO: API token created successfully: ${API_TOKEN_ID}"
  return 0
}
