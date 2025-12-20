# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repo provides scripts to set up isolated Ubuntu VMs in OrbStack with sandboxed users that cannot access macOS filesystems. It solves the security problem where OrbStack mounts `/Users` and `/mnt/mac` with full access to anyone in the VM.

## Scripts

| Script | Purpose |
|--------|---------|
| `./setup.sh [machine]` | Create/configure Ubuntu VM with dev tools |
| `./create-user.sh <machine> <user>` | Create sandboxed user with isolated mount namespace |
| `./sync-claude.sh <machine> [user...]` | Sync `~/.claude/CLAUDE.md` from macOS to VM users |

## Critical: Never Use `~` in Scripts

Never use `~` for paths in scripts that interact with VMs. The tilde expands on macOS *before* `orb` runs, so `orb -m myvm cp foo ~/.zshrc` writes to `/Users/you/.zshrc` (macOS), not `/home/you/.zshrc` (Linux).

Instead:
- Use explicit paths: `/home/$USER/.zshrc`
- Use `orb push` for file transfers: `orb push -m myvm foo /home/user/.zshrc`

## OrbStack CLI Reference

```bash
# Machine management
orb create ubuntu myvm          # create new machine
orb list                        # list machines
orb delete myvm                 # remove machine
orb start/stop/restart myvm     # control machine state

# Connecting
orb                             # shell into default machine
orb -m myvm                     # shell into specific machine
orb -m myvm -u agent            # shell as specific user

# Running commands
orb -m myvm uname -a            # run single command
orb -m myvm ./script.sh         # run script

# File transfer
orb push ~/file.txt /dest/      # macOS → Linux
orb pull ~/file.txt             # Linux → macOS
```

## How Sandboxing Works

The `create-user.sh` script:
1. Creates a user with a custom login shell (`/usr/local/bin/{user}-login`)
2. The login shell uses `unshare --mount` to create an isolated mount namespace
3. macOS paths (`/Users`, `/mnt/mac`, etc.) are hidden behind empty tmpfs mounts
4. User sees empty directories instead of macOS filesystem

This is a seatbelt (prevents accidents and credential theft), not a jail (determined attackers can still escape via network or kernel exploits).
