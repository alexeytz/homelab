#!/usr/bin/env bash

error() {
   echo "ERROR: $1" >&2
   exit 1
}

set -euo pipefail

ENV_FILE="${HOME}/hy2/hy2.env"
[[ -r "$ENV_FILE" ]] || error "Environment file '$ENV_FILE' not found or unreadable."
# shellcheck disable=SC1090
source "$ENV_FILE"

uuid=$(openssl rand -hex 32)
obfs_password=$(openssl rand -hex 16)

# Copy the template – make sure the source file exists.
TEMPLATE="./self_managed_certs-config-template.json"
TARGET="${HOME}/hy2/config.json"

[[ -r "$TEMPLATE" ]] || error "Template file '$TEMPLATE' not found or unreadable."

cp "$TEMPLATE" "$TARGET" || error "Failed to copy template to '$TARGET'."

# In‑place substitutions
sed -i "s|\"pioneer\": \"REPLACE-UUID\"|\"pioneer\": \"${uuid}\"|g" "$TARGET"
# shellcheck disable=SC2154
sed -i "s|\"addr\": \"REPLACE-DOMAIN\"|\"addr\": \"${domain}\"|g" "$TARGET"
# shellcheck disable=SC2154
sed -i "s|\"cert\": \"REPLACE-CERTIFICATE\"|\"cert\": \"${certificate}\"|g" "$TARGET"
# shellcheck disable=SC2154
sed -i "s|\"key\": \"REPLACE-KEYFILE\"|\"key\": \"${keyfile}\"|g" "$TARGET"
sed -i "s|\"password\": \"REPLACE-PASSWORD\"|\"password\": \"${obfs_password}\"|g" "$TARGET"
# shellcheck disable=SC2154
sed -i "s|\"listen\": \":REPLACE-PORT\"|\"listen\": \":${hy2_port}\"|g" "$TARGET"
# shellcheck disable=SC2154
sed -i "s|\"bindDevice\": \"REPLACE-IFACE\"|\"bindDevice\": \"${bind_device}\"|g" "$TARGET"

echo "Configuration file '$TARGET' has been successfully generated."
