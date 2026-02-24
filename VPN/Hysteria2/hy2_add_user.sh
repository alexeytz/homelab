#!/usr/bin/env bash

set -euo pipefail

# Paths – adjust if your installation uses different locations
CONFIG="/etc/hysteria/config.json"

# Ask for a key name (the “user” field you want to add)
read -rp "New user key (no spaces): " user
# Strip whitespace – we only allow a simple alphanumeric key
user=${user//[[:space:]]/}
[[ -z "$user" ]] && { echo "Invalid user key – cannot be empty"; exit 1; }

# Make sure the key does not already exist in auth.userpass
if jq -e --arg k "$user" '.auth.userpass | has($k)' "$CONFIG" >/dev/null; then
    echo "User '$user' already exists in the config"
    exit 1
fi

# Create a fresh UUID
uuid=$(openssl rand -hex 32)
echo "Generated UUID: $uuid"

# Insert the new key/value pair atomically
#  .auth.userpass[$user] = $uuid   ← adds/updates the key
jq --arg k "$user" --arg v "$uuid" '
    .auth.userpass[$k] = $v
' "$CONFIG" >"$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

# Give the config readable permissions (so hysteria-server can read it)
chmod +r "$CONFIG"

# Restart hysteria-server so the change takes effect
systemctl restart hysteria-server && sleep 1 && systemctl status hysteria-server

echo
echo "Added new user '$user' with ID $uuid"
echo "Config written to $CONFIG"
echo "hysteria-server has been restarted."