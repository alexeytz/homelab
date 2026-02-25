#!/usr/bin/env bash

set -euo pipefail

CONFIG="/usr/local/etc/xray/config.json"

# Get the email (no spaces, no empty string)
read -rp "New user (no spaces): " email
# Remove spaces
email=${email//[[:space:]]/}
[[ -z "$email" ]] && {
   echo "Invalid username"
   exit 1
} || { echo "Proceeding with user: $email"; }

# Make sure the user doesn’t already exist
if jq -e --arg e "$email" '.inbounds[0].settings.clients[] | select(.email==$e)' "$CONFIG" >/dev/null; then
   echo "User '$email' already exists"
   exit 1
fi

# Create a fresh UUID for the client
uuid=$(xray uuid)

# Append the new client to the config (atomic write)
client=$(jq -n \
   --arg e "$email" \
   --arg u "$uuid" \
   '{email:$e, id:$u, flow:"xtls-rprx-vision", "level":0}')

jq --argjson c "$client" \
   '.inbounds[0].settings.clients += [$c]' "$CONFIG" >"$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

chmod +r /usr/local/etc/xray/config.json

# Restart the Xray service
if ! systemctl restart xray; then
   err "Failed to restart xray service"
fi

# Build the connection link
protocol=$(jq -r '.inbounds[0].protocol' "$CONFIG")
port=$(jq -r '.inbounds[0].port' "$CONFIG")
fp=$(jq -r '.inbounds[0].streamSettings.tlsSettings.fingerprint' "$CONFIG")
domain=$(jq -r '.customization.addr' "$CONFIG")

link="${protocol}://${uuid}@${domain}:${port}?security=tls&alpn=http%2F1.1&fp=${fp}&spx=/&type=tcp&flow=xtls-rprx-vision&headerType=none&encryption=none#${email}"

printf "\n%s\n\n" "$link"
printf "%s\n" "$link" | qrencode -t ansiutf8
