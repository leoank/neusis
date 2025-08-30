# Neusis Documentation

This Nix configuration manages multiple Linux and macOS machines for a shared lab/team environment.

## Key Features

- **Multi-user setup**: Users defined in `users/` with different permission levels (admin/regular/guest)
- **Per-machine, per-user configs**: Each user can have different settings on different machines
- **Self-service workflow**: Users can test changes locally before submitting PRs
- **Development templates**: Quick-start templates for Python, Rust, etc.

## Machines

The repository currently manages configurations for:

- **karkinos**: NixOS developer workstation
- **darwin001**: macOS developer machine  
- **oppy, spirit**: Compute servers with GPU support
- **chiral**: Specialized system configurations

## Repository Structure

```
neusis/
├── flake.nix              # Entry point - defines inputs, outputs, and system configurations
├── machines/              # Machine-specific configurations
│   ├── karkinos/          # NixOS developer workstation
│   ├── darwin001/         # macOS M-series machine
│   ├── oppy/              # Compute server with GPU
│   ├── spirit/            # Compute server with GPU
│   ├── chiral/            # Specialized system
│   └── common/            # Shared machine modules (GPU, networking, SSH, etc.)
├── homes/                 # User home configurations (per-user)
│   ├── <username>/        # Individual user directories
│   │   ├── home.nix       # Base user profile
│   │   └── machines/      # Per-machine user configs
│   └── common/            # Shared home modules (dev tools, browsers, terminals)
├── users/                 # User definitions and permissions
├── modules/               # Custom NixOS and home-manager modules
├── pkgs/                  # Custom packages (Claude Code, NVIDIA vGPU, etc.)
├── overlays/              # Package modifications and overrides
├── templates/             # Development environment templates (Python, Rust, FHS)
├── lib/                   # Neusis utility functions
└── docs/                  # Documentation including NixOS & Flakes book
```

## How It Works

1. Users are defined in `users/*.nix` with their SSH keys and shell preferences
2. The `lib.neusisOS` functions dynamically generate home configurations for each user@machine combination
3. Users can test changes locally with `home-manager switch` before submitting PRs
4. Admins control which machines users can access

## Differences from Typical Configs

Most personal Nix configs manage one user's dotfiles. This repo handles multiple users across multiple machines, useful for teams or shared computing environments. It's essentially a lightweight user management layer on top of NixOS/nix-darwin.

## Documentation

- [Getting Started](01_getting_started.md) - Set up your user account and environment
- [Architecture Overview](02_architecture.md) - Detailed technical overview
- [Environment Setup](03_environment_setup.md) - Create development environments  
- [User Management](04_user_management.md) - Admin guide for adding users