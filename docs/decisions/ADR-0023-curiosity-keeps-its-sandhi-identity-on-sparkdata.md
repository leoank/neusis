# ADR-0023: curiosity keeps ank's sandhi identity on SPARKDATA, restored in the initrd and saved back whenever it changes

Status: proposed
Date: 2026-11-27

## Context
curiosity is a live disk (ADR-0020): nothing on it survives a reboot. Its sandhi dutavas
(ADR-0021) therefore joined leoank as a new device on every boot. Made ephemeral so the old
ones would go, it still took `sandhi-curiosity-2` behind devices from earlier boots, and
`sandhi-curiosity.leoank` dialled an offline one (sandhi EXP-20261127-hsprp3). The runxi
system tailnet solves the same churn by deleting offline devices that hold the name
(`deleteOfflineConflicts`, through an OAuth client).

sandhi EXP-20261127-j1rwdg checked that a dutavas started from a copy of its
`tailscaled.state` alone, with no auth key, comes back as the same device, provided it is
not ephemeral (an ephemeral one did not resume).

Alternatives: claim the name through the tailnet API at each boot, as the system tailnet
does (another OAuth client per tailnet, and still a new device per boot); keep sandhi's
whole state directory on SPARKDATA (exFAT, mounted root-only because it holds the host key,
so ank's service cannot write there).

## Decision
- SPARKDATA holds `config/curiosity/sandhi/leoank/tailscaled.state`, root-only like the
  host key beside it.
- The initrd's host-key script also copies it, when present, to `/var/lib/sandhi-ank/leoank/`
  in the root it switches to; tmpfiles hands `/var/lib/sandhi-ank` to ank in sysinit, before
  any user session, so sandhi always starts from it.
- A path unit saves the file back to SPARKDATA whenever tsnet rewrites it; the first join
  of a boot without a saved identity is saved that way too. The same save also runs once at
  boot and at activation, for an identity that is not rewritten.
- curiosity's sandhi uses `stateDir = /var/lib/sandhi-ank` and is not ephemeral.

## Consequences
- curiosity keeps one leoank device and its name across reboots.
- It takes effect once an ISO built with it is on the stick: a boot runs the ISO's
  configuration until comin switches.
- The saved node key sits on SPARKDATA with the host key; whoever has the drive can be
  curiosity on leoank, as they can already decrypt its secrets.
- The identity already on curiosity (in `~/.local/state/sandhi`) is moved to
  `/var/lib/sandhi-ank` by hand, once, before this configuration reaches it; otherwise the
  switch joins a new device behind the old name.
- A boot without SPARKDATA joins anew with the key and, since saving fails, joins anew again
  at the next boot.
