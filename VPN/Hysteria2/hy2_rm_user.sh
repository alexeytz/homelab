#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

CONFIG="/etc/hysteria/config.json"
[[ -r "$CONFIG" ]] || err "Config file '$CONFIG' missing or unreadable."

err() {
   printf '%s\n' "$*" >&2
   exit 1
}

# Pull the current key set
readarray -t keys < <(jq -r '.auth.userpass | keys[]' "$CONFIG")

if ((${#keys[@]} == 0)); then
   err "No keys found in \`auth.userpass\` - nothing to delete."
fi

# Show the list
printf '\nCurrent keys in auth.userpass:\n'
for i in "${!keys[@]}"; do
   printf '  %d) %s\n' $((i + 1)) "${keys[$i]}"
done
printf '\n'

# Ask which key to remove
read -rp 'Enter user ID to remove: ' uid
if ! [[ "$uid" =~ ^[0-9]+$ ]] || ((uid < 1 || uid > ${#keys[@]})); then
   err "Invalid ID, must be 1 to ${#keys[@]}"
fi

delkey="${keys[$((uid - 1))]}"

# Backup the current config
cp "$CONFIG" "${CONFIG}.bak.$(date +%s)" || err "Backup failed."

# Remove the key atomically
tmp=$(mktemp) || err "Could not create temp file."

jq --arg k "$delkey" '
    # Delete the chosen key from the userpass object
    .auth.userpass |= del(.[$k])
' "$CONFIG" >"$tmp" || err "jq failed to edit config."

# Verify deletion – the key must no longer exist
if jq -e --arg k "$delkey" '.auth.userpass | has($k)' "$tmp" >/dev/null; then
   err "Failed to remove key \"$delkey\" from config."
fi

# Apply the new file
mv -f "$tmp" "$CONFIG" || err "Could not write updated config."

# Make config readable
chmod +r "$CONFIG"

# Restart the hysteria-server service
if ! systemctl restart xrhysteria-serveray; then
   err "Failed to restart hysteria-server service"
fi

printf '\n Key "%s" removed from auth.userpass.\n' "$delkey"
printf 'A backup of the previous config was written to %s.bak.*\n' "$CONFIG"
