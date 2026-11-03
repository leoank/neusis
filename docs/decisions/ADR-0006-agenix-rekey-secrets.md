# ADR-0006: Secrets use agenix-rekey with a master identity kept outside the repo, rekeyed files committed per host, and cloud host keys generated ahead of the host

Status: accepted
Date: 2026-08-12 (pre-generated cloud host keys from 2026-10-19)
Backfilled: 2026-11-03, from `porting.md` (2026-08-12 *agenix-rekey on darwin + home*,
2026-10-19 M4 ghost001) and `cloud-terranix-spec.md` §6.

## Context
v1 used plain agenix with a `secrets.nix` rules file listing each secret's recipients.
With ADR-0002 that rules file was itself loaded as a module and broke the flake, and
every new host would have meant re-encrypting secrets to its key by hand. The new
tree already declared agenix-rekey, wired for NixOS only and enabled nowhere. Other
alternatives were not recorded.

## Decision
- Secrets are `.age` files under `modules/secrets/` (`common/`, `<user>/`), encrypted to
  ank's master identity. agenix-rekey re-encrypts them for each host into
  `modules/secrets/rekeyed/<host>/`, which is committed. No rules file: recipients come
  from `age.rekey`.
- The master identity is given as `{ identity = "<path>"; pubkey; }`: the private key
  is read at rekey time and never enters the repo or the store.
- A cloud host's SSH host key is generated on the operator machine before the instance
  exists. The private half is stored age-encrypted under
  `modules/secrets/bootstrap/<host>/`, and the public half is the machine's
  `hostPubkey`, so `agenix rekey` can run before the host boots.
- Edits go through `agenix edit`, then `agenix rekey`. Plaintext is never committed or
  printed.

## Consequences
- Adding a host is `hostPubkey` + `agenix rekey`; no secret has to be re-encrypted by
  hand.
- A host evaluates only once its `rekeyed/<host>/` exists, so a new host's checks fail
  until the first rekey.
- Home secrets that decrypt with ank's private key are left off servers, which don't
  carry it (ghost001's home is the headless subset).
