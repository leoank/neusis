#!/usr/bin/env bash
set -euo pipefail

# Disable key expiry for the current Tailscale device
# Required environment variables:
# - TS_CLIENT_ID_FILE: Path to file containing OAuth client ID
# - TS_CLIENT_SECRET_FILE: Path to file containing OAuth client secret

log() {
    echo "[tailscale-disable-key-expiry] $1" >&2
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

# Verify required environment variables
[ -z "${TS_CLIENT_ID_FILE:-}" ] && error_exit "TS_CLIENT_ID_FILE not set"
[ -z "${TS_CLIENT_SECRET_FILE:-}" ] && error_exit "TS_CLIENT_SECRET_FILE not set"
[ ! -f "$TS_CLIENT_ID_FILE" ] && error_exit "Client ID file not found: $TS_CLIENT_ID_FILE"
[ ! -f "$TS_CLIENT_SECRET_FILE" ] && error_exit "Client secret file not found: $TS_CLIENT_SECRET_FILE"

# Wait for Tailscale connection
log "Waiting for Tailscale connection..."
for i in {1..30}; do
    if tailscale status --json 2>/dev/null | jq -e '.BackendState == "Running" and .Self.ID != null' >/dev/null 2>&1; then
        log "Tailscale connected"
        break
    fi
    if [ $i -eq 30 ]; then
        error_exit "Tailscale did not connect after 150 seconds"
    fi
    log "Tailscale not ready, waiting... (attempt $i/30)"
    sleep 5
done

# Get device ID from local status
log "Getting device information..."
DEVICE_ID=$(tailscale status --json 2>/dev/null | jq -r '.Self.ID')
if [ -z "$DEVICE_ID" ] || [ "$DEVICE_ID" = "null" ]; then
    error_exit "Could not get device ID from tailscale status"
fi
log "Device ID: $DEVICE_ID"

# Get an API token: the client secret itself when it is an API access token
# (tskey-api-…), otherwise an OAuth token for the client id + secret.
[ -r "$TS_CLIENT_ID_FILE" ] && [ -r "$TS_CLIENT_SECRET_FILE" ] || error_exit "Cannot read the API credential files (run as root)"
CLIENT_SECRET=$(cat "$TS_CLIENT_SECRET_FILE")
if [[ "$CLIENT_SECRET" == tskey-api-* ]]; then
    log "Using the API access token"
    TOKEN=$CLIENT_SECRET
else
    log "Obtaining OAuth token..."
    OAUTH_RESPONSE=$(curl -s -w '\n%{http_code}' -X POST https://api.tailscale.com/api/v2/oauth/token \
        -d "client_id=$(cat "$TS_CLIENT_ID_FILE")" \
        -d "client_secret=$CLIENT_SECRET" 2>/dev/null) || error_exit "Could not reach the Tailscale OAuth endpoint"
    OAUTH_STATUS=${OAUTH_RESPONSE##*$'\n'}
    OAUTH_RESPONSE=${OAUTH_RESPONSE%$'\n'*}
    # The refusal names what is wrong (e.g. an unknown client) and never echoes the secret.
    [ "$OAUTH_STATUS" = 200 ] || error_exit "OAuth token refused (HTTP $OAUTH_STATUS): $(echo "$OAUTH_RESPONSE" | jq -r '.message // .error_description // .error // .' 2>/dev/null | head -c 300)"

    TOKEN=$(echo "$OAUTH_RESPONSE" | jq -r '.access_token')
    if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        error_exit "No access token in the OAuth response"
    fi
    log "Successfully obtained OAuth token"
fi
unset CLIENT_SECRET

# Check current key expiry status
log "Checking current key expiry status..."
DEVICE_INFO=$(curl -sf "https://api.tailscale.com/api/v2/device/$DEVICE_ID" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null) || error_exit "Failed to get device info from API"

KEY_EXPIRY_DISABLED=$(echo "$DEVICE_INFO" | jq -r '.keyExpiryDisabled')
if [ "$KEY_EXPIRY_DISABLED" = "true" ]; then
    log "Key expiry is already disabled for this device"
    exit 0
fi

# Disable key expiry
log "Disabling key expiry for device..."
curl -sf -X POST "https://api.tailscale.com/api/v2/device/$DEVICE_ID/key" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"keyExpiryDisabled": true}' >/dev/null 2>&1 || error_exit "Failed to disable key expiry"

log "Successfully disabled key expiry for device $DEVICE_ID"