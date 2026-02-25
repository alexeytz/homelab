#!/usr/bin/env bash

set -euo pipefail

err() {
   echo "ERROR: $1" >&2
   exit 1
}

# Verify the Xray configuration file
CONFIG="/etc/hysteria/config.json"
[[ -r "$CONFIG" ]] || err "Config file '$CONFIG' missing or unreadable."

# Pull the e‑mail list into array
#userpass_key=($(jq -r '.auth.userpass | keys[]' "$CONFIG"))
# For bash 4.4+, must not be in posix mode, may use temporary files
mapfile -t userpass_key < <(jq -r '.auth.userpass | keys[]' "$CONFIG")

# If no elemets in array
if [[ ${#userpass_key[@]} -eq 0 ]]; then
   err "No users detected in $CONFIG."
fi

# Print the user list
echo "User list:"
for idx in "${!userpass_key[@]}"; do
   printf "%d. %s\n" $((idx + 1)) "${userpass_key[idx]}"
done
