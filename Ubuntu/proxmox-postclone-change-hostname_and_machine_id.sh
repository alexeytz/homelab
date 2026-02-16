#!/usr/bin/env bash
#
# change-hostname.sh – Safely change the hostname on Ubuntu 24.04 (and newer).
#
# Usage:
#   sudo ./change-hostname.sh NEW_HOSTNAME
#
# This script:
#   • Validates input.
#   • Backs up /etc/hostname and /etc/hosts.
#   • Sets the new hostname via hostnamectl.
#   • Rewrites the loopback line in /etc/hosts.
#   • Prints a short summary and exits.
#
# Note:
#   • The new hostname must obey the hostname rules (RFC 1123 – only letters, digits, and hyphens; cannot start or end with a hyphen).
#   • The system will need a reboot to pick it up.

set -euo pipefail

#########################
# Helper functions
#########################
log() { printf '%s\n' "$*"; }
error() { printf '%s\n' "$*" >&2; }

# Validate the hostname according to RFC 1123
valid_hostname() {
    local host="$1"
    # Allowed: a-z, A-Z, 0-9, hyphen; cannot start/end with hyphen; length 1-63
    [[ "$host" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]
}

#########################
# Main script
#########################

# 1. Verify we are root
if [[ $EUID -ne 0 ]]; then
    error "ERROR: This script must be run as root (or with sudo)."
    exit 1
fi

# 2. Parse and validate arguments
if [[ $# -ne 1 ]]; then
    error "Usage: $0 NEW_HOSTNAME"
    exit 1
fi

NEW_HOSTNAME="$1"

if ! valid_hostname "$NEW_HOSTNAME"; then
    error "ERROR: '$NEW_HOSTNAME' is not a valid hostname."
    error "Hostname must contain only letters, digits, and hyphens, "
    error "cannot start or end with a hyphen, and be <= 63 characters."
    exit 1
fi

# 3. Grab the current hostname for reference
CURRENT_HOSTNAME="$(hostname)"

# 4. Backup files
BACKUP_DIR="/var/backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
HOSTNAME_BACKUP="$BACKUP_DIR/hostname.$TIMESTAMP.bak"
HOSTS_BACKUP="$BACKUP_DIR/hosts.$TIMESTAMP.bak"

cp /etc/hostname "$HOSTNAME_BACKUP"
cp /etc/hosts "$HOSTS_BACKUP"

log "Backed up /etc/hostname to $HOSTNAME_BACKUP"
log "Backed up /etc/hosts  to $HOSTS_BACKUP"

# 5. Set the new hostname via hostnamectl
log "Setting hostname to '$NEW_HOSTNAME' ..."
hostnamectl set-hostname "$NEW_HOSTNAME"

# 6. Regenerate the system machine ID
log "Regenerating machine ID..."
CURRENT_MACH_ID=$(cat /etc/machine-id)
rm -f /etc/machine-id /var/lib/dbus/machine-id
dbus-uuidgen --ensure=/etc/machine-id
dbus-uuidgen --ensure
NEW_MACH_ID=$(cat /etc/machine-id)

# 7. Update /etc/hosts – replace the loopback entry
#    We look for a line that starts with 127.0.1.1 (Ubuntu default) and replace the hostname.
#    If such a line does not exist, we append a new one at the end.
log "Updating /etc/hosts ..."
if grep -qE '^127\.0\.1\.1[[:space:]]+' /etc/hosts; then
    # Replace the hostname in that line
    sed -i "s|^127\.0\.1\.1[[:space:]]\+$CURRENT_HOSTNAME|127.0.1.1\t$NEW_HOSTNAME|g" /etc/hosts
else
    # Append a new loopback entry
    echo -e "127.0.1.1\t$NEW_HOSTNAME" >> /etc/hosts
fi

# 8. Summary
log ""
log "Hostname successfully changed:"
log "   Old hostname: $CURRENT_HOSTNAME"
log "   New hostname: $NEW_HOSTNAME"
log "   Old /etc/machine-id: $CURRENT_MACH_ID"
log "   New /etc/machine-id: $NEW_MACH_ID"
log ""
log "Machine ID regenerated and stored in /etc/machine-id and /var/lib/dbus/machine-id."
log "Please reboot or log out/in to make sure all services pick up the new name."