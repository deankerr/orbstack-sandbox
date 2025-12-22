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

## Sandbox Shell Gotchas

Several subtle issues can break tools running inside the sandbox:

### 1. stderr gets swallowed

**Symptom:** No error output visible in the sandbox shell.

**Cause:** Using `2>/dev/null` on the final `exec` line to suppress "zsh not found" errors also suppresses all stderr for the session.

**Fix:** Check for shell existence before exec instead of redirecting stderr:
```bash
if [ -x /bin/zsh ]; then
    exec sudo -u $USER /bin/zsh --login
else
    exec sudo -u $USER /bin/bash --login
fi
```

### 2. Tools can't run commands via `$SHELL -c`

**Symptom:** Tools like opencode that spawn subprocesses via `$SHELL -c "command"` produce no output.

**Cause:** Two issues:
1. `$SHELL` points to the login wrapper (`/usr/local/bin/{user}-login`), not `/bin/zsh`
2. The login wrapper didn't pass `-c` args through to the actual shell

**Fix:**
- Set `export SHELL=/bin/zsh` in `.zshrc` so tools use zsh directly
- Also fixed the wrapper to handle `-c` properly (see below)

### 3. Arguments to sandbox-shell get word-split

**Symptom:** `$SHELL -c "echo hello world"` only prints empty line or partial output.

**Cause:** Passing args through env vars loses quoting. `SANDBOX_ARGS="$*"` turns `-c "echo hello"` into `-c echo hello`, then `$SHELL_BIN $SANDBOX_ARGS` becomes `zsh -c echo hello` where zsh interprets "echo" as the command and "hello" as `$0`.

**Fix:** Handle `-c` specially—extract the command string into `SANDBOX_CMD` and pass it quoted:
```bash
if [ "$SANDBOX_MODE" = "cmd" ]; then
    exec sudo -u $USER $SHELL_BIN -c "$SANDBOX_CMD"
fi
```

### 4. sudoers blocks commands with arguments

**Symptom:** `sandbox-shell -c "..."` silently fails.

**Cause:** sudoers rule `/usr/local/bin/sandbox-shell` only allows the command with zero arguments.

**Fix:** Allow both forms:
```
user ALL=(root) SETENV:NOPASSWD: /usr/local/bin/sandbox-shell, /usr/local/bin/sandbox-shell *
```
