#!/bin/bash
#-/usr/bin/env bash
# -------------------------------------------------------------
#  • Ensures Vagrant is installed.
#  • Makes sure a Vagrantfile exists (creates a minimal one if needed).
#  • Detects if a VM is already defined for that Vagrantfile.
#  • If a VM is present, checks for an “INIT” snapshot – takes it if absent.
#  • If no VM exists, runs `vagrant up` to create it.
# -------------------------------------------------------------

#set -euo pipefail

# -------------------------------------------------------------
# Configuration
# -------------------------------------------------------------
SNAPSHOT_NAME="INIT"                      # Snapshot that must exist on an existing VM

# -------------------------------------------------------------
# Helper functions
# -------------------------------------------------------------
msg() {
    local level="$1"; shift
    case "$level" in
        info)  echo -e "\e[32m[INFO]\e[0m $*"
               ;;
        warn)  echo -e "\e[33m[WARN]\e[0m $*"
               ;;
        error) echo -e "\e[31m[ERROR]\e[0m $*"
               ;;
        *)     echo "$*"
               ;;
    esac
}

abort() {
    msg error "$1"
    exit 1
}

# -------------------------------------------------------------
# 1. Verify Vagrant is available
# -------------------------------------------------------------
if ! command -v vagrant >/dev/null 2>&1; then
    abort "Vagrant binary not found in PATH. Install Vagrant before running this script."
fi

# -------------------------------------------------------------
# 2. Ensure a Vagrantfile exists
# -------------------------------------------------------------
VAGRANTFILE="Vagrantfile"
if [[ ! -f "$VAGRANTFILE" ]]; then
    abort "Vagrantfile not found. Please create a Vagrantfile before running this script."
fi

# -------------------------------------------------------------
# 3. Detect existing VM
# -------------------------------------------------------------
# machine‑readable output makes it easy to detect a VM’s state
STATUS=$(vagrant status --machine-readable 2>/dev/null || true)
if [[ -z "$STATUS" ]]; then
    abort "Failed to query Vagrant status. Is the Vagrantfile valid?"
fi

# Extract the state, except "not_created" = would trigger VM creation.
VM_STATE=$(echo "$STATUS" | grep -E '^[0-9]+,[[:print:]]+,state,' | tail -1 | cut -d',' -f4 | sed -e 's/[[:cntrl:]]*$//' | grep -v 'not_created')

if [[ -z "$VM_STATE" ]]; then
    # No VM defined – create it
    msg info "No existing VM found. Initializing the environment."
    vagrant up
    msg info "Vagrant environment is now up. 1st."
    msg info "Halting the VM before snapshot..."
    vagrant halt
    msg info "Taking snapshot '$SNAPSHOT_NAME'..."
    vagrant snapshot save "$SNAPSHOT_NAME"
    msg info "Starting the VM after snapshot..."
    vagrant up
    msg info "Vagrant environment is now up. 2nd."
else
    # VM already exists – report its state
    msg info "Existing VM detected. Current state: '$VM_STATE'."
    vagrant status

    # ---------------------------------------------------------
    # 4. Verify that the INIT snapshot exists
    # ---------------------------------------------------------
    msg info "Checking for snapshot '$SNAPSHOT_NAME'."
    # `vagrant snapshot list` prints a header line then the names indented.
    # We grep for the exact name (case‑sensitive) on its own line.
    SNAP_EXISTS=$(vagrant snapshot list 2>/dev/null | grep -E "${SNAPSHOT_NAME}" | tail -1 || true)

    if [[ -z "$SNAP_EXISTS" ]]; then
        msg warn "Snapshot '$SNAPSHOT_NAME' not found. Taking snapshot now."
        msg info "Halting the VM before snapshot..."
        vagrant halt
        msg info "Taking snapshot '$SNAPSHOT_NAME'..."
        vagrant snapshot save "$SNAPSHOT_NAME"
        msg info "Snapshot '$SNAPSHOT_NAME' created."
        msg info "Starting the VM after snapshot..."
        vagrant up
        msg info "Vagrant environment is now up."
    else
        msg info "Snapshot '$SNAPSHOT_NAME' already exists."
    fi
fi

# Final environment status.
msg info "Vagrant status:"
vagrant status
msg info "Environment snapshots:"
vagrant snapshot list

msg info "Script finished successfully."
exit 0