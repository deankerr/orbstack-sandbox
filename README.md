# OrbStack Sandbox

Set up isolated Ubuntu VMs in OrbStack with sandboxed users that can't access your macOS filesystem.

## Quick Start

```bash
# Set up a new machine (or configure existing one)
./setup.sh myvm

# Create a sandboxed user
./create-user.sh myvm agent

# Connect
orb -m myvm              # as yourself
orb -m myvm -u agent     # as sandboxed user
```

## Scripts

| Script | Purpose |
|--------|---------|
| `setup.sh [machine]` | Create/configure Ubuntu VM with zsh, homebrew, starship |
| `create-user.sh <machine> <user>` | Create sandboxed user with isolated mount namespace |

## What It Does

### setup.sh
- Creates Ubuntu VM (if needed)
- Installs: zsh, homebrew, starship, mise, micro, eza
- Copies zsh/starship config from this repo
- Copies `~/.claude/CLAUDE.md` for Claude Code

### create-user.sh
- Creates unprivileged user with custom login shell
- Login shell uses `unshare --mount` to hide macOS paths
- Sandboxed user sees empty `/Users`, `/mnt/mac`, etc.
- Copies shell config and CLAUDE.md to sandboxed user's home

## The Problem

OrbStack mounts macOS filesystems via virtiofs:
- `/Users` → your home, SSH keys, credentials
- `/mnt/mac` → entire macOS root

These mounts bypass Linux permissions. Any user can read/write them.

## The Solution

Mount namespaces give each sandboxed user an isolated view where macOS paths are hidden behind empty tmpfs mounts.

```
Admin user:              Sandboxed user:
/Users → macOS           /Users → empty tmpfs
/mnt/mac → macOS         /mnt/mac → empty tmpfs
```

## Limitations

This is a seatbelt, not a jail:
- Protects against accidental `rm -rf ~`
- Prevents credential theft
- Does NOT protect against network exfiltration, kernel exploits, or determined attackers
