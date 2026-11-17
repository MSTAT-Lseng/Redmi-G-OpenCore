#!/bin/bash
# Creates an admin user on an installed macOS Data volume and skips Setup Assistant.
# Run from the macOS installer's Terminal (Utilities > Terminal):
#   bash /Volumes/<YOUR_USB>/create-user.sh [username] ["Real Name"]

set -u

USERNAME="${1:-username}"
REALNAME="${2:-RealName}"
UID_NUM=501
GID_NUM=20

# --- Locate the Data volume -------------------------------------------------
find_data_volumes() {
  for v in /Volumes/*; do
    [ -d "$v/private/var/db/dslocal/nodes/Default" ] && echo "$v"
  done
}

CANDIDATES=()
while IFS= read -r line; do CANDIDATES+=("$line"); done < <(find_data_volumes)

# If nothing is mounted yet, try mounting every APFS Data volume.
if [ ${#CANDIDATES[@]} -eq 0 ]; then
  echo "No mounted Data volume found, trying to mount APFS Data volumes..."
  for id in $(diskutil list | awk '/ Data /{print $NF}'); do
    diskutil mount "$id" >/dev/null 2>&1
  done
  while IFS= read -r line; do CANDIDATES+=("$line"); done < <(find_data_volumes)
fi

if [ ${#CANDIDATES[@]} -eq 0 ]; then
  echo "ERROR: Could not find a Data volume with a local directory node."
  echo "Run 'diskutil apfs list', mount the volume manually (diskutil mount \"macOS - Data\"), and retry."
  echo "Note: if FileVault is enabled the volume must be unlocked first."
  exit 1
fi

if [ ${#CANDIDATES[@]} -eq 1 ]; then
  D="${CANDIDATES[0]}"
else
  echo "Multiple Data volumes found:"
  i=1
  for c in "${CANDIDATES[@]}"; do echo "  $i) $c"; i=$((i+1)); done
  printf "Choose a number: "
  read -r choice
  D="${CANDIDATES[$((choice-1))]:-}"
  [ -z "$D" ] && { echo "Invalid choice."; exit 1; }
fi

N="$D/private/var/db/dslocal/nodes/Default"
echo "Using Data volume: $D"
echo "Creating user:     $USERNAME ($REALNAME)"

# --- Abort if the user already exists ---------------------------------------
if dscl -f "$N" localhost -read "/Local/Default/Users/$USERNAME" >/dev/null 2>&1; then
  echo "ERROR: User '$USERNAME' already exists on this volume."
  exit 1
fi

# --- Ask for password ---------------------------------------------------------
printf "Password for %s: " "$USERNAME"
read -r -s PASS1; echo
printf "Confirm password: "
read -r -s PASS2; echo
if [ -z "$PASS1" ] || [ "$PASS1" != "$PASS2" ]; then
  echo "ERROR: Passwords are empty or do not match."
  exit 1
fi

GUID=$(uuidgen)
U="/Local/Default/Users/$USERNAME"

# --- Create the account -------------------------------------------------------
dscl -f "$N" localhost -create "$U"
dscl -f "$N" localhost -create "$U" UserShell /bin/zsh
dscl -f "$N" localhost -create "$U" RealName "$REALNAME"
dscl -f "$N" localhost -create "$U" UniqueID "$UID_NUM"
dscl -f "$N" localhost -create "$U" PrimaryGroupID "$GID_NUM"
dscl -f "$N" localhost -create "$U" GeneratedUID "$GUID"
dscl -f "$N" localhost -create "$U" NFSHomeDirectory "/Users/$USERNAME"
dscl -f "$N" localhost -passwd "$U" "$PASS1"

# Admin rights (name and GUID)
dscl -f "$N" localhost -append /Local/Default/Groups/admin GroupMembership "$USERNAME"
dscl -f "$N" localhost -append /Local/Default/Groups/admin GroupMembers "$GUID"

# --- Home folder and Setup Assistant flag -------------------------------------
mkdir -p "$D/Users/$USERNAME"
chown "$UID_NUM:$GID_NUM" "$D/Users/$USERNAME"
touch "$D/private/var/db/.AppleSetupDone"

# --- Verify -------------------------------------------------------------------
echo
echo "Verification:"
dscl -f "$N" localhost -read "$U" UniqueID NFSHomeDirectory UserShell
dscl -f "$N" localhost -read /Local/Default/Groups/admin GroupMembership
[ -f "$D/private/var/db/.AppleSetupDone" ] && echo ".AppleSetupDone: present"

echo
echo "Done. Reboot and log in as '$USERNAME'."
