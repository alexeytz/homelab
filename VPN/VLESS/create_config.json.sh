#!/usr/bin/env bash

error() {
   echo "ERROR: $1" >&2
   exit 1
}

set -euo pipefail

ENV_FILE="${HOME}/xray/xray.env"
[[ -r "$ENV_FILE" ]] || error "Environment file '$ENV_FILE' not found or unreadable."
source "$ENV_FILE"

uuid=$(xray uuid)

# Copy the template – make sure the source file exists.
TEMPLATE="./config-template.json"
TARGET="${HOME}/xray/config.json"

[[ -r "$TEMPLATE" ]] || error "Template file '$TEMPLATE' not found or unreadable."

cp "$TEMPLATE" "$TARGET" || error "Failed to copy template to '$TARGET'."

# In‑place substitutions
sed -i "s|\"id\": \"REPLACE-UUID\"|\"id\": \"${uuid}\"|g" "$TARGET"
sed -i "s|\"name\": \"REPLACE-DOMAIN\"|\"name\": \"${domain}\"|g" "$TARGET"
sed -i "s|\"dest\": \"REPLACE-IP:REPLACE-PORT\"|\"dest\": \"${proxy_ip}:${proxy_port}\"|g" "$TARGET"
sed -i "s|\"certificateFile\": \"REPLACE-CERTIFICATE\"|\"certificateFile\": \"${certificate}\"|g" "$TARGET"
sed -i "s|\"keyFile\": \"REPLACE-KEYFILE\"|\"keyFile\": \"${keyfile}\"|g" "$TARGET"

echo "Configuration file '$TARGET' has been successfully generated."
