# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

Available machines: `oppy`, `spirit`, `karkinos`, `chiral` (Linux), `darwin001` (macOS)

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
- `claude-code`: Claude Code CLI
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

## Contributing Guidelines

- **No surprises**: Features must be opt-in via individual `homes/<user>/home.nix`, not forced through `homes/common/`
- **Personal boundaries**: SSH agents, shells, and user tools belong in `homes/<user>/` configs only
- **Cross-platform**: Don't hardcode architectures in `flake.nix` - use `machines/registry.nix` for dynamic package sets
