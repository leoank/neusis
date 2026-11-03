# ADR-0011: Cloud hosts boot one shared base image and become themselves through neusis cloud bootstrap; nixos-anywhere is the fallback

Status: accepted
Date: 2026-10-16
Backfilled: 2026-11-03, from `cloud-terranix-spec.md` (§4.4, §5.2–5.4, §8, §12
questions 6–8) and `porting.md` (2026-10-19 M3).

## Context
An OCI host needs a NixOS it can boot before its own configuration (and the secrets
that configuration needs) can be applied. Alternatives in the spec:
- nixos-anywhere onto a platform image (kexec + disko): proven and already in the
  `neusis` CLI, but the machine's first OS isn't ours, kexec is fragile on small shapes,
  and it needs a disko layout.
- Host-specific images with the full host config baked in: an image import per host,
  the host key still needs injecting, and every OS change tempts replacing the instance.
- cloud-init in the image: adds state the IMDS `fetch-ssh-keys` unit makes unnecessary.
- deploy-rs or colmena for day 2: not needed for one host; worth revisiting for magic
  rollback once there are several.

## Decision
- `lib.cloud.mkOciBaseImage` builds one qcow2 per architecture (`oci-image.nix` +
  `features.nixos.oci-guest`): flakes on, no users, secrets or mesh, root by SSH key
  from instance metadata. It is a package, not a `nixosConfiguration`, so
  agenix-rekey and T1 never treat it as a host.
- `neusis cloud bootstrap <host>` pushes the pre-generated host key (ADR-0006) and
  switches the instance to its real configuration with `nixos-rebuild`. Day 2 is
  `neusis cloud deploy` over the tailnet.
- The instance ignores image and metadata changes, so re-baking the image never
  replaces a host. A test pins that the base image and `oci-guest` share disk layout and
  bootloader, which is what makes the switch safe.
- Public SSH stays open after bootstrap by default and can be closed (ank's answer to
  question 8).
- nixos-anywhere (`neusis anywhere`) stays available as the escape hatch.

## Consequences
- One image serves every host of an architecture, and an OS change is a `switch`, not a
  re-provision.
- Bootstrap tooling lives in the Go CLI next to `anywhere`, not in a flake app.
- Building the image needs KVM, so it isn't part of CI's gates.
