#!/bin/bash
# OrbStack VM Setup - run from macOS
# Usage: ./setup.sh [machine-name]

set -e

MACHINE="${1:-ubuntu}"
REPO="$(cd "$(dirname "$0")" && pwd)"
VM_REPO="/mnt/mac$REPO"
VM_USER="$(whoami)"
VM_HOME="/home/$VM_USER"

# Load environment variables for git config (GIT_USER_NAME, GIT_USER_EMAIL)
if [ -f "$REPO/.env" ]; then
    source "$REPO/.env"
fi

echo "▶ Setting up machine: $MACHINE"

# * Create the VM if it doesn't already exist
if ! orb list 2>/dev/null | grep -q "^$MACHINE "; then
    echo "  Creating machine..."
    orb create ubuntu "$MACHINE"
fi

# * Install base system packages via apt
echo "▶ Installing system packages"
orb -m "$MACHINE" sudo apt-get update
orb -m "$MACHINE" sudo apt-get install -y build-essential curl git zsh acl

# * Install Homebrew for Linux
echo "▶ Installing Homebrew"
orb -m "$MACHINE" bash -c '
    if [ ! -d /home/linuxbrew/.linuxbrew ]; then
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
'

# * Install packages from brew-packages.txt
echo "▶ Installing brew packages"
orb -m "$MACHINE" bash -c "
    eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"
    xargs brew install < '$VM_REPO/brew-packages.txt'
"

# * Push zsh, starship, and plugin configs to the VM
echo "▶ Copying config files"
orb -m "$MACHINE" mkdir -p "$VM_HOME/.config"
orb push -m "$MACHINE" "$REPO/zshrc" "$VM_HOME/.zshrc"
orb push -m "$MACHINE" "$REPO/zsh_plugins.txt" "$VM_HOME/.zsh_plugins.txt"
orb push -m "$MACHINE" "$REPO/starship.toml" "$VM_HOME/.config/starship.toml"

# * Pre-build antidote plugin cache so first shell is fast
echo "▶ Building zsh plugin cache"
orb -m "$MACHINE" zsh -c '
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    source $(brew --prefix antidote)/share/antidote/antidote.zsh
    antidote load
'

# * Set up global git config (default branch + user info from .env)
echo "▶ Configuring git"
orb -m "$MACHINE" git config --global init.defaultBranch main
if [ -n "$GIT_USER_NAME" ]; then
    orb -m "$MACHINE" git config --global user.name "$GIT_USER_NAME"
fi
if [ -n "$GIT_USER_EMAIL" ]; then
    orb -m "$MACHINE" git config --global user.email "$GIT_USER_EMAIL"
fi

# * Set zsh as default shell
echo "▶ Setting default shell to zsh"
orb -m "$MACHINE" sudo chsh -s /bin/zsh "$VM_USER"

# * Install ghostty terminfo (if running from Ghostty)
if infocmp -x xterm-ghostty &>/dev/null; then
    echo "▶ Installing ghostty terminfo"
    infocmp -x xterm-ghostty | orb -m "$MACHINE" bash -c 'sudo tic -x -'
fi

echo ""
echo "✓ Setup complete"
echo "  Connect with: orb -m $MACHINE"
