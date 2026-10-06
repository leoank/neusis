# Secrets

neusis manages secrets with
[agenix-rekey](https://github.com/oddlama/agenix-rekey). You encrypt each
secret once to your **master identity**. `agenix rekey` then re-encrypts it
for every host that needs it, using the host's `hostPubkey`, and commits the
result under `secrets/rekeyed/<host>/`. The rekeyed files can decrypt only
on that host, so builds stay pure and CI can build them.

## Set up

```sh
neusis add secrets --master-identity ~/.ssh/id_ed25519 \
                   --master-pubkey "$(cat ~/.ssh/id_ed25519.pub)"
```

(Or pass `--secrets` to `neusis init`.) This records your master identity
in `secrets/master-identities.nix`. Machines you add with
`neusis add machine` from then on get the
[`neusis.services.secrets`](../reference/system-modules/secrets.md) block
wired to your repo's storage directory and identity.

Give the identity as a **string path**, not a Nix path literal, so the
private key is read when you run `agenix rekey` and is never copied into
the Nix store.

## Add a secret

```sh
neusis add secrets my-token    # prints the steps for this secret
agenix edit secrets/common/my-token.age
agenix rekey
git add secrets/
```

Then use it on a machine:

```nix
age.secrets.my-token.rekeyFile = ../../secrets/common/my-token.age;
```

## Initial passwords on NixOS

Each NixOS host with login users (admins, regulars, guests) **must** set
[`initialHashedPassword`](../reference/flake-schema.md#opt-flake-neusis-machines--name--initialHashedPassword)
to an agenix secret that holds a password hash (`mkpasswd -m sha-512`).
There's deliberately no default. A hidden default would set up accounts
from a secret you can't decrypt. `mkNeusisOS` stops with an error that tells
you what to set. On darwin, `initialHashedPassword` is ignored.

## Home-manager secrets

User-level secrets work the same way through
[`homeModules.secrets`](../reference/home-modules/secrets.md), keyed by the
user's own public key.
