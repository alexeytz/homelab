#!/usr/bin/env bash

set -euo pipefail

err() {
    echo "ERROR: $1" >&2
    exit 1
}

# Verify the Xray configuration file
CONFIG="/usr/local/etc/xray/config.json"
[[ -r "$CONFIG" ]] || err "Config file '$CONFIG' missing or unreadable."

# Pull the e‑mail list into array
emails=($(jq -r '.inbounds[0].settings.clients[].email' "$CONFIG"))

# If no elemets in array
if [[ ${#emails[@]} -eq 0 ]]; then
    echo "No users detected in $CONFIG."
    exit 1
fi

# Print the user list
echo "User list:"
for idx in "${!emails[@]}"; do
    printf "%d. %s\n" $((idx + 1)) "${emails[idx]}"
done