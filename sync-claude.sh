#!/bin/bash
# Sync CLAUDE.md to VM users - run from macOS
# Usage: ./sync-claude.sh <machine> [user...]

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <machine> [user...]"
    echo "  Syncs ~/.claude/CLAUDE.md to VM users"
    echo "  If no users specified, syncs to current user only"
    exit 1
fi

MACHINE="$1"
shift

MAC_USER="$(whoami)"
MAC_CLAUDE="$HOME/.claude/CLAUDE.md"

# * Sync to the current (admin) user
echo "▶ Syncing to $MAC_USER"
orb -m "$MACHINE" mkdir -p "/home/$MAC_USER/.claude"
orb push -m "$MACHINE" "$MAC_CLAUDE" "/home/$MAC_USER/.claude/CLAUDE.md"

# * Sync to any additional users specified
for user in "$@"; do
    echo "▶ Syncing to $user"
    orb -m "$MACHINE" sudo mkdir -p "/home/$user/.claude"
    orb push -m "$MACHINE" "$MAC_CLAUDE" "/home/$user/.claude/CLAUDE.md"
    orb -m "$MACHINE" sudo chown -R "$user:$user" "/home/$user/.claude"
done

echo ""
echo "✓ Sync complete"
