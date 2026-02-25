#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

CONFIG="/usr/local/etc/xray/config.json"

err() {
   printf '%s\n' "$*" >&2
   exit 1
}

# Pull all client e‑mails into an array
#emails=($(jq -r '.inbounds[0].settings.clients[].email' "$CONFIG"))
# For bash 4.4+, must not be in posix mode, may use temporary files
mapfile -t emails < <(jq -r '.inbounds[0].settings.clients[].email' "$CONFIG")

# Show a numbered list
echo "Registered users:"
for i in "${!emails[@]}"; do
   printf '  %d) %s\n' $((i + 1)) "${emails[$i]}"
done

# Ask for a selection and validate it
read -rp 'Enter user ID from the list above: ' uid

# Check that uid is a positive integer in range
if ! [[ "$uid" =~ ^[0-9]+$ ]] || ((uid < 1 || uid > ${#emails[@]})); then
   err "Error, number range must be within 1 to ${#emails[@]}"
   exit 1
fi

# Convert to 0‑based index
idx=$((uid - 1))
email="${emails[$idx]}"

# Retrieve the needed fields from the JSON
#   The `index` here is the array index of the client
index=$(
   jq --arg email "$email" '
        .inbounds[0].settings.clients
        | to_entries[]
        | select(.value.email == $email)
        | .key' "$CONFIG"
)

protocol=$(jq -r '.inbounds[0].protocol' "$CONFIG")
port=$(jq -r '.inbounds[0].port' "$CONFIG")
uuid=$(jq -r ".inbounds[0].settings.clients[${index}].id" "$CONFIG")
fp=$(jq -r '.inbounds[0].streamSettings.tlsSettings.fingerprint' "$CONFIG")
domain=$(jq -r '.customization.addr' "$CONFIG")

# Build the final URL
link="${protocol}://${uuid}@${domain}:${port}?security=tls&alpn=http%2F1.1&fp=${fp}&spx=/&type=tcp&flow=xtls-rprx-vision&headerType=none&encryption=none#${email}"

printf '\n%s\n\n' "$link"
printf '%s\n' "$link" | qrencode -t ansiutf8
