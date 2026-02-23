#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

CONFIG="/usr/local/etc/xray/config.json"
ENV_FILE="${HOME}/xray/xray.env"

# Helper: error + exit
err() { printf '%s\n' "$*" >&2; exit 1; }

[[ -r "$ENV_FILE" ]] || err "Env file '$ENV_FILE' missing or unreadable."
source "$ENV_FILE"

# Pull all client e‑mails into an array
emails=($(jq -r '.inbounds[0].settings.clients[].email' "$CONFIG"))
if (( ${#emails[@]} == 0 )); then
    err "No clients found in $CONFIG"
fi

# Show the list to the operator
printf 'Client list:\n'
for i in "${!emails[@]}"; do
    printf '  %d) %s\n' $((i+1)) "${emails[$i]}"
done

# Ask for an ID and validate it
read -rp 'Enter client ID to remove: ' uid
if ! [[ "$uid" =~ ^[0-9]+$ ]] || (( uid < 1 || uid > ${#emails[@]} )); then
    err "Invalid ID, must be 1 to ${#emails[@]}"
fi

email="${emails[$((uid-1))]}"

# Make a backup (you can comment out the next line if you don’t want it)
cp -- "$CONFIG" "${CONFIG}.bak.$(date +%s)" || err "Failed to create config backup"

# Edit the config atomically (mktemp → jq → mv)
tmp=$(mktemp) || err "Failed to create temporary file"

jq --arg email "$email" '
  .inbounds[0].settings.clients |= map(select(.email != $email))
' "$CONFIG" >"$tmp" || err "jq failed to edit config"

# Make sure the client was actually removed
if jq -e --arg email "$email" '.inbounds[0].settings.clients[] | select(.email == $email)' "$tmp" >/dev/null; then
    err "Failed to remove client $email"
fi

mv -f "$tmp" "$CONFIG" || err "Failed to write updated config"

# Restart the Xray service
if ! systemctl restart xray; then
    err "Failed to restart xray service"
fi

printf 'User %s removed from configuration.\n' "$email"
