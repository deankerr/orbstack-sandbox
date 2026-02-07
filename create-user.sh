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

# * Grant admin read/write access to sandbox home via ACLs
echo "▶ Setting up admin access"
orb -m "$MACHINE" bash -c "
    sudo setfacl -R -m u:$ADMIN_USER:rwX $USER_HOME
    sudo setfacl -R -d -m u:$ADMIN_USER:rwX $USER_HOME
"

# * Install sandbox-shell: uses unshare to hide macOS mounts
echo "▶ Installing sandbox-shell"
orb -m "$MACHINE" sudo tee /usr/local/bin/sandbox-shell > /dev/null << 'SANDBOX_EOF'
#!/bin/bash
if [ -z "$SANDBOX_USER" ]; then
    echo "Error: SANDBOX_USER not set" >&2
    exit 1
fi

# * Handle -c flag specially to preserve command string
SANDBOX_MODE="login"
SANDBOX_CMD=""
if [ "$1" = "-c" ]; then
    SANDBOX_MODE="cmd"
    shift
    SANDBOX_CMD="$*"
fi

if [ "$(id -u)" -ne 0 ]; then
    exec sudo SANDBOX_USER="$SANDBOX_USER" SANDBOX_MODE="$SANDBOX_MODE" SANDBOX_CMD="$SANDBOX_CMD" "$0"
fi

# * Export for the unshare subshell
export SANDBOX_USER SANDBOX_MODE SANDBOX_CMD

unshare --mount /bin/bash -c '
    for p in /Users /mnt/mac /Applications /Library /Volumes /private; do
        mount -t tmpfs none $p 2>/dev/null
    done
    export HOME=/home/$SANDBOX_USER
    cd $HOME
    SHELL_BIN=$( [ -x /bin/zsh ] && echo /bin/zsh || echo /bin/bash )

    if [ "$SANDBOX_MODE" = "cmd" ]; then
        exec setpriv --reuid=$SANDBOX_USER --regid=$SANDBOX_USER --init-groups $SHELL_BIN -c "$SANDBOX_CMD"
    else
        exec setpriv --reuid=$SANDBOX_USER --regid=$SANDBOX_USER --init-groups $SHELL_BIN --login
    fi
'
SANDBOX_EOF
orb -m "$MACHINE" sudo chmod +x /usr/local/bin/sandbox-shell

# * Create login wrapper, register shell, configure sudoers
echo "▶ Configuring login shell"
orb -m "$MACHINE" bash -c "
    # Login wrapper
    cat > /tmp/${USERNAME}-login << 'WRAPPER'
#!/bin/bash
exec sudo SANDBOX_USER=\"$USERNAME\" /usr/local/bin/sandbox-shell \"\\\$@\"
WRAPPER
    sudo mv /tmp/${USERNAME}-login /usr/local/bin/${USERNAME}-login
    sudo chmod +x /usr/local/bin/${USERNAME}-login

    # Register as valid shell
    grep -q '/usr/local/bin/${USERNAME}-login' /etc/shells || \
        echo '/usr/local/bin/${USERNAME}-login' | sudo tee -a /etc/shells > /dev/null

    # Set as user's shell
    sudo usermod -s '/usr/local/bin/${USERNAME}-login' '$USERNAME'

    # Sudoers
    echo '$USERNAME ALL=(root) SETENV:NOPASSWD: /usr/local/bin/sandbox-shell, /usr/local/bin/sandbox-shell *' | sudo tee '/etc/sudoers.d/${USERNAME}-sandbox' > /dev/null
    sudo chmod 440 '/etc/sudoers.d/${USERNAME}-sandbox'
    sudo visudo -c > /dev/null
"

# * Copy config files and create README
echo "▶ Copying config files"
orb -m "$MACHINE" bash -c "
    for f in .zshrc .zsh_plugins.txt .zsh_plugins.zsh .gitconfig; do
        [ -f '$ADMIN_HOME/'\$f ] && cp '$ADMIN_HOME/'\$f '$USER_HOME/'
    done
    [ -f '$ADMIN_HOME/.config/starship.toml' ] && {
        mkdir -p '$USER_HOME/.config'
        cp '$ADMIN_HOME/.config/starship.toml' '$USER_HOME/.config/'
    }
    cat << 'README' > '$USER_HOME/README.md'
# Sandbox Environment

Sandboxed Ubuntu VM on macOS (OrbStack). Your account is isolated from the host filesystem. You have network access but no sudo.

Installed tools: bun, node, uv, git, gh, curl, wget, ripgrep, fd, fzf, bat, eza, tree, jq, yq, tmux, sqlite, unar

If a task requires a tool that is not installed, ask for it rather than working around the limitation.
README
    sudo chown -R '$USERNAME:$USERNAME' '$USER_HOME'

    # Clean up bash configs (using zsh)
    rm -f '$USER_HOME/.bashrc' '$USER_HOME/.bash_logout' '$USER_HOME/.profile'
"

echo ""
echo "✓ Setup complete"
echo ""
echo "  To use:"
echo "    orb -m $MACHINE -u $USERNAME"
echo ""
echo "  To verify isolation:"
echo "    ls /Users        # should be empty"
echo "    ls /mnt/mac      # should be empty"
