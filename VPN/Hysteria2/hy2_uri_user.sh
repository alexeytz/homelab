#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

CONFIG="/etc/hysteria/config.json"
[[ -r "$CONFIG" ]] || err "Config file '$CONFIG' missing or unreadable."

err() { printf '%s\n' "$*" >&2; exit 1; }


# Pull the current key set
readarray -t keys < <(jq -r '.auth.userpass | keys[]' "$CONFIG")

if (( ${#keys[@]} == 0 )); then
    err "No keys found in \`auth.userpass\` - nothing to delete."
fi

# Show the list
printf '\nCurrent keys in auth.userpass:\n'
for i in "${!keys[@]}"; do
    printf '  %d) %s\n' $((i+1)) "${keys[$i]}"
done
printf '\n'

# Ask which key to remove
read -rp 'Enter user ID to remove: ' uid
if ! [[ "$uid" =~ ^[0-9]+$ ]] || (( uid < 1 || uid > ${#keys[@]} )); then
    err "Invalid ID, must be 1 to ${#keys[@]}"
fi

user="${keys[$((uid-1))]}"
uuid=$(jq -r --arg key "$user" '.auth.userpass[$key]' "$CONFIG")



#protocol=$(jq -r '.inbounds[0].protocol' "$CONFIG")
port=$(jq -r '.listen' "$CONFIG"|awk -F ":" '{print $2}')
domain=$(jq -r '.tls.addr' "$CONFIG")
obfs_password=$(jq -r '.obfs.salamander.password' "$CONFIG")

# Build the final URL
link="hy2://${user}:${uuid}@${domain}:${port}?obfs=salamander&obfs-password=${obfs_password}&sni=${domain}#IPv4"

printf '\n%s\n\n' "$link"
printf '%s\n' "$link" | qrencode -t ansiutf8
