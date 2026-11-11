# ADR-0020: curiosity is a live disk whose host key comes from a data drive in the initrd; its N1X support comes from anvesana

Status: proposed
Date: 2026-11-11

## Context
curiosity is bbaum-pc-7, an MSI Prestige N16 Flip AI+ (NVIDIA RTX Spark N1X, aarch64-linux).
Linux bring-up happened in the anvesana repo (findings: anvesana `docs/n1x-linux.md`); Ank
wants to work on the machine from Linux now, in Claude Code sessions with his secrets and the
tailnet, without installing NixOS next to Windows yet (BitLocker, dual boot). So it boots from a
USB stick and forgets everything at each reboot.

agenix decrypts a host's secrets with its SSH host key during early boot (activation, or a
sysinit service before local filesystems). A live image gets a fresh host key every boot, so
nothing would decrypt. Alternatives:
- Bake the host key into the image: the private key would sit in the world-readable Nix store
  and on every copy of the ISO.
- Install NixOS on the internal NVMe: needs shrinking the BitLocker volume; Ank chose not to
  yet.
- Persist a whole root (impermanence on an ext4 image file): more moving parts than one key.
- Copy the key from the data drive Ank already carries (SPARKDATA, exFAT, USB) in the initrd,
  before switch-root.

The N1X hardware support (NVIDIA's kernel with patches, out-of-tree spi-hid, LPS0 module,
desktop tuning) could be copied into neusis or taken from anvesana.

## Decision
- curiosity's ISO (`packages.aarch64-linux.curiosity-live`) is built from
  `machines/curiosity.nix` like any host: users, homes, secrets, cslab tailnet, distributed
  builds, comin.
- Its host key is pre-generated like ghost001's (ADR-0011): public half in the machine file,
  an age copy for the master identity in `secrets/bootstrap/curiosity/`, the private half on
  SPARKDATA at `config/curiosity/ssh_host_ed25519_key`, never in git or the store. An initrd
  systemd service waits up to 30 s for SPARKDATA, mounts it read-only and copies the key to
  `/sysroot/etc/ssh` before switch-root, so agenix and sshd find it where they always do.
  Without the drive the boot continues without secrets.
- ank's home `secrets` bundle decrypts with ank's own key; on curiosity that key is read from
  SPARKDATA (`config/curiosity/ank/id_ed25519`) only if Ank puts it there.
- `gclb-sync` (ank's bootstrap-repos list) runs as a user service, so neusis is checked out at
  `~/workspace/repos/leoank/neusis` for changing curiosity from a session on it.
- The N1X support is the `anvesana` flake input (`nixosModules.n1x` and `n1x-desktop`), one
  source of truth; it boots with `acpi_osi="!Windows 2022"`, which needs no vendor ACPI tables.
- curiosity is alone in a `live` deploy group: its build compiles the N1X kernel, so it must
  not hold back canary or stable.

## Consequences
- Whoever has the SPARKDATA drive has curiosity's host key (and ank's key, if he puts it
  there): the drive is now as sensitive as the machine's identity. Losing it means
  `agenix rekey` with a new key.
- Tailscale state does not persist; the cslab profile re-authenticates each boot and
  force-claims the hostname.
- Building curiosity (and CI's `live` gate) compiles NVIDIA's kernel on aarch64-linux.
- anvesana's `exp/nvpcf-throttle` branch is pinned until it is merged to main.
