#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

ROTATION_SCRIPT="/usr/local/sysadmin/ssh/ssh-key-rotation.sh"
INVENTORY_NDJSON="/usr/local/sysadmin/ssh/ssh-inventory.ndjson"
LOG_FILE="/usr/local/sysadmin/logs/linux-user-provision.log"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "$(timestamp) [$1] $2" | tee -a "$LOG_FILE"; }
die() { log "ERROR" "$1"; exit 1; }

usage() {
  echo "Usage: $0 <username>"
  exit 2
}

[[ $EUID -eq 0 ]] || die "Must be run as root"
[[ $# -eq 1 ]] || usage

USERNAME="$1"

if [[ ! "$USERNAME" =~ ^[a-z][a-z0-9._-]{0,31}$ ]]; then
  die "Invalid username: $USERNAME"
fi

[[ -x "$ROTATION_SCRIPT" ]] || die "Rotation script not executable"
getent passwd "$USERNAME" >/dev/null || die "Linux user not found: $USERNAME"

HOSTNAME="$(hostname -f 2>/dev/null || hostname)"

log "INFO" "Generating SSH token for user=$USERNAME host=$HOSTNAME"

# CALL ENGINE
"$ROTATION_SCRIPT" "$USERNAME" || die "SSH key rotation failed"

# Get LAST entry (guaranteed, just written)
LAST="$(tail -n 1 "$INVENTORY_NDJSON")"

PUBLIC_KEY="$(echo "$LAST" | sed -n 's/.*"public_key":"\([^"]*\)".*/\1/p')"
FINGERPRINT="$(echo "$LAST" | sed -n 's/.*"fingerprint":"\([^"]*\)".*/\1/p')"
PRIVATE_KEY="${PUBLIC_KEY%.pub}.pem"

[[ -f "$PRIVATE_KEY" ]] || die "Private key not found: $PRIVATE_KEY"

echo "USERNAME=$USERNAME"
echo "HOSTNAME=$HOSTNAME"
echo "PUBLIC_KEY_PATH=$PUBLIC_KEY"
echo "PRIVATE_KEY_PATH=$PRIVATE_KEY"
echo "FINGERPRINT=$FINGERPRINT"

log "INFO" "SSH token generated for $USERNAME fingerprint=$FINGERPRINT"

exit 0

