#!/bin/bash
# Create sandboxed user - run from macOS
# Usage: ./create-user.sh <machine-name> <username>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <machine-name> <username>"
    exit 1
fi

MACHINE="$1"
USERNAME="$2"
ADMIN_USER="$(whoami)"
ADMIN_HOME="/home/$ADMIN_USER"
USER_HOME="/home/$USERNAME"

# * Prevent accidentally sandboxing the admin user
if [ "$USERNAME" = "$ADMIN_USER" ]; then
    echo "Error: Cannot create sandbox user with same name as admin ($ADMIN_USER)"
    exit 1
fi

echo "▶ Creating sandboxed user: $USERNAME on $MACHINE"

# * Create the unprivileged user account
orb -m "$MACHINE" bash -c "
    if id '$USERNAME' &>/dev/null; then
        echo '  User $USERNAME already exists'
    else
        sudo adduser --disabled-password --gecos '' '$USERNAME'
        echo '  Created user $USERNAME'
    fi
"

# * Install sandbox-shell: uses unshare to hide macOS mounts
echo "▶ Installing sandbox-shell"
orb -m "$MACHINE" sudo tee /usr/local/bin/sandbox-shell > /dev/null << 'SANDBOX_EOF'
#!/bin/bash
if [ -z "$SANDBOX_USER" ]; then
    echo "Error: SANDBOX_USER not set" >&2
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    exec sudo SANDBOX_USER="$SANDBOX_USER" "$0" "$@"
fi

unshare --mount /bin/bash -c '
    mount -t tmpfs none /Users 2>/dev/null
    mount -t tmpfs none /mnt/mac 2>/dev/null
    mount -t tmpfs none /Applications 2>/dev/null
    mount -t tmpfs none /Library 2>/dev/null
    mount -t tmpfs none /Volumes 2>/dev/null
    mount -t tmpfs none /private 2>/dev/null
    cd /home/'"$SANDBOX_USER"'
    exec sudo -u '"$SANDBOX_USER"' /bin/zsh --login 2>/dev/null || exec sudo -u '"$SANDBOX_USER"' /bin/bash --login
'
SANDBOX_EOF
orb -m "$MACHINE" sudo chmod +x /usr/local/bin/sandbox-shell

# * Create per-user login wrapper that invokes sandbox-shell
echo "▶ Installing login wrapper"
orb -m "$MACHINE" sudo tee "/usr/local/bin/${USERNAME}-login" > /dev/null << LOGIN_EOF
#!/bin/bash
exec sudo SANDBOX_USER="$USERNAME" /usr/local/bin/sandbox-shell
LOGIN_EOF
orb -m "$MACHINE" sudo chmod +x "/usr/local/bin/${USERNAME}-login"

# * Register the wrapper as a valid login shell
orb -m "$MACHINE" bash -c "
    if ! grep -q '/usr/local/bin/${USERNAME}-login' /etc/shells; then
        echo '/usr/local/bin/${USERNAME}-login' | sudo tee -a /etc/shells > /dev/null
    fi
"

# * Set it as the user's default shell
orb -m "$MACHINE" sudo usermod -s "/usr/local/bin/${USERNAME}-login" "$USERNAME"

# * Allow user to run sandbox-shell via sudo without password
echo "▶ Configuring sudoers"
orb -m "$MACHINE" bash -c "
    echo '$USERNAME ALL=(root) SETENV:NOPASSWD: /usr/local/bin/sandbox-shell' | sudo tee '/etc/sudoers.d/${USERNAME}-sandbox' > /dev/null
    sudo chmod 440 '/etc/sudoers.d/${USERNAME}-sandbox'
    sudo visudo -c > /dev/null
"

# * Copy shell config (.zshrc, plugins, starship, gitconfig) from admin
echo "▶ Copying config files"
orb -m "$MACHINE" bash -c "
    for f in .zshrc .zsh_plugins.txt .zsh_plugins.zsh .gitconfig; do
        [ -f '$ADMIN_HOME/'\$f ] && sudo cp '$ADMIN_HOME/'\$f '$USER_HOME/'
    done
    if [ -f '$ADMIN_HOME/.config/starship.toml' ]; then
        sudo mkdir -p '$USER_HOME/.config'
        sudo cp '$ADMIN_HOME/.config/starship.toml' '$USER_HOME/.config/'
    fi
    sudo chown -R '$USERNAME:$USERNAME' '$USER_HOME'
"

# * Copy CLAUDE.md for Claude Code context
echo "▶ Copying CLAUDE.md"
orb -m "$MACHINE" sudo mkdir -p "$USER_HOME/.claude"
orb push -m "$MACHINE" "$HOME/.claude/CLAUDE.md" "$USER_HOME/.claude/CLAUDE.md" 2>/dev/null || echo "  No CLAUDE.md found, skipping"
orb -m "$MACHINE" sudo chown -R "$USERNAME:$USERNAME" "$USER_HOME/.claude"

# * Create a README explaining the sandbox restrictions
echo "▶ Creating user README"
orb -m "$MACHINE" sudo tee "/home/$USERNAME/README.md" > /dev/null << 'README_EOF'
# Sandboxed Environment

You are running in a sandboxed shell. macOS filesystem paths are hidden.

## What's restricted
- /Users, /mnt/mac, /Applications, /Library, /Volumes - all empty
- No sudo access (except the sandbox wrapper itself)
- No access to other users' home directories

## What works
- Your home directory: ~/
- Network access
- Installing packages in your home (npm, pip --user, etc.)

If you need system packages installed, ask the admin user.
README_EOF
orb -m "$MACHINE" sudo chown "$USERNAME:$USERNAME" "/home/$USERNAME/README.md"

echo ""
echo "✓ Setup complete"
echo ""
echo "  To use:"
echo "    orb -m $MACHINE -u $USERNAME"
echo ""
echo "  To verify isolation:"
echo "    ls /Users        # should be empty"
echo "    ls /mnt/mac      # should be empty"
