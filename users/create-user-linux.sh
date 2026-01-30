#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

LOG_FILE="/usr/local/sysadmin/logs/linux-user-provision.log"
DEFAULT_GROUP="sudo"
DEFAULT_SHELL="/bin/bash"

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

HOME_DIR="/home/${USERNAME}"

if ! getent passwd "$USERNAME" >/dev/null 2>&1; then
  useradd -m -d "$HOME_DIR" -s "$DEFAULT_SHELL" "$USERNAME" || die "useradd failed"
  log "INFO" "User created: $USERNAME home=$HOME_DIR"
else
  log "WARN" "User already exists: $USERNAME"
fi

usermod -aG "$DEFAULT_GROUP" "$USERNAME" || die "Failed to add to sudo"

passwd -l "$USERNAME" >/dev/null 2>&1 || true

chmod 750 "$HOME_DIR"
chown "$USERNAME:$USERNAME" "$HOME_DIR"

log "INFO" "User $USERNAME added to sudo and password locked"

echo "OK user=$USERNAME"
exit 0

