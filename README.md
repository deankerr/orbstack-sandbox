# orbstack-sandbox

Sandboxed OrbStack VMs for LLM coding agents. OrbStack is a fast, lightweight way to run Linux VMs on macOS — but it mounts the host filesystem with full access by default. This locks that down so agents running in permissive modes (e.g. `claude --dangerously-skip-permissions`) can work on dev tasks without risking the host machine.

It's a seatbelt, not a jail — it guards against accidental host damage and credential access, not a determined attacker. Don't rely on it to contain untrusted or adversarial code.

## Quick Start

```bash
# Set up a new VM (or configure existing one)
./setup.sh myvm

# Create a sandboxed user
./create-user.sh myvm agent

# Connect as sandboxed user
orb -m myvm -u agent
```

## How It Works

OrbStack mounts `/Users` and `/mnt/mac` into every VM with full read/write access — exposing your home directory, SSH keys, and credentials to any process in the VM.

This repo gives each sandbox user a custom login shell that runs `unshare --mount` to build a private mount namespace, overlays the macOS paths with empty tmpfs mounts, then uses `setpriv` to drop to the unprivileged user — so there is no sudo inside the sandbox. Each sandbox user sees empty directories in place of macOS paths:

```
Admin user:              Sandboxed user:
/Users → macOS home      /Users → empty
/mnt/mac → macOS root    /mnt/mac → empty
```

The admin user retains full access and can read/write sandbox home directories via POSIX ACLs (no sudo needed).

## Scripts

| Script                            | Purpose                                                            |
| --------------------------------- | ------------------------------------------------------------------ |
| `setup.sh [machine]`              | Create/configure Ubuntu VM with zsh, homebrew, starship, dev tools |
| `create-user.sh <machine> <user>` | Create sandboxed user with isolated mount namespace                |

### setup.sh

- Creates Ubuntu VM (if needed)
- Installs system packages, Homebrew, and tools from `brew-packages.txt`
- Configures zsh, starship, antidote (plugin manager), and git

### create-user.sh

- Creates unprivileged user with custom login shell
- Login shell uses `unshare --mount` + `setpriv` for namespace isolation and privilege drop
- Copies shell/git config from admin user
- Sets up ACLs so admin can access sandbox home without sudo

## Pre-installed Tools

bun, node, uv, git, gh, curl, wget, ripgrep, fd, fzf, bat, eza, tree, jq, yq, micro, fresh-editor, tmux, sqlite, unar, starship, antidote

See `brew-packages.txt` for the full list.

## VS Code Remote SSH

OrbStack's auto-generated SSH config only matches the `orb` host alias. To connect to specific machines via `*.orb.local` hostnames (e.g. in VS Code Remote SSH), add this to `~/.ssh/config` before the `Host *` block:

```
Host *.orb.local
  IdentityFile ~/.orbstack/ssh/id_ed25519
  IdentitiesOnly yes
  UserKnownHostsFile ~/.orbstack/ssh/known_hosts
```

Then connect as any user: `dean@orb5.orb.local`, `agent@orb5.orb.local`, etc.
