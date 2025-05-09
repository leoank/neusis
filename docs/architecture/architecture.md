# Neusis: Multi-machine Nix Configuration System

**Purpose**: This document provides a comprehensive technical overview of the Neusis system architecture. It explains the core concepts, dependency structure, and implementation details of the Nix-based configuration system. This document is essential for understanding how different components interact and how the system is organized.

A reproducible, declarative infrastructure-as-code system for managing multiple machines and user environments using the Nix ecosystem (NixOS, nix-darwin, and home-manager).

## Nix Fundamentals

This repository leverages core Nix concepts:

- **Flakes**: Self-contained, reproducible Nix environments with explicit dependencies
- **NixOS**: Linux distribution built on the Nix package manager
- **nix-darwin**: NixOS-like system for macOS configuration
- **home-manager**: User environment management tool
- **Pure Functions**: All configurations are pure functions from inputs to system state

## Conceptual Architecture

This repository implements a directed acyclic dependency graph where:

- **Nodes**: Configuration units (machines, users, modules)
- **Edges**: Import/dependency relationships
- **Entry Point**: flake.nix (root node)

The system follows Nix's pure functional composition principles where configurations are composed through explicit imports rather than global state.

### Visualizing the Dependency Graph

For a comprehensive view of dependency structure, you can use specialized tools:
- [nix-visualize](https://github.com/craigmbooth/nix-visualize)
- [nix-du](https://github.com/symphorien/nix-du)
- [nix-tree](https://github.com/utdemir/nix-tree)

## Nix-based Dependency Structure

```ascii
flake.nix                          # Nix flake entry point
├── inputs                         # External Nix dependencies
│   ├── nixpkgs                    # Main package collection 
│   ├── nixpkgs-unstable           # Bleeding-edge packages
│   ├── home-manager               # User environment manager
│   ├── nix-darwin                 # macOS system configuration
│   ├── nixos-hardware             # Hardware-specific optimizations
│   ├── hyprland                   # Wayland compositor
│   ├── agenix                     # Secret management
│   ├── stylix                     # System-wide theming
│   ├── nixvim                     # Declarative Neovim
│   ├── disko                      # Disk partitioning
│   └── [other flake inputs]       # Additional dependencies
│
├── outputs
│   ├── nixosConfigurations        # NixOS machine configurations
│   │   ├── karkinos               # Developer workstation
│   │   │   ├── default.nix        # Top-level machine config
│   │   │   ├── hardware-configuration.nix # Hardware specifics
│   │   │   ├── disko.nix          # Disk layout
│   │   │   ├── filesystem.nix     # Filesystem configuration
│   │   │   ├── machines/common/   # Shared modules (imported)
│   │   │   │   ├── gui.nix        # Desktop environment
│   │   │   │   ├── networking.nix # Network configuration
│   │   │   │   ├── ssh.nix        # SSH server config
│   │   │   │   ├── gpu/           # GPU-specific configurations
│   │   │   │   │   └── nvidia.nix # NVIDIA driver config
│   │   │   │   ├── nix.nix        # Nix package manager config
│   │   │   │   └── tailscale.nix  # VPN configuration
│   │   │   └── homes/<users>/machines/karkinos.nix # User configurations
│   │   │
│   │   ├── oppy, spirit           # Compute servers
│   │   └── chiral                 # Specialized system
│   │
│   ├── darwinConfigurations       # macOS machine configurations
│   │   └── darwin001
│   │       ├── default.nix        # Top-level macOS config
│   │       ├── machines/common/   # Shared modules (imported)
│   │       │   ├── darwin_home_manager.nix # Home Manager integration
│   │       │   ├── nix-homebrew.nix # Homebrew integration
│   │       │   ├── casks.nix      # macOS applications
│   │       │   └── [other modules]
│   │       └── homes/<users>/machines/darwin001.nix # User configurations
│   │
│   ├── homeConfigurations         # Standalone home-manager configs
│   │   ├── <user>@<machine>       # Per-user, per-machine configs
│   │   ├── homes/<user>/home.nix  # Base user profile
│   │   │   ├── programs           # User application configs
│   │   │   └── imports            # Module imports
│   │   └── homes/common/          # Shared home modules
│   │       ├── browsers/          # Browser configurations
│   │       ├── dev/               # Development tools
│   │       │   ├── git.nix        # Version control
│   │       │   ├── editors.nix    # Editor configurations
│   │       │   ├── terminals.nix  # Terminal emulators
│   │       │   └── nixvim/        # Neovim configuration
│   │       ├── gui/               # Desktop environment
│   │       ├── network/           # Network tools
│   │       └── themes/            # Visual customization
│   │
│   ├── nixosModules              # Reusable NixOS modules
│   │   └── nvidia-vgpu           # vGPU virtualization support
│   │
│   ├── homeManagerModules        # Reusable home-manager modules
│   │
│   ├── overlays                  # Package modifications
│   │   ├── default.nix           # Main overlay index
│   │   └── [package customizations]
│   │
│   └── packages                  # Custom packages
│       ├── <system>/        # System-specific builds
│       ├── kalam/                # Custom Neovim config
│       ├── nvidia_vgpu/          # NVIDIA vGPU support
│       ├── typedb/               # TypeDB database
│       └── sst/                  # Server-side template tools
│
└── modules                       # Local module definitions
    ├── home-manager/             # User environment modules
    └── nixos/                    # System-level modules
        └── nvidia-vgpu/          # NVIDIA virtualization
```

Each Nix module is defined as a function that takes an attribute set of parameters and returns an attribute set of configuration values, allowing for highly composable and reusable system definitions. The diagram above represents the logical dependency structure, with items higher in the tree importing and composing elements from lower levels.

## Nix Module System

Configurations leverage Nix's module system for composition:

```nix
# Example: Conditional module composition with Nix
{ config, pkgs, lib, ... }:
{
  # Standard Nix module import pattern with parameterization
  imports = [
    (import ../common/dev/editors.nix { 
      enableNvim = true;
      enableAstro = false;
    })
  ];
  
  # Direct package inclusion from nixpkgs
  environment.systemPackages = with pkgs; [
    git
    neovim
    ripgrep
  ];
  
  # Service enablement (NixOS module)
  services.tailscale.enable = true;
}
```

Nix's module system handles:
- Dependency resolution
- Option merging
- Type checking
- Default values
- Conflict resolution

## Using This Nix Repository

1. **NixOS machine setup**: `nixos-rebuild switch --flake .#<machine>`
2. **macOS machine setup**: `darwin-rebuild switch --flake .#<machine>`
3. **User environment only**: `home-manager switch --flake .#<user>@<machine>`
4. **Adding users**: See `docs/add_users.md`
5. **Extending**: Create machine-specific configs in `machines/` or user-specific in `homes/`
6. **Common modules**: Reuse components from `homes/common/` and `machines/common/`

For first-time Nix installations:
```bash
# Install Nix
sh <(curl -L https://nixos.org/nix/install)

# Enable flakes (in ~/.config/nix/nix.conf)
experimental-features = nix-command flakes

# Clone and deploy
git clone https://github.com/username/neusis.git
cd neusis
nixos-rebuild switch --flake .#<machine>
```

## Key Components

- **NixVim/Kalam/AstroNvim**: Terminal-centric development environment
- **Tailscale**: Secure networking fabric
- **GPU tools**: ML/AI acceleration (NVIDIA, vGPU)
- **Ollama**: Local LLM deployment

## Nix Implementation Notes

- **Pure Functions**: All configurations follow Nix's pure functional paradigm
- **Declarative**: System state is derived entirely from declarative specifications
- **Reproducibility**: Version pinning via flake.lock ensures bit-exact reproducibility
- **Atomic Upgrades**: Nix's transactional approach allows for safe system updates
- **Rollbacks**: Failed configurations can be instantly rolled back via the bootloader
- **Hermetic**: Builds are isolated from the host system to ensure purity

## Specialized Subsystems

### Nix-based Development Environment

The repository provides a sophisticated terminal-centric development environment using Nix to ensure consistent tooling across all machines:

```
homes/common/dev/
├── editors.nix        # Neovim configurations packaged with Nix
├── git.nix            # Version control with Nix-managed plugins
├── terminals.nix      # WezTerm, Kitty with declarative config
├── nixvim/            # Declarative Neovim via Nix modules
└── git_clone_bare.nix # Reproducible repository setup
```

Key Nix advantages for development:
- **Reproducible environments**: Same dev tools on all machines
- **Declarative configuration**: Editor/IDE setup in code
- **Version pinning**: Tools pinned to exact versions
- **Cross-platform**: Works identically on Linux and macOS

### Nix Machine Types

Each machine type has a specialized Nix configuration:

- **Developer Workstations**: 
  - karkinos (NixOS Linux)
  - darwin001 (nix-darwin macOS)
  - Custom module sets for GUI, development tools, local services
  
- **Compute Servers**: 
  - oppy, spirit (NixOS Linux)
  - Optimized for computation with GPU support
  - Minimal GUI, focus on service configuration
  
- **Specialized Systems**: 
  - chiral (NixOS Linux)
  - Example of Nix's ability to configure special-purpose machines

### Nix-managed AI Infrastructure

The system leverages Nix to integrate AI capabilities with reproducible configurations:

- **Local LLM hosting**: 
  - Ollama packaged and configured via Nix
  - Declarative service configuration
  - Consistent across all machines

- **AI-assisted Development**:
  - Neovim AI plugins (Avante, CodeCompanion) declaratively configured
  - Consistent plugin versions across all developer environments
  - Integration with local LLMs

- **ML Acceleration**:
  - NVIDIA drivers and CUDA managed by Nix
  - vGPU support via custom Nix modules
  - Reproducible ML environments via Nix templates

### Nix-based Cross-Machine Synchronization

Nix enables user environments to follow users across machines with perfect consistency:

- **Identity Management**:
  - SSH keys synchronized via Git
  - User accounts declaratively defined
  - Permissions managed through NixOS/nix-darwin modules

- **Network Fabric**:
  - Tailscale configured identically via Nix modules
  - Secure networking with consistent configuration
  - Authentication keys managed via agenix/age

- **Environment Consistency**:
  - Identical editor/terminal experience on all systems
  - Same package versions guaranteed by flake.lock
  - User preferences follow users between NixOS and macOS machines

This approach demonstrates Nix's core strength: the ability to create a cohesive, reproducible computing environment that spans multiple machines and operating systems, defined entirely in code.