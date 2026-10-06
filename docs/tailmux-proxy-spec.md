# Multi-tailnet application proxy — implementation spec

**Working name:** `tsmux` (tailnet-mux; rename freely).
**Status:** design spec for a *separate* build effort (hand-off prompt at the
end of this file).
**Date:** 2026-08-12.

## 1. Why this exists

The neusis `tailscale` system module (`modules/features/tailscale/`,
`neusis.services.tailscale`) runs **one** system-wide tailnet at a time. You
can declare several *profiles* and switch the active one at runtime
(`tailscale switch`), but only one is live — a single `tailscaled` owns the
kernel `utun`, so two tailnets can't route simultaneously at the OS level
(running multiple `tailscaled` daemons is possible on Linux with
`netfilterMode=off` per-instance tun devices, but it doesn't port to macOS and
breaks exit-nodes/MSS-clamping — we deliberately abandoned that path).

`tsmux` is the **concurrent** path: an **application-level** proxy that embeds
one Tailscale node **per profile** in a single process using the
[`tsnet`](https://tailscale.com/kb/1244/tsnet) library, and routes each
connection to the correct tailnet **by hostname**. It never creates a system
VPN interface, needs no root, and leaves the official client untouched — so it
runs happily *alongside* the system tailnet. This is the model
[tailmux](https://tailmux.app/) uses; this spec is for building our own.

**Division of labour**
- **System tailnet** (`neusis.services.tailscale`): the machine's primary
  tailnet — kernel routing, full connectivity, exit-node/subnet capable. One
  active at a time; switchable.
- **`tsmux`** (this): every *other* tailnet the user needs *at the same time*,
  reachable at app level (browser/CLI/SSH via loopback proxies). Per-user,
  rootless, concurrent.

Example: `leoank` is the active system tailnet (kernel), while `cslab` and a
`work` tailnet are reachable concurrently through `tsmux`.

## 2. Architecture

```
                          ┌───────────────────────────── tsmux process ─────────────────────────────┐
  browser (PAC) ─┐        │                                                                          │
  HTTP_PROXY  ───┼──────► │  Router  127.0.0.1:43100  (HTTP CONNECT + SOCKS5)                         │
  ALL_PROXY   ───┘        │     │  hostname → owning profile (suffix match; unique; no fallback)      │
                          │     ▼                                                                     │
  PAC file  ────────────► │  ┌────────────┐   ┌────────────┐   ┌────────────┐                         │
  127.0.0.1:43180         │  │ tsnet node │   │ tsnet node │   │ tsnet node │   … one per profile     │
                          │  │  "leoank"  │   │  "cslab"   │   │   "work"   │                         │
                          │  │ Dir=…/leoank│  │ Dir=…/cslab│  │ Dir=…/work │   (own state + identity) │
                          │  └─────┬──────┘   └─────┬──────┘   └─────┬──────┘                         │
                          └────────┼────────────────┼────────────────┼────────────────────────────────┘
                                   ▼                ▼                ▼
                              leoank tailnet    cslab tailnet    work tailnet   (direct or via DERP)
```

**The hostname is the routing key.** The decision happens *while the DNS name
is still readable*, before it resolves to an IP. A name owned by one profile
never falls back to another; unmatched names are denied.

### 2.1 Components

1. **Profile manager.** For each configured profile, construct one
   `tsnet.Server`:
   ```go
   srv := &tsnet.Server{
       Hostname:   profile.Hostname,          // node name on that tailnet
       Dir:        filepath.Join(stateDir, profile.Name), // isolated state
       AuthKey:    os.Getenv(profile.AuthKeyEnv),         // agenix-provided
       ControlURL: profile.ControlURL,         // "" = Tailscale; or headscale
       Ephemeral:  false,
       UserLogf:   log.Printf,                  // prints the login URL
   }
   srv.Start()                                  // non-blocking; Up(ctx) to wait
   ```
   Each `Server` has its **own netstack, identity, MagicDNS, and state
   directory** — this is what makes concurrent tailnets work. `profile login`
   calls `Up(ctx)` (or uses the auth key) and surfaces the approval URL.

2. **Suffix router** — a loopback listener on `127.0.0.1:43100` that speaks
   **HTTP CONNECT** and **SOCKS5**. For each request it extracts the target
   **hostname**, finds the owning profile by suffix, and dials through it:
   ```go
   conn, err := owner.srv.Dial(ctx, "tcp", net.JoinHostPort(host, port))
   ```
   `tsnet`'s `Dial` resolves the name via *that node's* MagicDNS and tunnels
   the connection. Then splice bytes both ways. No owner → refuse the
   connection (configurable).

3. **PAC server** — loopback HTTP on `127.0.0.1:43180` serving `/proxy.pac`:
   known suffixes → `PROXY 127.0.0.1:43100`, everything else → `DIRECT`. Point
   the browser/system auto-proxy at `http://127.0.0.1:43180/proxy.pac`.

4. **Per-profile proxies (optional).** Each profile may also expose its own
   dedicated SOCKS5/HTTP on a derived port (`profile_socks5_proxy_base + i`)
   for tools that want to pin a single tailnet. `tsnet.Server.Loopback()`
   returns a ready-made per-node SOCKS5 + HTTP-LocalAPI listener:
   ```go
   addr, proxyCred, localAPICred, err := srv.Loopback()
   // SOCKS5 user "tsnet", password proxyCred
   ```

5. **CLI wrappers.** `run`/`env` export `HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY`
   pointing at the router for a child command; `ssh` is a bastion wrapper;
   `tunnel` binds a fixed local port to a `host:port` on the owning tailnet
   (for RDP/SMB/DB clients that ignore proxies).

### 2.2 Connection flow

1. Client issues a request with the hostname intact (PAC, `HTTP_PROXY`,
   SOCKS5-with-domain, or `tsmux connect`).
2. Router matches the hostname suffix → exactly one profile.
3. Router dials `owner.srv.Dial(host:port)`; bytes are spliced.
4. Traffic reaches the tailnet directly or via a DERP relay.

Raw-IP targets carry no ownership information → **denied by default**.

## 3. Configuration

`~/.config/tsmux/config.yaml` (mirrors tailmux's schema so its docs apply):

```yaml
router:
  http_proxy:   127.0.0.1:43100     # HTTP CONNECT + SOCKS5 (shared)
  socks5_proxy: 127.0.0.1:43100
  pac_listen:   127.0.0.1:43180     # serves /proxy.pac
  profile_http_proxy_base:   43110  # per-profile HTTP proxies start here
  profile_socks5_proxy_base: 43120  # per-profile SOCKS5 proxies start here
  profile_udp_port_base:     0      # 0 = auto WireGuard port per node

profiles:
  cslab:
    backend:      tsnet             # embedded (recommended) | tailscaled
    display_name: "CSLab mesh"
    hostname:     rogue
    auth_key_env: TSMUX_CSLAB_AUTHKEY
    control_url:  ""                # "" = Tailscale; else headscale URL
    accept_routes: false
    suffixes:     [ ".cslab.ts.net" ]   # DNS suffixes this profile owns
    match_root:   false             # also own the bare apex of a suffix
    ip_routes:    []                # advanced: explicit CIDRs → this profile
  work:
    backend:      tsnet
    display_name: "Work"
    hostname:     rogue
    auth_key_env: TSMUX_WORK_AUTHKEY
    suffixes:     [ ".corp.ts.net" ]

security:
  require_loopback_listeners: true  # refuse to bind non-loopback
  allow_cross_profile_fallback: false
  allow_ip_literals: false          # deny raw-IP targets
  allow_unknown_tsnet: false        # deny unclassified *.ts.net
```

**Validation rules:** every suffix owned by exactly one profile (overlap →
error at `config validate` / save time); listeners must be loopback when
`require_loopback_listeners`.

## 4. CLI surface

```
tsmux init                       # write starter config.yaml
tsmux config validate            # check suffix uniqueness, loopback binds
tsmux up                         # run router + PAC + all tsnet nodes (foreground)
tsmux profile login <name>       # authenticate a profile (Up(); prints URL)
tsmux profile list               # profiles + backend state
tsmux test <host>                # which profile owns <host>? (no dial)
tsmux connect <host> <port>      # raw reachability test through the owner
tsmux run -- <cmd> …             # run <cmd> with HTTP_PROXY/ALL_PROXY set
tsmux env                        # print the proxy env vars for eval $(…)
tsmux ssh <host>                 # SSH bastion to a host on any tailnet
tsmux tunnel <local> <host:port> # fixed local port → host:port on owner tailnet
tsmux diag path <url> [--netcheck]
```

## 5. Security invariants (hard requirements)

- **Loopback only.** Every router/PAC/per-profile listener binds
  `127.0.0.1`/`::1`. Refuse otherwise.
- **Unique suffix ownership.** No suffix belongs to two profiles.
- **No cross-profile fallback.** A failed dial is *not* retried on another
  profile.
- **Deny raw IP + unknown `*.ts.net`** by default (only overridable via
  explicit `ip_routes` / `allow_*` flags).
- **Isolation.** Each profile's `tsnet.Server` uses a distinct `Dir`; the
  process never reads/writes the system `tailscaled` state. No traffic bridges
  between profiles.

## 6. Neusis integration (home-manager)

`tsmux` is a **home-manager (user-level)** service — it needs no root, so it
fits the "extra HM tailnets" slot from the original design.

- **Packaging.** A Go flake package (`buildGoModule`) — add as a flake input
  or vendor under `modules/packages/tsmux/`. Declare the input in a
  `features/flake/*.nix` module (remember: `git add` new input-declaring files
  before `nix run .#write-flake`).
- **HM module** `homeModules.tsmux` (mirror the existing home modules):
  - options `neusis.services.tsmux.{enable, profiles.<name>.{hostname,
    authKeyFile, controlUrl, suffixes, …}, router.*}`.
  - render `config.yaml` from those options (`pkgs.writeText` / `settings`).
  - run `tsmux up` as a **launchd agent** (darwin) / **systemd user service**
    (Linux) — top-level keys differ per platform, so split like the system
    tailscale module (`launchd.agents` vs `systemd.user.services`) rather than
    one agnostic block.
  - auth keys via **agenix HM secrets** (the `ank` `secrets` hmBundle pattern):
    each `profiles.<name>.authKeyFile` → `config.age.secrets.<x>.path`, exported
    into the profile's `auth_key_env` by a wrapper.
- **Relationship to the system module.** Put a tailnet on *either* the system
  module (kernel, one active) *or* `tsmux` (app-level, concurrent) — not both
  for the same tailnet on the same host. Different tailnets on each is the
  whole point.

## 7. Build milestones

1. **M1 — nodes.** Config load + validate; bring up one `tsnet.Server` per
   profile; `profile login/list`. Acceptance: `profile login cslab` prints a
   URL, node appears in the cslab admin console, state persists in `Dir`.
2. **M2 — CONNECT router.** Loopback HTTP CONNECT on `:43100`; hostname→profile
   suffix match; `owner.srv.Dial`; byte splice. Acceptance:
   `HTTPS_PROXY=127.0.0.1:43100 curl https://<host>.cslab.ts.net` works;
   unknown suffix refused.
3. **M3 — SOCKS5 + PAC.** SOCKS5 (domain ATYP) on the same port; PAC on
   `:43180`. Acceptance: browser with the PAC reaches cslab hosts, everything
   else is `DIRECT`.
4. **M4 — wrappers.** `run`/`env`/`ssh`/`tunnel`/`test`/`connect`/`diag`.
5. **M5 — nix + HM.** flake package, `homeModules.tsmux`, agenix auth keys,
   launchd/systemd-user unit. Acceptance: `home-manager switch` brings it up;
   survives logout/login.
6. **M6 — hardening.** Loopback-bind enforcement, suffix-overlap rejection,
   no-fallback tests, `diag`, unit/integration tests.

## 8. Non-goals

Exit nodes / subnet routing *into* the proxy; transparent system-wide routing;
UDP association; raw-IP routing; replacing the system `tailscaled`; bridging
traffic between profiles.

## 9. Key references

- tsnet: <https://tailscale.com/kb/1244/tsnet>,
  <https://pkg.go.dev/tailscale.com/tsnet> (Server fields; `Dial`, `Loopback`,
  `Up`, `Listen`; per-`Dir` state; multiple servers per process).
- Fast user switching (why the system side is one-at-a-time):
  <https://tailscale.com/kb/1225/fast-user-switching>.
- tailmux (reference implementation + docs): <https://tailmux.app/>,
  `/docs/configuration`, `/docs/limitations`,
  `/guides/connect-to-multiple-tailscale-tailnets`.

---

## 10. Hand-off prompt (give this to the build agent)

> See `docs/tailmux-proxy-agent-prompt.md` for a self-contained prompt you can
> paste into a fresh agent working in a *new* repository.
