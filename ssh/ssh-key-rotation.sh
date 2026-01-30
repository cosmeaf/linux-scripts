#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

# ==============================
# SYSADMIN SSH KEY ENGINE
# UUID PER KEY (ENTERPRISE)
# ==============================

BASE_DIR="/usr/local/sysadmin/ssh"
LOG_FILE="/usr/local/sysadmin/logs/ssh-key-rotation.log"
INVENTORY_CSV="${BASE_DIR}/ssh-inventory.csv"
INVENTORY_NDJSON="${BASE_DIR}/ssh-inventory.ndjson"

KEY_TYPE="rsa"
KEY_BITS="4096"
KEY_COMMENT="sysadmin-ssh"

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

command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen not found"
command -v uuidgen   >/dev/null 2>&1 || die "uuidgen not found"
getent passwd "$USERNAME" >/dev/null || die "Linux user not found: $USERNAME"

# --------------------------
# Directory setup
# --------------------------
USER_DIR="${BASE_DIR}/${USERNAME}"

mkdir -p "$BASE_DIR" || die "Failed to create BASE_DIR"
mkdir -p "$USER_DIR" || die "Failed to create USER_DIR: $USER_DIR"
chmod 700 "$USER_DIR" || die "Failed to chmod USER_DIR"

[[ -w "$USER_DIR" ]] || die "USER_DIR not writable: $USER_DIR"

# --------------------------
# Key paths
# --------------------------
UUID="$(uuidgen)"

PRIVATE_KEY="${USER_DIR}/${UUID}.pem"
PUBLIC_KEY="${USER_DIR}/${UUID}.pub"

TMP_KEY="${PRIVATE_KEY}.tmp"
TMP_PUB="${TMP_KEY}.pub"   # ssh-keygen behavior

log "INFO" "Generating SSH key for user=$USERNAME uuid=$UUID"

# --------------------------
# Generate key (atomic)
# --------------------------
ssh-keygen \
  -t "$KEY_TYPE" \
  -b "$KEY_BITS" \
  -m PEM \
  -f "$TMP_KEY" \
  -N "" \
  -C "${KEY_COMMENT}-${USERNAME}-${UUID}" \
  -q || die "ssh-keygen failed"

# Validate tmp files
[[ -f "$TMP_KEY" ]] || die "Temp private key not created: $TMP_KEY"
[[ -f "$TMP_PUB" ]] || die "Temp public key not created: $TMP_PUB"

chmod 600 "$TMP_KEY" || die "chmod failed on tmp private key"
chmod 644 "$TMP_PUB" || die "chmod failed on tmp public key"

# Move atomically
mv -f "$TMP_KEY" "$PRIVATE_KEY" || die "Failed to move private key"
mv -f "$TMP_PUB" "$PUBLIC_KEY"  || die "Failed to move public key"

chmod 600 "$PRIVATE_KEY" || die "chmod failed on private key"
chmod 644 "$PUBLIC_KEY"  || die "chmod failed on public key"

# --------------------------
# Validate keys
# --------------------------
ssh-keygen -lf "$PRIVATE_KEY" >/dev/null || die "Private key validation failed"
ssh-keygen -lf "$PUBLIC_KEY"  >/dev/null || die "Public key validation failed"

# --------------------------
# authorized_keys install
# --------------------------
HOME_DIR="$(getent passwd "$USERNAME" | cut -d: -f6)"
SSH_DIR="${HOME_DIR}/.ssh"
AUTH_KEYS="${SSH_DIR}/authorized_keys"

[[ -d "$HOME_DIR" ]] || die "Home directory not found: $HOME_DIR"

mkdir -p "$SSH_DIR" || die "Failed to create .ssh dir"
chmod 700 "$SSH_DIR" || die "chmod failed on .ssh"

touch "$AUTH_KEYS" || die "Failed to touch authorized_keys"
chmod 600 "$AUTH_KEYS" || die "chmod failed on authorized_keys"

# Remove old sysadmin keys for this user
grep -Fv "${KEY_COMMENT}-${USERNAME}" "$AUTH_KEYS" > "${AUTH_KEYS}.tmp" || true
cat "$PUBLIC_KEY" >> "${AUTH_KEYS}.tmp"
mv -f "${AUTH_KEYS}.tmp" "$AUTH_KEYS" || die "Failed to update authorized_keys"

chown -R "${USERNAME}:${USERNAME}" "$SSH_DIR" || die "chown failed on .ssh"

# --------------------------
# Inventory
# --------------------------
FINGERPRINT="$(ssh-keygen -E sha256 -lf "$PUBLIC_KEY" | awk '{print $2}')"
HOSTNAME="$(hostname -f 2>/dev/null || hostname)"
ROTATED_AT="$(timestamp)"

[[ -n "$FINGERPRINT" ]] || die "Failed to get fingerprint"

# CSV
if [[ ! -f "$INVENTORY_CSV" ]]; then
  echo "timestamp,hostname,user,public_key_path,fingerprint" > "$INVENTORY_CSV" \
    || die "Failed to create inventory CSV"
fi

echo "${ROTATED_AT},${HOSTNAME},${USERNAME},${PUBLIC_KEY},${FINGERPRINT}" \
  >> "$INVENTORY_CSV" || die "Failed to write inventory CSV"

chmod 600 "$INVENTORY_CSV"

# NDJSON (single source for wrapper)
echo "{\"timestamp\":\"${ROTATED_AT}\",\"hostname\":\"${HOSTNAME}\",\"user\":\"${USERNAME}\",\"public_key\":\"${PUBLIC_KEY}\",\"fingerprint\":\"${FINGERPRINT}\"}" \
  >> "$INVENTORY_NDJSON" || die "Failed to write inventory NDJSON"

chmod 600 "$INVENTORY_NDJSON"

# --------------------------
# Success
# --------------------------
log "INFO" "SSH key generated successfully"
log "INFO" "User=$USERNAME"
log "INFO" "UUID=$UUID"
log "INFO" "Private=$PRIVATE_KEY"
log "INFO" "Public=$PUBLIC_KEY"
log "INFO" "Fingerprint=$FINGERPRINT"

exit 0

