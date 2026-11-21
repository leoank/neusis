# ADR-0021: Concurrent tailnets come from sandhi, a DNS server and proxy in its own repo, not the tsmux proxy

Status: accepted (supersedes ADR-0008's application-level proxy; the rest of ADR-0008 stands)
Date: 2026-11-21

## Context
ADR-0008 left concurrent tailnets to a tsnet-based application proxy, specified as tsmux
in `docs/tailmux-proxy-spec.md`: loopback SOCKS5, HTTP CONNECT and a PAC file, reaching out
only, per user. It was never built. In November 2026 the fleet moved from `shntnu.github`
to `runxi-shen.github` and saarthi's hub to `leoank`; every machine was switched by hand,
in order, with comin and saarthi broken in between. A proxy that only proxy-aware programs
use, and that cannot publish a machine into a tailnet, would not have spared any of that.

## Decision
- The concurrent path is **sandhi** (`github:leoank/sandhi`, its own repo and yajna
  notebook), designed in its ADR-0001 to ADR-0004: tailnet backends, each with a
  **dutavas** (an embassy: the machine's identity on that network, here an embedded tsnet
  identity from saarthi's crate, copied), a router, and front ends: `sandhi connect` for ssh's
  `ProxyCommand`, inbound forwards that publish a machine's services into tailnets it is not
  on, then DNS answering each tailnet's real domain with a loopback address per peer, then
  a TUN.
- The tsmux spec is kept as history; nothing is built from it.
- neusis consumes sandhi as a flake input with a home-manager module once its phase 1
  lands, auth keys as agenix secrets.

## Consequences
- The system tailnet becomes optional per machine; a machine may stay on one tailnet for
  good while sandhi carries the rest.
- Every machine joins every tailnet it uses through sandhi as a device of its own, so
  auth keys multiply; neusis has to mint or share them without hand rotation.
- sandhi never answers for the system tailnet's domain, so the `/etc/resolver/ts.net`
  that tailscaled installs on darwin keeps working beside it.
