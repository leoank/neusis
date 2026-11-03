# ADR-0008: A host runs one system-wide tailnet with switchable profiles; concurrent tailnets are left to an application-level proxy

Status: accepted
Date: 2026-08-16
Backfilled: 2026-11-03, from `porting.md` (2026-08-16 *Design decisions (with
rationale)*) and `tailmux-proxy-spec.md` §1.

## Context
Machines need to reach more than one tailnet: ank's personal `leoank` tailnet and the
`shntnu.github` lab mesh. The approach looked at first, a reference gist running several
`tailscaled` daemons through a systemd template with per-instance tun devices and
`netfilterMode=off`, is Linux- and root-only. It doesn't port to macOS (where the hosts
were) or to home-manager, and it breaks exit nodes and MSS clamping. The scope was
changed mid-task to drop it.

## Decision
- `agnosticModules/tailscale` (`neusis.services.tailscale`) runs one `tailscaled` with
  several declared **profiles**. A required `defaultProfile` connects at boot, and the
  `neusis-ts-<name>` commands switch between profiles at runtime (Tailscale's
  fast user switching).
- Each tailnet's profile and secrets live in their own config-only feature
  (`features.agnostic.ank_mesh`, `cslab_mesh`). `ank_mesh` wins the default at normal
  priority when both are imported.
- No home-manager tailscale module. Reaching several tailnets at once is the job of a
  separate tsnet-based proxy (`tailmux-proxy-spec.md`), built as its own project.

## Consequences
- Only one tailnet is live per host. The 2026-10-22 auto-update decision later put every
  device and CI on `shntnu.github`, so the fleet rarely needs to switch.
- Profiles are runtime state in `tailscaled.state`, so they're created on first use
  rather than declared.
- Both platforms run neusis's own autoconnect (a systemd oneshot or launchd daemon), so
  nickname and force-claim sequencing are identical everywhere.
