# Attic binary cache on spirit — setup guide for the lab admin

**Audience:** the administrator of `spirit` and `oppy` (NixOS, on the
`shntnu.github` tailnet). Ankur doesn't manage these machines; this is
what he is asking for and how to do it.

**Why:** Ankur's machines (neusis fleet) are moving to automatic updates.
CI builds each machine's new system every day and pushes the result to a
binary cache. Each machine then *downloads* its update instead of
compiling it. Context: `docs/auto-update-spec.md` §8 in
github.com/leoank/neusis.

**What it costs the lab machine:**
- One small service (`atticd`, a Rust HTTP server with SQLite).
- About **200 GB of disk** to start. Old entries expire after 30 days.
  The cache only ever holds rebuildable build outputs, so it needs no
  backups.
- Light network traffic, over Tailscale only.

Nothing else on the machine changes. It doesn't touch the Nix daemon,
the builders or users.

**The ask, in short:**

1. Add the NixOS snippet below to **spirit** and rebuild (§1). `oppy` is
   optional (§6).
2. Create the server secret once (§2).
3. Mint two tokens and send them to Ankur, encrypted to his SSH key (§3).
4. Create a Tailscale OAuth client for Ankur's CI, limited to one tag
   that can only reach `spirit:8080` (§4).

---

## 1. NixOS configuration

Drop this into spirit's configuration (for example as `attic.nix`, then
import it). It uses the upstream `services.atticd` module from nixpkgs
(present in 24.11 and later, and checked against 26.05).

```nix
# attic.nix — binary cache for the neusis fleet (Ankur).
{ ... }:
{
  services.atticd = {
    enable = true;

    # Holds ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64 (step 2). Stays out of
    # the Nix store. Point this at your secret manager's output instead
    # (sops-nix, agenix, …) if you use one.
    environmentFile = "/var/lib/secrets/atticd.env";

    settings = {
      listen = "[::]:8080";
      jwt = { };

      # The module defaults are fine and listed here for clarity:
      # SQLite at /var/lib/atticd/server.db, NARs under
      # /var/lib/atticd/storage, content-defined chunking (so daily
      # rebuilds of the same system share most of their bytes).
      compression.type = "zstd";

      # Expire anything not pushed again within 30 days; run every 12 h.
      garbage-collection = {
        interval = "12 hours";
        default-retention-period = "30 days";
      };
    };
  };

  # Only over Tailscale, never on the LAN or the internet.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8080 ];
}
```

**Putting the data on a bigger disk.** The unit runs with
`DynamicUser = true`, so its state actually lives in
`/var/lib/private/atticd`. The simplest way to move it is to bind-mount
a directory from the data disk there, without changing `storage.path`:

```nix
fileSystems."/var/lib/private/atticd" = {
  device = "/data/atticd";        # any directory on the big disk
  options = [ "bind" ];
};
```

Run `sudo mkdir -p /data/atticd` before the rebuild. systemd fixes the
ownership on start.

Apply with your usual `nixos-rebuild switch`. Then confirm the service
is running:

```bash
systemctl status atticd
curl -s http://localhost:8080/ | head -1      # any HTTP answer is fine
```

## 2. Server secret (once)

atticd signs its access tokens with an RSA key read from the environment
file:

```bash
sudo install -d -m 700 /var/lib/secrets
printf 'ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64="%s"\n' \
  "$(openssl genrsa -traditional 4096 | base64 -w0)" \
  | sudo tee /var/lib/secrets/atticd.env >/dev/null
sudo chmod 600 /var/lib/secrets/atticd.env
sudo systemctl restart atticd
```

If this file is lost, every token becomes invalid. Mint new ones (§3);
the cached data is unaffected.

## 3. Tokens for Ankur

The module installs an `atticd-atticadm` wrapper. Two tokens, both
limited to caches named `neusis*`:

```bash
# Ankur's owner token: create, configure and clean up his caches.
sudo atticd-atticadm make-token --sub ankur --validity '1y' \
  --pull 'neusis*' --push 'neusis*' --delete 'neusis*' \
  --create-cache 'neusis*' --configure-cache 'neusis*' \
  --configure-cache-retention 'neusis*' --destroy-cache 'neusis*' \
  > ankur.token

# CI push token: pull + push only, stored as a GitHub Actions secret.
sudo atticd-atticadm make-token --sub neusis-ci --validity '1y' \
  --pull 'neusis*' --push 'neusis*' \
  > neusis-ci.token
```

Send them **encrypted to Ankur's SSH key**. `age` (in nixpkgs) can
encrypt to an SSH public key directly:

```bash
tar c ankur.token neusis-ci.token \
  | nix shell nixpkgs#age -c age \
      -r "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH40XzfXPtcTwJ8FHxHXCaEteylFOwtuw5TaY5CZ5NS" \
      -o neusis-attic-tokens.tar.age
shred -u ankur.token neusis-ci.token
```

Send `neusis-attic-tokens.tar.age` over any channel. Only Ankur's private
key can open it.

Tokens expire after a year. To rotate, rerun the two commands and send
the new ones. To revoke everything at once, replace the server secret
(§2).

## 4. Network: who needs to reach port 8080

All of Ankur's devices live on the `shntnu.github` tailnet. The ones
that need to reach the cache:

| Client | Access |
|---|---|
| `rogue` (Ankur's Mac) | already reaches spirit |
| `ghost001` (Ankur's cloud VM) | joins `shntnu.github` with the lab's existing auth key, like rogue |
| GitHub Actions jobs | **ephemeral** nodes tagged `tag:neusis-ci`, joined with an OAuth client (below) |

**Requested: an OAuth client for CI.** In the admin console for
`shntnu.github`:

1. Policy file: declare the tag and grant it access to the cache only.

   ```jsonc
   "tagOwners": {
     "tag:neusis-ci": ["autogroup:admin"],
   },
   // with "acls":
   { "action": "accept", "src": ["tag:neusis-ci"], "dst": ["spirit:8080"] },
   // or, with "grants":
   { "src": ["tag:neusis-ci"], "dst": ["spirit"], "ip": ["tcp:8080"] },
   ```

   If your policy names hosts by tag or IP rather than by MagicDNS name,
   use spirit's tag or its `100.x` address in `dst`.

2. **Settings → OAuth clients → Generate**, with scope **Auth Keys:
   write**, restricted to tag `tag:neusis-ci`. Send the client ID and
   secret to Ankur encrypted, like the tokens (§3). The workflow mints
   a short-lived *ephemeral* key per job, so the nodes disappear when
   the job ends.

Tagged nodes can reach nothing except `spirit:8080`. If oppy later runs
a second cache (§6), add `oppy:8080` to the same rule.

Not needed: a public port, a Cloudflare tunnel, a DNS name, or TLS.
Tailscale already encrypts the traffic.

## 5. What Ankur does afterwards (no admin action)

```bash
attic login lab http://spirit.tail5e510f.ts.net:8080 "$(cat ankur.token)"
attic cache create neusis
attic cache configure neusis --public   # readable without a token, still Tailscale-only
attic cache info neusis                 # → public key for the hosts' trusted-public-keys
```

From then on, CI pushes with `neusis-ci.token`, and Ankur's machines add
the cache as a substituter, falling back to building whenever it's
unreachable.

## 6. Optional: oppy as a second cache

spirit and oppy are identical, so the same `attic.nix` works on oppy
unchanged. Repeat §2 and §3 there. This gives a **second, independent**
cache (it shares no state with spirit). CI can push to both, and the
hosts list both as substituters, so one machine being down costs
nothing. It isn't needed to start; spirit alone is enough.

## 7. Operating it

| Task | Command |
|---|---|
| Logs | `journalctl -u atticd -f` |
| Disk used | `sudo du -sh /var/lib/private/atticd` |
| Shorter retention if disk is tight | Ankur: `attic cache configure neusis --retention-period '14 days'`, or the admin: `default-retention-period` |
| Stop serving | `services.atticd.enable = false;` and rebuild |
| Remove completely | Do the above, then `sudo rm -rf /var/lib/private/atticd /var/lib/secrets/atticd.env` |

Nothing else on the machine depends on atticd, and nothing else depends
on the cache being up. If it's down, Ankur's machines just build or
download from cache.nixos.org as they do today.
