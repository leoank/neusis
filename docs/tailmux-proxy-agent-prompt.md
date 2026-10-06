# Agent hand-off prompt — build a multi-tailnet application proxy

Copy everything in the block below into a fresh coding agent working in a new,
empty repository. It is self-contained (does not depend on the neusis repo).

---

You are building **`tsmux`** (working name — rename if you like): a
command-line, application-level proxy that lets one machine reach services on
**several independent Tailscale tailnets at the same time**, routing each
connection to the correct tailnet **by hostname**. It runs entirely in
userspace (no root, no system VPN interface) and does not touch the official
Tailscale client, so it coexists with a normally-installed `tailscale`.

This is a clean-room reimplementation of the idea behind **tailmux**
(<https://tailmux.app/> — read `/docs/getting-started`, `/docs/configuration`,
`/docs/limitations`, and `/guides/connect-to-multiple-tailscale-tailnets`).
Match its config schema and CLI where reasonable, but write your own code.

## Language & core library

- **Go.** Use the **`tsnet`** library (`tailscale.com/tsnet`) to embed one
  Tailscale node **per profile** in a single process. Read the API first:
  <https://tailscale.com/kb/1244/tsnet> and
  <https://pkg.go.dev/tailscale.com/tsnet>.
- Key `tsnet.Server` fields: `Hostname`, `Dir` (per-node state dir — MUST be
  unique per profile), `AuthKey`, `ControlURL` (empty = Tailscale; set for
  headscale), `Ephemeral`, `UserLogf` (prints the login URL).
- Key methods: `Start()` / `Up(ctx)` (bring the node up), `Dial(ctx, "tcp",
  "host:port")` (resolves the name via *that node's* MagicDNS and tunnels — this
  is the heart of routing), `Loopback()` (per-node SOCKS5 + HTTP-LocalAPI), and
  `LocalClient()`.

## Architecture (build this)

1. **Profile manager.** For each profile in the config, create and start one
   `tsnet.Server` with its own `Dir`, `Hostname`, `AuthKey` (from an env var),
   and optional `ControlURL`. `profile login <name>` runs `Up(ctx)` and prints
   the auth URL (or consumes the auth key). Each node has its own identity,
   netstack, MagicDNS, and state — this is what makes tailnets concurrent.

2. **Suffix router** on `127.0.0.1:43100`, speaking **HTTP CONNECT** and
   **SOCKS5** (support domain targets, ATYP=3). For every request: extract the
   target **hostname**, find the single profile whose configured `suffixes`
   own it, dial `owner.Dial(ctx, "tcp", host:port)`, then splice bytes both
   ways. **The hostname is the routing key** — decide before it resolves to an
   IP.

3. **PAC server** on `127.0.0.1:43180` serving `/proxy.pac`: known suffixes →
   `PROXY 127.0.0.1:43100`, everything else → `DIRECT`.

4. **Optional per-profile proxies** on derived ports (e.g. base `43120 + i`)
   for tools that want to pin one tailnet — you can back these with
   `srv.Loopback()`.

5. **CLI** (Cobra or stdlib flags):
   `init`, `config validate`, `up` (run router + PAC + all nodes, foreground),
   `profile login <name>`, `profile list`, `test <host>` (print owning
   profile, no dial), `connect <host> <port>` (reachability test), `run -- <cmd>`
   (run a child with `HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY` set to the router),
   `env` (print those vars), `ssh <host>` (bastion), `tunnel <localPort>
   <host:port>` (fixed local port → host:port on the owning tailnet),
   `diag path <url>`.

## Configuration

`~/.config/tsmux/config.yaml`:

```yaml
router:
  http_proxy:   127.0.0.1:43100
  socks5_proxy: 127.0.0.1:43100
  pac_listen:   127.0.0.1:43180
  profile_socks5_proxy_base: 43120
profiles:
  cslab:
    hostname:     myhost
    auth_key_env: TSMUX_CSLAB_AUTHKEY   # node reads the key from this env var
    control_url:  ""
    suffixes:     [ ".cslab.ts.net" ]
    match_root:   false
  work:
    hostname:     myhost
    auth_key_env: TSMUX_WORK_AUTHKEY
    suffixes:     [ ".corp.ts.net" ]
security:
  require_loopback_listeners: true
  allow_cross_profile_fallback: false
  allow_ip_literals: false
  allow_unknown_tsnet: false
```

## Hard requirements / invariants

- **Loopback only.** All listeners bind `127.0.0.1`/`::1`; refuse otherwise.
- **Unique suffix ownership** — reject overlapping suffixes at
  `config validate` / save time.
- **No cross-profile fallback** — a failed dial is never retried on another
  profile.
- **Deny raw-IP targets and unknown `*.ts.net`** by default.
- **Isolation** — distinct `Dir` per profile; never read/write the system
  `tailscaled` state; never bridge traffic between profiles.

## Milestones (ship in order, with tests)

1. Config load + validate; bring up one `tsnet.Server` per profile;
   `profile login/list`. *Done when:* `profile login cslab` prints a URL, the
   node appears in that tailnet's admin console, and state persists in `Dir`.
2. HTTP CONNECT router on `:43100` with hostname→profile matching + `Dial` +
   splice. *Done when:* `HTTPS_PROXY=127.0.0.1:43100 curl https://<host>.cslab.ts.net`
   succeeds and an unknown suffix is refused.
3. SOCKS5 (domain targets) on the same port + PAC on `:43180`. *Done when:* a
   browser using the PAC reaches cslab hosts and everything else is `DIRECT`.
4. `run`/`env`/`ssh`/`tunnel`/`test`/`connect`/`diag`.
5. Packaging: a `flake.nix` with a `buildGoModule` package + a runnable binary;
   a systemd-user unit (Linux) and a launchd agent (macOS) example that runs
   `tsmux up`.
6. Hardening: enforce loopback binds, reject suffix overlap, prove
   no-fallback, add unit + integration tests.

## Non-goals

Exit nodes; subnet routing into the proxy; transparent system-wide routing;
UDP association; raw-IP routing; replacing the system `tailscaled`.

## Deliverables

A Go module with the CLI above, a `README` documenting install/config/usage, a
`flake.nix` (package + dev shell), and tests for the router's hostname matching
and the loopback/no-fallback invariants.
