# ADR-0014: The fleet's binary cache is attic on spirit, reached over the tailnet, with paths signed by a neusis key

Status: accepted (not yet built: auto-updates M7)
Date: 2026-10-21 (moved to phase 2 on 2026-10-24)
Backfilled: 2026-11-03, from `auto-update-spec.md` (§8, §14) and `attic-cache-setup.md`.

## Context
With CI building every system (ADR-0012), hosts still build or download everything
themselves. A cache that CI pushes to and hosts read from removes that duplicate work.
Options in the spec (§8.2):
- harmonia / nix-serve-ng on spirit's store: tied to a shared lab store's GC, with no
  retention of its own.
- niks3 + Cloudflare R2: good for off-tailnet reads and offsite durability; a later
  step if spirit's availability becomes a problem.
- attic on ghost001 with R2 or OCI Object Storage: fully under ank's control; the
  fallback if the lab admin declined.
- Cachix or FlakeHub Cache: paid at these sizes.
- magic-nix-cache: CI-only, so hosts can't read it.
- A Cloudflare tunnel in front of spirit: unnecessary on the tailnet, and its request
  body cap is smaller than single NARs.

## Decision
- attic on spirit, set up by the lab admin: nixpkgs' `services.atticd`, SQLite plus
  local storage, zstd and content-defined chunking, 30-day retention, listening only on
  `tailscale0`. One cache, `neusis`, public-read inside the tailnet.
- Everything reaches it on `shntnu.github`. CI joins as an ephemeral node tagged
  `tag:neusis-ci`, allowed to reach only the cache port.
- CI signs paths with a neusis cache key (`nix store sign`) before `attic push`, and
  hosts trust that key, so trust doesn't depend on spirit's operator.
- oppy can later run a second, independent cache for redundancy.

## Consequences
- Phase 1 of auto-updates shipped without a cache; hosts build their own closures until
  M7.
- Open: does attic serve our own signatures in its narinfo, so hosts can trust only our
  key? (risk R8). If it doesn't, hosts trust attic's key, and spirit's operator joins the
  trust base.
- spirit's availability becomes the cache's availability.
