# orbstack-sandbox

## Overview

Sandboxed OrbStack VMs for LLM coding agents. OrbStack runs lightweight Linux VMs on macOS, but mounts the host filesystem (`/Users`, `/mnt/mac`) with full read/write access by default. This repo locks that down so agents running in permissive modes (e.g. `claude --dangerously-skip-permissions`) can't touch the host machine.

Each sandbox user gets an isolated mount namespace where macOS paths are hidden behind empty tmpfs mounts. It's a seatbelt — prevents accidental damage and credential access — not a jail.

## Scripts

| Script                              | Purpose                                             |
| ----------------------------------- | --------------------------------------------------- |
| `./setup.sh [machine]`              | Create/configure Ubuntu VM with dev tools           |
| `./create-user.sh <machine> <user>` | Create sandboxed user with isolated mount namespace |

## OrbStack CLI Reference

```bash
orb create ubuntu myvm          # create new machine
orb list                        # list machines
orb -m myvm                     # shell into machine
orb -m myvm -u agent            # shell as specific user
orb -m myvm uname -a            # run command in machine
orb push -m myvm src /dest      # copy file macOS → Linux
```

## How Sandboxing Works

1. `create-user.sh` creates a user with a custom login shell
2. The login shell calls `unshare --mount` to create an isolated mount namespace
3. macOS paths (`/Users`, `/mnt/mac`, etc.) are overlaid with empty tmpfs mounts
4. `setpriv` drops to the unprivileged user — no sudo available inside the sandbox
5. Admin gets ACL-based read/write access to sandbox home directories (no sudo needed)

## Tips

- **Never use `~` in scripts.** Tilde expands on macOS before `orb` runs. Use explicit paths (`/home/$USER/.zshrc`) or `orb push` for file transfers.
- **Set `SHELL=/bin/zsh` in the sandbox `.zshrc`.** The login shell is the wrapper script, not zsh. Tools that spawn subprocesses via `$SHELL -c` will break unless `SHELL` points to the real shell.
- **Handle `-c` args in the sandbox shell carefully.** Passing args through env vars loses quoting. The sandbox-shell handles `-c` as a special case, extracting the command string and passing it quoted to preserve word boundaries.
- **Sudoers must allow arguments.** The rule needs both `/usr/local/bin/sandbox-shell` and `/usr/local/bin/sandbox-shell *` to support `-c` invocations.
- **Don't redirect stderr on exec lines.** Check for shell existence before exec instead of using `2>/dev/null`, which swallows all stderr for the session.
- **Export `HOME` before dropping privileges.** `setpriv` doesn't set environment variables. The sandbox-shell must explicitly `export HOME=/home/$SANDBOX_USER` so tools write caches to the right directory.
