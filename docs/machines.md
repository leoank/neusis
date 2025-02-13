# NixOS Machine Configurations

This repository contains modular NixOS configurations for various machines, with shared components in the `common/` directory.

## Directory Structure

```
machines/
├── <machine-name>/     # Individual machine configurations
│   ├── default.nix     # Main configuration entry point
│   ├── disko.nix       # Disk partitioning configuration
│   ├── hardware-configuration.nix
│   └── network.nix     # Machine-specific network settings
└── common/             # Shared configuration modules
    ├── bootloader/
    ├── gpu/
    ├── network/
    └── services/

```

## Configuration Components

### Machine-Specific (`machines/<name>/`)

Each machine directory contains:

- **default.nix**: Main entry point that imports required modules and defines:
  - System packages
  - User accounts
  - Hardware settings
  - Services
  - Home Manager integration

- **disko.nix**: Storage configuration
  - Disk partitioning
  - ZFS pool setup (if applicable)
  - Mount points

- **network.nix**: Network setup
  - Interface configuration
  - Network bonding
  - Static IP settings

### Common Modules (`common/`)

Shared configurations organized by category:

#### System
- **bootloader/**
  - `systemd.nix`: UEFI with systemd-boot
  - `grub.nix`: GRUB with ZFS support
- **nix/**
  - Core settings
  - Binary caches
  - Garbage collection

#### Hardware
- **gpu/**
  - `nvidia.nix`: Standard desktop (OpenGL, 32-bit support)
  - `nvidia_dc.nix`: Datacenter optimized (CUDA, container toolkit)
  - `nvidia_sgpu.nix`: Single GPU passthrough
- **audio/**
  - `pipewire.nix`: Modern audio stack

#### Network
- **network/**
  - `base.nix`: NetworkManager and firewall
  - `ssh.nix`: OpenSSH server
  - `tailscale.nix`: VPN with auto-auth
  - `router.nix`: NAT and DHCP

#### Services
- **services/**
  - `guacamole.nix`: Remote desktop
  - `printing.nix`: CUPS
  - `containers.nix`: Container configurations

## Special Configurations

### WSL Support
For Windows Subsystem for Linux machines:

```nix
wsl = {
  enable = true;
  defaultUser = "username";
  useWindowsDriver = true;
  docker-desktop.enable = true;
  nativeSystemd = true;
};
```

## Adding a New Machine

1. Create directory structure:
```bash
mkdir -p machines/my-machine
```

2. Generate hardware config:
```bash
nixos-generate-config --root /mnt --show-hardware-config > machines/my-machine/hardware-configuration.nix
```

3. Create minimal configuration:
```nix
# machines/my-machine/default.nix
{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../common/bootloader/systemd.nix
    ../common/network/base.nix
  ];

  networking.hostName = "my-machine";
  system.stateVersion = "23.11";
}
```

4. Build and test:
```bash
sudo nixos-rebuild switch --flake .#my-machine
```

## Best Practices

1. Keep machine-specific configs minimal
2. Use common modules for shared functionality
3. Document special requirements
4. Follow consistent naming conventions
5. Create focused, single-purpose modules
6. Test configurations before deployment
