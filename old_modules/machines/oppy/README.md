# Oppy NixOS Configuration

```
machines/oppy/
├── default.nix                    # Main entry point: imports all modules, Tailscale mesh config
├── hardware-configuration.nix     # Auto-generated (nixos-generate-config): filesystems, kernel modules
├── README.md
│
# System Configuration (edit frequently)
├── boot.nix                       # Systemd-boot + ZFS pool import workaround (bug #359)
│                                  #   - Activation script imports zstore03, zstore16 at boot
├── network.nix                    # Bond001 (802.3ad LACP: enp206s0f0+enp206s0f1)
│                                  #   - Static IP: 10.192.6.25/24
│                                  #   - Infiniband: ibp69s0 configured
│                                  #   - MAC/GUID matching hardcoded
├── system.nix                     # System-level config:
│                                  #   - nixpkgs: cudaSupport=true, allowUnfree, overlays
│                                  #   - FHS compat (nix-ld), theme support (dconf)
│                                  #   - Install ISO format settings
├── packages.nix                   # System packages & shell config
│                                  #   - Packages: vim, dive, podman-tui, ipmitool
│                                  #   - Shells: zsh, fish enabled
├── services.nix                   # Running services:
│                                  #   - Monitoring: Grafana/Prometheus (neusis.services.monitoring)
│                                  #   - IPMI: Device access (ipmiusers group, udev rules)
│
# CSLab Policies (portable when Spirit migrates to NixOS)
├── cslab/
│   ├── infrastructure.nix         # Lab infrastructure setup:
│   │                              #   - Creates imaging group (GID 1000) for all lab members
│   │                              #   - /work/{datasets,users,scratch,tools,_archive} structure
│   │                              #   - Per-user dirs (750 perms): /work/users/<user>, /work/scratch/<user>
│   │                              #   - Build assertion: fails if exx/root in config (prevents lockout)
│   │                              #   - Installs test-cslab-infrastructure.sh to system PATH
│   ├── monitoring.nix             # Automated monitoring:
│   │                              #   - Quota checks: Mon 9AM (100GB limit, Slack alerts via agenix)
│   │                              #   - Group audits: Wed 9AM (detects unauthorized sudo)
│   │                              #   - Logs: /var/log/lab-scripts/
│   └── scripts/
│       ├── archive-user.sh        # Manual user removal: archives /home/<user> to /work/users/_archive
│       │                          #   Usage: sudo archive-user.sh <username>
│       ├── check-quotas.nu        # Nushell: quota monitoring (called by monitoring.nix timer)
│       └── test-cslab-infrastructure.sh  # Validation suite (available as sudo test-cslab-infrastructure.sh)
│
# Deployment Configs (install-time only, NOT for rebuilds)
├── deployment/
│   ├── disko.nix                  # Disk partitioning & ZFS pools:
│   │                              #   - Boot: Samsung 990 PRO 4TB (ssd00)
│   │                              #   - work: 3x Kioxia 15TB stripe (~42TB usable)
│   │                              #   - Datasets: /work/{datasets,users,scratch,tools,users/_archive}
│   │                              #   - Config: lz4 compression, dedup OFF, per-dataset snapshot policies
│   │                              #   WARNING: Changes NOT applied on rebuild, only during install
│   │                              #   See ../../imaging-server-maintenance/assets/EXPERIMENTS_DISKO_MIGRATION.md
│   └── vm.nix                     # VM testing config (vmVariantWithDisko)
│                                  #   Usage: TESTVM_SECRETS=$(pwd)/scratch nix run .#nixosConfigurations.oppy.config.system.build.vmWithDisko
│                                  #   Mounts secrets from host via virtio for testing
│
# Deprecated Files (archived, not imported)
└── archive/
    ├── users.nix                  # Old manual user config (replaced by neusis lib + users/cslab.nix)
    ├── broad_req_routes.txt       # Historical routing table snapshot
    ├── disko_install_cmd.txt      # Old install commands (now in RUNBOOK_NIX.md)
    └── network_config.txt         # Old manual network setup (now declarative in network.nix)
```

## Shared Configuration (from `../common/`)

Oppy imports 12 shared modules used across all neusis machines:

```
../common/
├── networking.nix          # NetworkManager enabled, firewall disabled
├── gpu/
│   └── nvidia_dc.nix       # Driver 535.x, persistence mode, GSP firmware (H100 NVL)
├── substituters.nix        # Binary caches: devenv, cuda-maintainers, nix-gaming, ai
├── virtualization.nix      # Podman (docker compat), libvirtd, Apptainer, virt-manager
├── input_device.nix        # X11 keyboard (US), libinput for touchpad
├── ssh.nix                 # Root login allowed, password auth, X11 forwarding
├── us_eng.nix              # Timezone: America/New_York, locale: en_US.UTF-8
├── nosleep.nix             # Disable sleep/suspend/hibernate (server stays on)
├── nix.nix                 # Flakes enabled, weekly GC (15d retention), auto-optimize
├── printing.nix            # CUPS printing service
└── zfs.nix                 # ZFS kernel modules, auto-scrub, trim, NFS server
```

## Related Configuration

```
../../users/
└── cslab.nix                                        # Single file with user lists:
                                                     #   - admins: Full sudo (wheel group)
                                                     #   - regulars: Standard users (no sudo)
                                                     #   - locked: Account exists, nologin shell
                                                     #   - guests: Minimal privileges

../../imaging-server-maintenance/
└── RUNBOOK_NIX.md                                   # Operations: deployment, troubleshooting, user mgmt
```
