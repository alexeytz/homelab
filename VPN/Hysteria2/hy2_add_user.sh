#!/usr/bin/env bash

set -euo pipefail

err() {
   echo "ERROR: $1" >&2
   exit 1
}

CONFIG="/etc/hysteria/config.json"
[[ -r "$CONFIG" ]] || err "Config file '$CONFIG' missing or unreadable."

# Ask for a key name (the “user” field you want to add)
read -rp "New user key (no spaces): " user
# Strip whitespace – we only allow a simple alphanumeric key
user=${user//[[:space:]]/}
[[ -z "$user" ]] && { err "Invalid user key - cannot be empty"; }

# Make sure the key does not already exist in auth.userpass
if jq -e --arg k "$user" '.auth.userpass | has($k)' "$CONFIG" >/dev/null; then
   err "User '$user' already exists in the config"
fi

# Create a fresh UUID
uuid=$(openssl rand -hex 32)
echo "Generated UUID: $uuid"

# Insert the new key/value pair
jq --arg k "$user" --arg v "$uuid" '
    .auth.userpass[$k] = $v
' "$CONFIG" >"$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

# Give the config readable permissions (so hysteria-server can read it)
chmod +r "$CONFIG"

# Restart the hysteria-server service
if ! systemctl restart xrhysteria-serveray; then
   err "Failed to restart hysteria-server service"
fi

port=$(jq -r '.listen' "$CONFIG" | awk -F ":" '{print $2}')
domain=$(jq -r '.customization.addr' "$CONFIG")
obfs_password=$(jq -r '.obfs.salamander.password' "$CONFIG")

# Build the final URL
link="hy2://${user}:${uuid}@${domain}:${port}?obfs=salamander&obfs-password=${obfs_password}&sni=${domain}#IPv4"

printf '\n%s\n\n' "$link"
printf '%s\n' "$link" | qrencode -t ansiutf8
