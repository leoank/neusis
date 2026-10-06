#!/usr/bin/env bash
set -euo pipefail

# Force claim hostname for the current Tailscale device
# This script ensures the current device gets the exact hostname without suffix by:
# 1. Checking if the DNS name already matches exactly (exits if it does)
# 2. Renaming any conflicting devices to hostname-old-<timestamp>
# 3. Setting the current device to the exact desired hostname
# This preserves all devices (nothing gets deleted) while ensuring the current device gets the exact name.
# Required environment variables:
# - TS_CLIENT_ID_FILE: Path to file containing OAuth client ID
# - TS_CLIENT_SECRET_FILE: Path to file containing OAuth client secret
# - TAILNET_ORG: Tailnet organization name
# - NODE_NAME: Desired hostname for this device

log() {
    echo "[tailscale-force-claim] $1" >&2
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

# Verify required environment variables
[ -z "${TS_CLIENT_ID_FILE:-}" ] && error_exit "TS_CLIENT_ID_FILE not set"
[ -z "${TS_CLIENT_SECRET_FILE:-}" ] && error_exit "TS_CLIENT_SECRET_FILE not set"
[ -z "${TAILNET_ORG:-}" ] && error_exit "TAILNET_ORG not set"
[ -z "${NODE_NAME:-}" ] && error_exit "NODE_NAME not set"
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

# Get current device info from local status
log "Getting current device information..."
STATUS=$(tailscale status --json 2>/dev/null) || error_exit "Failed to get tailscale status"
DEVICE_ID=$(echo "$STATUS" | jq -r '.Self.ID')
CURRENT_HOSTNAME=$(echo "$STATUS" | jq -r '.Self.HostName')
CURRENT_DNSNAME=$(echo "$STATUS" | jq -r '.Self.DNSName // ""')

if [ -z "$DEVICE_ID" ] || [ "$DEVICE_ID" = "null" ]; then
    error_exit "Could not get device ID from tailscale status"
fi

log "Device ID: $DEVICE_ID"
log "Current hostname: $CURRENT_HOSTNAME"
log "Current DNS name: $CURRENT_DNSNAME"
log "Desired hostname: $NODE_NAME"

# Check if DNS name matches exactly what we want (no -1, -2, etc suffix)
CURRENT_DNS_SHORT=$(echo "$CURRENT_DNSNAME" | cut -d'.' -f1)
DESIRED_DNS_SHORT=$(echo "$NODE_NAME" | tr '[:upper:]' '[:lower:]')

if [ "$CURRENT_DNS_SHORT" = "$DESIRED_DNS_SHORT" ]; then
    log "Device already has exact DNS name: $CURRENT_DNS_SHORT"
    exit 0
fi

log "Current DNS name '$CURRENT_DNS_SHORT' != desired '$DESIRED_DNS_SHORT' - will force claim"

# Get OAuth token
log "Obtaining OAuth token..."
OAUTH_RESPONSE=$(curl -sf -X POST https://api.tailscale.com/api/v2/oauth/token \
    -d "client_id=$(cat "$TS_CLIENT_ID_FILE")" \
    -d "client_secret=$(cat "$TS_CLIENT_SECRET_FILE")" 2>/dev/null) || error_exit "Failed to obtain OAuth token"

TOKEN=$(echo "$OAUTH_RESPONSE" | jq -r '.access_token')
if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    log "OAuth response: $OAUTH_RESPONSE"
    error_exit "Failed to extract access token from OAuth response"
fi
log "Successfully obtained OAuth token"

# Handle conflicting devices by renaming them
log "Checking for hostname conflicts..."
DEVICES_RESPONSE=$(curl -sf "https://api.tailscale.com/api/v2/tailnet/$TAILNET_ORG/devices" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null) || error_exit "Failed to fetch device list"

if [ -n "${DEVICES_RESPONSE:-}" ]; then
    # Find devices where the name (without domain) matches our desired hostname
    # but has a different node ID
    CONFLICTS=$(echo "$DEVICES_RESPONSE" | jq -r \
        --arg hostname "$NODE_NAME" \
        --arg device_id "$DEVICE_ID" \
        '.devices[]? | select(.name | split(".")[0] | ascii_downcase == ($hostname | ascii_downcase)) | select(.nodeId != $device_id) | {id: .nodeId, name: .name, hostname: .hostname}' 2>/dev/null | jq -s '.')

    CONFLICT_COUNT=$(echo "$CONFLICTS" | jq 'length')

    if [ "$CONFLICT_COUNT" -gt 0 ]; then
        log "Found $CONFLICT_COUNT device(s) with exact name '$DESIRED_DNS_SHORT'. Renaming them to preserve them..."

        # Use Unix timestamp for unique suffix (no collisions)
        TIMESTAMP=$(date +%s)

        # Rename each conflicting device
        echo "$CONFLICTS" | jq -r '.[]? | .id' | while read -r conflict_id; do
            if [ -n "$conflict_id" ]; then
                # Create unique name with timestamp
                NEW_NAME="${DESIRED_DNS_SHORT}-old-${TIMESTAMP}"

                log "  Renaming device $conflict_id to '$NEW_NAME'..."
                curl -sf -X POST "https://api.tailscale.com/api/v2/device/$conflict_id/name" \
                    -H "Authorization: Bearer $TOKEN" \
                    -H "Content-Type: application/json" \
                    -d "{\"name\": \"$NEW_NAME\"}" >/dev/null 2>&1 || log "    Warning: Failed to rename device $conflict_id"

                # Increment timestamp to ensure uniqueness if multiple conflicts
                TIMESTAMP=$((TIMESTAMP + 1))
            fi
        done

        # Give the API a moment to process the renames
        sleep 2
    else
        log "No conflicting devices found"
    fi
fi

# Set device hostname (this sets the exact name without suffix)
log "Setting current device (ID: $DEVICE_ID) to exact hostname: $NODE_NAME"
RENAME_RESPONSE=$(curl -sf -X POST "https://api.tailscale.com/api/v2/device/$DEVICE_ID/name" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$NODE_NAME\"}" 2>&1) || error_exit "Failed to set device hostname: $RENAME_RESPONSE"

log "Successfully forced claim of hostname '$NODE_NAME' for device $DEVICE_ID"