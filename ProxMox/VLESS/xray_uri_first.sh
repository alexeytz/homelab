#!/usr/bin/env bash
set -euo pipefail

error() { echo "ERROR: $1" >&2; exit 1; }

ENV_FILE="${HOME}/xray/xray.env"
[[ -r "$ENV_FILE" ]] || error "Env file '$ENV_FILE' missing or unreadable."
source "$ENV_FILE"

# Make sure the vars we need are present
: "${uuid:?Missing UUID}"
: "${domain:?Missing DOMAIN}"

CONFIG="/usr/local/etc/xray/config.json"
[[ -r "$CONFIG" ]] || error "Xray config '$CONFIG' missing or unreadable."

protocol=$(jq -r '.inbounds[0].protocol' "$CONFIG") || error "Could not parse protocol"
port=$(jq -r '.inbounds[0].port' "$CONFIG") || error "Could not parse port"
fp=$(jq -r '.inbounds[0].streamSettings.tlsSettings.fingerprint' "$CONFIG") || error "Could not parse fingerprint"

link="$protocol://$uuid@${domain}:$port?security=tls&alpn=http%2F1.1&fp=$fp&spx=/&type=tcp&flow=xtls-rprx-vision&headerType=none&encryption=none#first"

printf "\n%s\n\n" "$link"
printf "%s\n" "$link" | qrencode -t ansiutf8