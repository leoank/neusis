# Agent Instructions

## Overview

Neusis is a NixOS/nix-darwin flake-based configuration management system for Linux and macOS machines. It provides declarative system configurations, user management, and home-manager integration across multiple machines.

## Development Commands

### Building System Configurations

For NixOS (Linux) machines:

```bash
nixos-rebuild switch --flake .#<machine-name>
```

For Darwin (macOS) machines:

```bash
darwin-rebuild switch --flake .#darwin001
```

Available machines: `oppy`, `karkinos`, `chiral`(Linux), `rogue` , `darwin001` (macOS)

### Development Shell

```bash
nix develop
```

This provides access to essential tools like `home-manager`, `disko`, `nixos-anywhere`, `agenix`, and others.

### Home Manager Configurations

Build standalone home-manager configurations:

```bash
home-manager switch --flake .#<username>@<machine>
```

### Deployment Tools

- `nixos-anywhere`: Remote system deployment
- `disko`: Disk partitioning and formatting
- `agenix`: Secret management

## Architecture

### Core Structure

- **flake.nix**: Main entry point defining inputs, outputs, and system configurations
- **lib/neusisOS.nix**: Core library providing user management utilities and system builders
- **machines/**: Machine-specific configurations organized by hostname
- **homes/**: User home-manager configurations organized by username
- **users/**: User account definitions (admins, regulars, guests)
- **modules/**: Reusable NixOS and home-manager modules

### Key Components

1. **User Management System** (`lib/neusisOS.nix`):
   - Three user types: admins (wheel group), regulars, guests
   - Automatic SSH key management
   - Home-manager integration
   - Dynamic user creation across machines

2. **Machine Registry** (`machines/registry.nix`):
   - Maps machine names to their target systems
   - Handles cross-platform package sets

3. **Flake Modules** (`flakeModules/`):
   - Modular system for organizing configurations
   - Automatic home configuration generation
   - Build checks and validation

### Configuration Pattern

Each machine follows this structure:

- Machine definition in `machines/<name>/default.nix`
- Hardware configuration and system-specific settings
- User accounts via using user sets from `users/`
- Home-manager configurations per user per machine

### Package Management

Custom packages in `pkgs/`:

- `kalam`/`kalampy`/`kalamv2`: Neovim distributions
- Hardware-specific packages (Intel FPGA, Xilinx, NVIDIA vGPU)

### Secrets Management

- Age-encrypted secrets in `secrets/`
- SSH keys managed per user
- Tailscale authentication keys

## Common Patterns

- All configurations use flake.nix as the single source of truth
- User configurations support per-machine customization via `homeModules.<machine>`
- System configurations inherit from common modules in `machines/common/`
- Templates in `templates/` for new project types

## User Types and Management

The system supports four user types defined in `lib/neusisOS.nix`:

1. **Admins** (`mkAdmin`): Full privileges with wheel group, networkmanager, libvirtd, docker, podman access
2. **Regulars** (`mkRegular`): Standard users with libvirtd, docker, podman access (no wheel/sudo)
3. **Locked** (`mkLocked`): Account exists with data preserved but cannot login (shell set to nologin, password locked with "!")
4. **Guests** (`mkGuest`): Minimal privileges with basic input, podman, docker access

User definitions are merged from `users/*.nix` files via `mergeUserConfigs` in `users/all.nix`. Each user config specifies:
- `username`, `fullName`, `shell`
- `sshKeys`: List of SSH public key file paths
- `homeModules.<machine>`: Per-machine home-manager configuration paths

## Contributing Guidelines

- **No surprises**: Features must be opt-in via individual `homes/<user>/home.nix`, not forced through `homes/common/`
- **Personal boundaries**: SSH agents, shells, and user tools belong in `homes/<user>/` configs only
- **Cross-platform**: Don't hardcode architectures in `flake.nix` - use `machines/registry.nix` for dynamic package sets
- **User management**: Add new users to `users/*.nix` files, never hardcode in machine configs

This project uses **bd** (beads) for issue tracking. Run `bd prime` for full workflow context.

> **Architecture in one line:** Issues live in a local Dolt database
> (`.beads/dolt/`); cross-machine sync uses `bd dolt push/pull` (a
> git-compatible protocol), stored under `refs/dolt/data` on your git
> remote — separate from `refs/heads/*` where your code lives.
> `.beads/issues.jsonl` is a passive export, not the wire protocol.
>
> See [SYNC_CONCEPTS.md](https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md)
> for the one-screen overview and anti-patterns (don't treat JSONL as the
> source of truth; don't `bd import` during normal operation; don't
> reach for third-party Dolt hosting before trying the default).

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work atomically
bd close <id>         # Complete work
bd dolt push          # Push beads data to remote
```

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging on confirmation prompts.

Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i` (interactive) mode on some systems, causing the agent to hang indefinitely waiting for y/n input.

**Use these forms instead:**
```bash
# Force overwrite without prompting
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file

# For recursive operations
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

**Other commands that may prompt:**
- `scp` - use `-o BatchMode=yes` for non-interactive
- `ssh` - use `-o BatchMode=yes` to fail instead of prompting
- `apt-get` - use `-y` flag
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1` env var

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:7510c1e2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
