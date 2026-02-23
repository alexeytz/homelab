#!/usr/bin/env bash

# -------------------------------------------------------------
# 1. Helper: print a message and exit with a non‑zero status.
# -------------------------------------------------------------
error() {
    echo "ERROR: $1" >&2
    exit 1
}

# -------------------------------------------------------------
# 2. Make the script fail on any command that returns >0.
# -------------------------------------------------------------
set -euo pipefail

# -------------------------------------------------------------
# 3.  Load environment file – make sure it exists first.``
# -------------------------------------------------------------
ENV_FILE="${HOME}/xray/xray.env"
[[ -r "$ENV_FILE" ]] || error "Environment file '$ENV_FILE' not found or unreadable."
source "$ENV_FILE"

# -------------------------------------------------------------
# 4.  Verify that the required variables are defined and non‑empty.
# -------------------------------------------------------------
: "${uuid:?Missing environment variable 'uuid'}"
: "${domain:?Missing environment variable 'domain'}"
: "${proxy_ip:?Missing environment variable 'proxy_ip'}"
: "${proxy_port:?Missing environment variable 'proxy_port'}"
: "${certificate:?Missing environment variable 'certificate'}"
: "${keyfile:?Missing environment variable 'keyfile'}"

# -------------------------------------------------------------
# 5.  Copy the template – make sure the source file exists.
# -------------------------------------------------------------
TEMPLATE="./config-template.json"
TARGET="${HOME}/xray/config.json"

[[ -r "$TEMPLATE" ]] || error "Template file '$TEMPLATE' not found or unreadable."

cp "$TEMPLATE" "$TARGET" || error "Failed to copy template to '$TARGET'."

# -------------------------------------------------------------
# 6.  In‑place substitutions – use -i to edit the file directly.
#     We redirect sed's stderr to /dev/null because it will
#     otherwise complain about the file not being opened for
#     reading/writing when using -i without a backup extension.
# -------------------------------------------------------------
sed -i "s|\"id\": \"REPLACE-UUID\"|\"id\": \"${uuid}\"|g" "$TARGET"
sed -i "s|\"name\": \"REPLACE-DOMAIN\"|\"name\": \"${domain}\"|g" "$TARGET"
sed -i "s|\"dest\": \"REPLACE-IP:REPLACE-PORT\"|\"dest\": \"${proxy_ip}:${proxy_port}\"|g" "$TARGET"
sed -i "s|\"certificateFile\": \"REPLACE-CERTIFICATE\"|\"certificateFile\": \"${certificate}\"|g" "$TARGET"
sed -i "s|\"keyFile\": \"REPLACE-KEYFILE\"|\"keyFile\": \"${keyfile}\"|g" "$TARGET"

# -------------------------------------------------------------
# 7.  Final sanity check – did the file actually get updated?
# -------------------------------------------------------------
if ! grep -q "\"id\": \"$uuid\"" "$TARGET"; then
    error "Placeholder 'REPLACE-UUID' was not replaced. Did you pass the right UUID?"
fi

echo "Configuration file '$TARGET' has been successfully generated."