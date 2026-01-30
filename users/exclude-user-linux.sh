#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

LOG_FILE="/usr/local/sysadmin/logs/linux-user-provision.log"
SSH_BASE="/usr/local/sysadmin/ssh"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "$(timestamp) [$1] $2" | tee -a "$LOG_FILE"; }
die() { log "ERROR" "$1"; exit 1; }

usage() {
  echo "Usage: $0 <username>"
  exit 2
}

# --------------------------
# Preconditions
# --------------------------
[[ $EUID -eq 0 ]] || die "Must be run as root"
[[ $# -eq 1 ]] || usage

USERNAME="$1"

if [[ ! "$USERNAME" =~ ^[a-z][a-z0-9._-]{0,31}$ ]]; then
  die "Invalid username format: $USERNAME"
fi

USER_DIR="${SSH_BASE}/${USERNAME}"

# --------------------------
# HARD CLEANUP SSH KEYS (BEFORE USERDEL)
# --------------------------
if [[ -d "$USER_DIR" ]]; then
  log "WARN" "Removing ALL SSH keys for user=$USERNAME in $USER_DIR"
  rm -rf "$USER_DIR" || die "Failed to remove SSH key directory: $USER_DIR"
else
  log "WARN" "No SSH key directory found for user=$USERNAME"
fi

# --------------------------
# Linux user removal
# --------------------------
if getent passwd "$USERNAME" >/dev/null 2>&1; then
  log "WARN" "Deleting Linux user and home for user=$USERNAME"
  passwd -l "$USERNAME" >/dev/null 2>&1 || true
  userdel -r "$USERNAME" || die "userdel failed for $USERNAME"
  log "INFO" "Linux user deleted with home: $USERNAME"
else
  log "WARN" "Linux user not found: $USERNAME (keys already cleaned if existed)"
fi

echo "OK user_deleted=$USERNAME keys_removed=yes"
exit 0

