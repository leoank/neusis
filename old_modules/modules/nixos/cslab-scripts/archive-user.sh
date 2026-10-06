#!/usr/bin/env bash
# Archive a departed user's data before removing them from configuration
#
# Usage: sudo ./archive-user.sh <username>
#
# This script:
# 1. Archives /home/<username> to /work/users/_archive/<username>_YYYY-MM-DD
# 2. Changes ownership to root:imaging
# 3. Reminds you to remove user from users/cslab.nix and rebuild

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: sudo $0 <username>"
    echo "Example: sudo $0 alice"
    exit 2
fi

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 3
fi

USERNAME="$1"
ARCHIVE_DATE=$(date +%Y-%m-%d)
ARCHIVE_PATH="/work/users/_archive/${USERNAME}_${ARCHIVE_DATE}"

# Safety checks
if [ "$USERNAME" = "root" ]; then
    echo "ERROR: Cannot archive system account: $USERNAME"
    exit 1
fi

if [ ! -d "/home/$USERNAME" ]; then
    echo "ERROR: User home directory does not exist: /home/$USERNAME"
    exit 1
fi

if [ -e "$ARCHIVE_PATH" ]; then
    echo "ERROR: Archive path already exists: $ARCHIVE_PATH"
    exit 1
fi

# Archive the user
echo "Archiving user: $USERNAME"
echo "  From: /home/$USERNAME"
echo "  To:   $ARCHIVE_PATH"

mv "/home/$USERNAME" "$ARCHIVE_PATH"
chown -R root:imaging "$ARCHIVE_PATH"
chmod 750 "$ARCHIVE_PATH"

echo ""
echo "✓ User $USERNAME archived successfully"
echo ""
echo "Next steps:"
echo "  1. Remove $USERNAME from users/cslab.nix (or move to 'locked' list first)"
echo "  2. Run: sudo nixos-rebuild switch --flake .#oppy"
echo "  3. User account will be removed on next rebuild"
echo ""
echo "Archived data: $ARCHIVE_PATH"
