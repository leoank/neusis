# Cloud machines with terranix — architecture

Status: **decided** (2026-10-16; decisions in §12). Build plan: `docs/cloud-terranix-plan.md`.
Once this is locked in, it gets turned into a milestone plan; decisions
taken during review are recorded in §12 and, as work lands, in
`docs/porting.md`.

Goal: create and manage cloud machines from neusis as code. The
infrastructure (network, image, instance) is described in Nix with
terranix; the operating system on the machine is a NixOS image built
from a config in this repo; the host's real configuration, secrets and
updates come from the same flake for the machine's whole life. The first
target is **Oracle Cloud Infrastructure (OCI)**, on an Ampere A1
(aarch64-linux) instance.

---

## 1. What terranix gives us (and what it doesn't)

terranix (github.com/terranix/terranix, v2.9.0 plus unreleased `main`
as of 2026-09) is a Nix → Terraform JSON generator. A terranix
configuration is a module-system evaluation whose `config` is serialised
to `config.tf.json`; Terraform or OpenTofu then runs against that file.

Relevant surface, read from the source:

| Piece | What it does |
|---|---|
| `lib.terranixConfiguration { system \| pkgs, modules, extraArgs }` | Builds the `config.tf.json` derivation. `passthru` carries the evaluated config. |
| `lib.evalTerranixConfiguration { … }` | Same evaluation without building anything: returns `{ config; _meta; }`. **This is what our nix-unit tests use.** |
| `flakeModule` (flake-parts) | `perSystem.terranix.terranixConfigurations.<name> = { modules; extraArgs; workdir; terraformWrapper = { package; extraRuntimeInputs; prefixText; suffixText; }; }` |
| …its outputs | `packages.<sys>.<name>`: an app that runs `init` + `apply`; `passthru.{init,plan,apply,destroy}` so `nix run .#<name>.plan` works; `passthru.terraform` is the wrapped binary for arbitrary subcommands; `devShells.<sys>.<name>` (toggle with `terranix.exportDevShells`). |
| Core modules | Arbitrary `resource`/`data`/`provider`/`terraform`/`output`/`variable`/`locals`/`moved`/`removed`/`import`/`ephemeral` blocks, `backend.*` helpers, `lib.tf.ref`, and (unreleased) NixOS-style `assertions`/`warnings`. |

What it **doesn't** do, which shapes the design:

- **No state management.** State lives wherever the Terraform backend
  puts it. The flake-module's wrapper `mkdir -p <workdir> && cd <workdir>`
  — and `workdir` is **relative to the caller's cwd**, so the apps must
  run from the repo root.
- **No secret handling.** Provider credentials and state encryption keys
  have to be provided by us (the `prefixText` hook is the place).
- **No knowledge of NixOS.** Getting a NixOS system onto the instance and
  keeping it updated is our job; terranix only creates cloud resources.
- **Provider schemas aren't typed.** Resource attributes are freeform; a
  typo in an OCI attribute only shows up at `tofu validate`/`plan` time.
  We compensate with thin typed neusis modules on top (§4.3) and a
  `tofu validate` check (§10).

## 2. Where neusis is today (the constraints)

- Dendritic flake: every `modules/**.nix` is a flake-parts module,
  imported by import-tree; `_`-prefixed paths are skipped; inputs are
  declared next to their use with `flake-file.inputs` and `flake.nix` is
  generated.
- A machine is `flake.neusis.machines.<host>` (`system`, `hostPubkey`,
  `module`, `userRegistries`, `initialHashedPassword`, …) and is built
  because a lab registry lists it:
  `flake.neusis.registry.machines.anklab.{nixos,darwin}`.
  `modules/deploy.nix` → `mkNeusisFlake` → `nixosConfigurations.<host>`.
- **There is no NixOS host in the fleet right now** (only `rogue`,
  `darwin001`). The NixOS path (`mkNeusisOS`, role-based users,
  `initialHashedPassword`, home-manager wiring) is exercised only by the
  test fixture and the T3 VM tests. The OCI machine will be the first
  real NixOS host on the new tree.
- Secrets: agenix-rekey with a master identity
  (`~/.ssh/id_ed25519`, string path), per-host rekeyed files under
  `modules/secrets/rekeyed/<host>/`, host identity = `hostPubkey` in the
  machine registry. agenix-rekey picks up every `nixosConfigurations`
  entry automatically (`features/flake/agenix-rekey.nix`).
- Remote bootstrap tooling already exists: `neusis anywhere`
  (`cli/internal/anywhere`, ported from `scripts/anywhere.py`) decrypts
  a tree of `.age` files (e.g. `etc/ssh/ssh_host_ed25519_key.age`) into
  a root-shaped folder and hands it to nixos-anywhere `--extra-files`.
- Builders: spirit/oppy (x86_64 + aarch64-linux, big) and rogue's
  linux-builder (aarch64-linux). Building an aarch64-linux disk image
  from rogue already works through these.
- Mesh: tailscale via `agnosticModules/tailscale` + `features/agnostic/ank_mesh`,
  auth key from `secrets/common/persistent_tsauthkey.age`.
- Testing ladder T0–T3 (`docs/testing.md`), tests mirror module paths
  under `modules/tests/`.
- Conventions: reusable modules vs opinionated features; opt-in per
  machine/user; personal tools and credentials live in the user's home
  bundle.

## 3. Design principles for cloud machines

1. **A cloud machine is a normal neusis machine.** Its NixOS config is
   `flake.neusis.machines.<host>` + a registry entry, built by
   `mkNeusisFlake` like any other. Nothing about users, secrets, mesh or
   features is cloud-special. The cloud part is only *where it runs* and
   *how it first boots*.
2. **Two planes, one source of truth.** The *infrastructure plane*
   (terranix → OpenTofu → OCI API) creates and destroys resources. The
   *OS plane* (NixOS config → image / `nixos-rebuild`) decides what runs
   on them. The infra plane reads machine facts from the registry
   (`system`, `hostname`); it never re-declares them.
3. **Infrastructure changes and OS changes must not trigger each other.**
   Changing a package on the host must never plan an instance
   replacement; changing a security rule must never rebuild an image.
4. **Reusable vs opinionated, as everywhere else.** Provider-level
   terranix modules (an "OCI NixOS instance", "OCI network", "encrypted
   state") are library outputs consumers can use; the concrete stack
   (*my* tenancy, *my* VCN, *my* machines) is fleet config.
5. **Secrets never enter the store, the image, the OCI metadata, or
   plaintext state.**
6. **Applies are human-initiated.** CI may plan/validate; it never applies.

## 4. Architecture

### 4.1 The big picture

```
                      neusis flake (this repo)
 ┌──────────────────────────────────────────────────────────────────────┐
 │ flake.neusis.machines.ghost001 ─┬─► nixosConfigurations.ghost001          │
 │   (system, hostPubkey, module) │      (mkNeusisFlake, users, agenix,   │
 │                                │       tailscale, features.nixos.      │
 │                                │       oci-guest)                      │
 │                                │                                       │
 │ features.nixos.oci-guest ──────┼─► packages.aarch64-linux.             │
 │   (OCI hardware profile)       │      oci-base-image  (qcow2)          │
 │                                │            │ store path               │
 │ terranixModules.oci-* ─────────┴────────────┼──────────┐               │
 │ (reusable, typed)                           ▼          ▼               │
 │                          terranixConfigurations:  oci-images   oci-anklab
 │                          (perSystem, flake-module) bucket+image  VCN+instances
 └──────────────────────────────────────────┬──────────────┬────────────┘
                                            │ nix run .#… (OpenTofu,
                                            │  creds + state key from
                                            │  the operator's agenix)
                                            ▼              ▼
 ┌─────────────────────────── OCI tenancy ──────────────────────────────┐
 │ Object Storage: neusis-images/oci-base-aarch64-<hash>.qcow2           │
 │ Custom image (QCOW2, A1-compatible) ─────────► Instance ghost001        │
 │ VCN / subnet / IGW / security list / reserved IP ─┘  (boots base image)│
 └───────────────────────────────────────────────────────────┬──────────┘
                                                             │
                 neusis cloud bootstrap ghost001  ─────────────┘
                 (push pre-generated host key, nixos-rebuild switch
                  --flake .#ghost001 → host config, agenix, tailscale)
                                                             │
                 day 2: nixos-rebuild switch --target-host ghost001 (tailnet)
```

### 4.2 Infrastructure tool: OpenTofu through the terranix flake-module

- **Engine: OpenTofu** (`pkgs.opentofu`, 1.11 in nixpkgs 26.05) rather
  than Terraform (1.15, BSL-licensed). The deciding feature is
  OpenTofu's native **client-side state encryption** (since 1.7),
  which lets us keep state somewhere simple without leaking secrets
  (§6). The terranix flake-module supports OpenTofu directly
  (`terraformWrapper.package = pkgs.opentofu.withPlugins …`).
- **Providers pinned by Nix:** `pkgs.opentofu.withPlugins (p: [ p.oracle_oci ])`
  (OCI provider v8.14.0 in 26.05). No registry downloads at `init`, and
  the provider version moves with `nixpkgs`, which keeps the "one lock
  file" story.
- **Use the upstream flake-module**, imported from a flake feature, not a
  hand-rolled wrapper. It already gives `plan`/`apply`/`destroy` apps and
  dev shells. We add neusis defaults (engine, plugins, the secret-loading
  `prefixText`, a "run from repo root" guard) in one place so every
  stack inherits them.

### 4.3 New code, by layer

| Layer | Location (proposed) | Exposed as | Kind |
|---|---|---|---|
| Input + flake-module glue + neusis defaults | `modules/features/flake/terranix.nix` | (imports `inputs.terranix.flakeModule`) | flake feature |
| Typed option for terranix modules | `modules/lib/neusis-options.nix` | `flake.terranixModules.<name>` (`lazyAttrsOf deferredModule`, like `agnosticModules`) | schema |
| Reusable terranix modules | `modules/terranixModules/{state-encryption,oci/provider,oci/network,oci/image,oci/instance}.nix` | `flake.terranixModules.*` | library |
| OCI guest hardware profile (NixOS) | `modules/features/nixos/oci-guest.nix` | `flake.neusis.features.nixos.oci-guest` | feature |
| Base image | `modules/images/oci-base.nix` | `packages.<linux>.oci-base-image` | package |
| The machine | `modules/machines/ghost001.nix` + `registry/machines/anklab.nix` (`nixos = [ … ]`) | `nixosConfigurations.ghost001` | fleet config |
| The stacks | `modules/infra/oci-images.nix`, `modules/infra/oci-anklab.nix` | `perSystem.terranix.terranixConfigurations.*` → `packages.<sys>.oci-*` | fleet config |
| Operator credentials | `modules/users/ank/…` (HM agenix secret + `~/.oci/config`) | — | user bundle |
| Bootstrap command | `cli/` (`neusis cloud bootstrap`) | `packages.<sys>.neusis` | CLI |
| Tofu working dirs (state, lock) | `infra/<stack>/` (repo root, not under `modules/`) | — | data |
| Tests | `modules/tests/{terranixModules,infra,images,features/nixos,machines}/…` | `tests.*`, `checks.*` | tests |

**Typed neusis layer over raw resources.** Stacks don't write raw
`resource.oci_core_instance` blocks. They set small typed options, and
the reusable modules expand them into resources, for example:

```nix
# modules/infra/oci-anklab.nix  (sketch, not final API)
{ self, ... }:
{
  perSystem = { pkgs, ... }: {
    terranix.terranixConfigurations.oci-anklab = {
      workdir = "infra/oci-anklab";
      modules = with self.terranixModules; [
        state-encryption oci-provider oci-network oci-instance
        {
          neusis.oci = {
            profile = "neusis";                 # ~/.oci/config profile
            compartment = "ocid1.compartment…";
            network.anklab = { cidr = "10.42.0.0/16"; publicSsh = true; };
            instances.ghost001 = {
              machine = self.neusis.machines.ghost001; # hostname, system
              network = "anklab";
              shape = { name = "VM.Standard.A1.Flex"; ocpus = 4; memoryGb = 24; };
              bootVolumeGb = 100;
              image = "oci-base-aarch64";        # looked up by name (§5.2)
              reservedIp = true;
            };
          };
        }
      ];
    };
  };
}
```

The instance module derives `display_name`/hostname from the machine
and asserts consistency (via terranix `assertions`): an `aarch64-linux`
machine must get an A1 (Arm) shape, and an `x86_64-linux` one an x86
shape. That check is cheap and catches the most expensive mistake.

**No change to `machineType`.** Cloud placement stays out of the
machine schema for now. The machine def stays provider-agnostic, and the
stack points at the machine, not the reverse. If we later need the
machine to know its deploy address, we add an optional field then.

### 4.4 The OS plane: one hardware profile, two uses

nixpkgs 26.05 ships the pieces we need:
`nixos/modules/virtualisation/oci-common.nix` (kernel params for the
OCI serial/VNC consoles, `growPartition`, ext4 root by label `nixos`,
ESP by label, GRUB EFI as removable, OCI NTP, `qemu-guest` profile,
networkd) and `oci-image.nix` (qcow2 via `make-disk-image`, UEFI by
default, plus a `fetch-ssh-keys` unit that pulls root's
`authorized_keys` from IMDSv2). It's also reachable as
`system.build.images.oci`.

- `features.nixos.oci-guest` = imports `oci-common.nix` (+ any neusis
  tweaks, such as serial-console getty and `boot.loader.timeout`). Both
  the base image config and every OCI host config import it, so a
  `nixos-rebuild switch` from base → host keeps the same
  filesystems/bootloader. **This invariant is what makes the base-image
  approach safe**, and it gets a T0 test: the host's `fileSystems."/"`
  and `boot.loader` match the base image's.
- **Base image** (`packages.aarch64-linux.oci-base-image`, later
  `x86_64-linux` too): `nixpkgs.lib.nixosSystem` with
  `oci-image.nix` + `oci-guest` + the neusis nix settings, sshd on,
  root login by key only (keys from IMDS). No users, no agenix, no
  tailscale, no secrets, so it's host-independent and safe to sit in
  object storage. Deliberately **not** in `nixosConfigurations` (that
  would put a secrets-less "host" in agenix-rekey's host list and in T1
  as a machine).
- **Host config** (`nixosConfigurations.ghost001`): ordinary neusis
  machine, plus `oci-guest`, agenix + `nixosModules.secrets`, tailscale +
  `ank_mesh`, users from `registry.users.anklab`, and an
  `initialHashedPassword`, which `mkNeusisOS` requires once there are
  login users.

## 5. Lifecycle

### 5.0 One-time account setup (manual, documented)

1. OCI tenancy; pick the home region (Always Free A1 capacity lives in
   the home region only). Strongly consider upgrading to
   **Pay-As-You-Go**: you're still free within Always Free limits, but
   PAYG avoids idle-instance reclamation and usually gets A1 capacity
   ("Out of host capacity" is common on free accounts).
2. Create a compartment for neusis, plus an IAM user/group with a policy
   scoped to it (manage instance-family, virtual-network-family,
   object-family, volume-family in that compartment). Generate an API
   signing key.
3. Store the API private key as an agenix secret in ank's home bundle.
   HM decrypts it to `~/.oci/neusis_api_key.pem` and writes a
   `~/.oci/config` profile `[neusis]` (tenancy/user OCID, fingerprint,
   region, key_file). The OCI provider uses `config_file_profile =
   "neusis"`, and the `oci` CLI works with the same profile. This follows
   the "personal credentials live in the user bundle" rule. The flake
   itself never sees the key.
4. Generate the OpenTofu state-encryption passphrase, also as an HM
   agenix secret (§6).

### 5.1 Define the machine (in git, before anything exists)

1. `modules/machines/ghost001.nix` + add it to `registry.machines.anklab.nixos`.
2. **Pre-generate the host SSH key** on the operator machine
   (`ssh-keygen -t ed25519`). The private half goes in as
   `modules/secrets/bootstrap/ghost001/etc/ssh/ssh_host_ed25519_key.age`
   (encrypted to the master identity, the same root-shaped layout that
   `neusis anywhere` already understands). The public half is the
   machine's `hostPubkey`.
3. `agenix rekey`. The host's secrets (tailscale auth key, initial
   password, …) are rekeyed for `ghost001` **before the instance exists**.
   This removes the classic "boot → keyscan → edit registry → rekey →
   redeploy" two-commit dance.
4. T0/T1 green: the host config evaluates, and the stacks evaluate.

### 5.2 Bake the image — stack `oci-images`

`nix run .#oci-images.plan` / `.apply`:

- Building `config.tf.json` depends on `oci-base-image` (its store path
  is in the JSON), so Nix builds the aarch64-linux qcow2 through the
  remote/linux builders first. **The image in the cloud is exactly the
  derivation in the repo.**
- Resources: an Object Storage bucket; `oci_objectstorage_object` that
  uploads the qcow2 (object name carries the store hash, e.g.
  `oci-base-aarch64-<hash>.qcow2`); `oci_core_image` imported from it
  (`source_image_type = "QCOW2"`, `launch_mode = "PARAVIRTUALIZED"`,
  display name `oci-base-aarch64`, freeform tags carrying the store
  hash + nixpkgs rev); `oci_core_shape_management` to mark it
  compatible with `VM.Standard.A1.Flex`; and, if the spike shows it's
  needed, an image capability schema forcing UEFI firmware.
  `create_before_destroy` so a new image exists before the old one goes.
  Image import takes ~10–20 min, so set `timeouts` accordingly.

**Why a separate stack:** the image changes whenever `nixpkgs` (or the
base config) changes. If it lived in the machines stack, every infra
tweak after a `nix flake update` would rebuild and upload a multi-GB
qcow2 and re-import an image. Separate stacks keep the *bake* cadence
(deliberate, rare) apart from the *provision* cadence (frequent). The
machines stack finds the image with an `oci_core_images` data source by
display name. Hand-written OCIDs never appear in Nix.

### 5.3 Provision — stack `oci-anklab`

`nix run .#oci-anklab.plan` / `.apply` creates:

- VCN, internet gateway, route table, public subnet, and a security list
  (or NSG) allowing ICMP, tailscale's UDP 41641, and TCP 22 while
  `publicSsh = true` (the default, restrictable to `sshAllowCidrs`).
- Reserved public IP (survives instance replacement; the bootstrap and
  any DNS have a stable target).
- `oci_core_instance`: shape config, boot volume size, image from the
  data source, `metadata.ssh_authorized_keys` = ank's public key (picked
  up by the image's `fetch-ssh-keys`, so root SSH works on first boot),
  `display_name` = hostname. **`lifecycle.ignore_changes =
  [ source_details[0].source_id, metadata ]`**: re-baking an image or
  editing metadata must never replace a running host. Replacement is
  always explicit (§5.7).
- Outputs: `instances.ghost001.{public_ip, ocid}` (read by the bootstrap
  command through `tofu output -json`).

After apply, the instance boots the **base image**, which is already
NixOS from this repo, reachable as root over SSH with ank's key.

### 5.4 Bootstrap — `neusis cloud bootstrap ghost001`

One idempotent command (extends the existing `neusis anywhere` code
path in the Go CLI, with a thin flake app wrapper):

1. Read the IP from `tofu output -json` in `infra/oci-anklab/` and wait
   for SSH.
2. Decrypt `modules/secrets/bootstrap/ghost001/**.age` with the master
   identity (existing `anywhere decrypt` logic) and copy them into place
   (`/etc/ssh/ssh_host_ed25519_key{,.pub}`, 0600/0644). Restart sshd and
   check that the presented host key matches `hostPubkey`.
3. `nixos-rebuild switch --flake .#ghost001 --target-host root@<ip>`
   (build on the builders, or locally with `--build-host`). Activation
   runs agenix with the now-present host key: secrets decrypt, users get
   their initial password, tailscale joins the tailnet with the
   persistent auth key.
4. Verify: `tailscale status` shows `ghost001`; `ssh ank@ghost001` over the
   tailnet works.

Why not bake the host config into the image? It buys almost nothing:
the host key still has to be injected after boot, because it can't go
in the image or in OCI metadata, and activation has to run anyway. Each
host would also need its own image import (≈GBs + 15 min per config
change). Why not cloud-init/user-data for the key? OCI metadata is
readable by anything on the instance, stored in OCI, and copied into
state. That breaks principle 5.

### 5.5 Lock down (optional)

Public SSH stays open after bootstrap by default (decision §12.8).
Setting `publicSsh = false` in the stack and applying closes port 22;
the machine is then reached only over tailscale (and the OCI serial
console as break-glass). A plan with no changes is the "steady state"
signal either way.

### 5.6 Operate (day 2)

- **OS changes** (the common case): edit the flake, then
  `nixos-rebuild switch --flake .#ghost001 --target-host ghost001` over the
  tailnet, as a flake app/`neusis` subcommand so it's one command.
  No terranix involvement.
- **Infra changes** (shape resize, disk, rules): `plan` → review →
  `apply`. Read every plan for `-/+ replace` on the instance.
- **Upgrades**: bumping nixpkgs only affects the host via deploy.
  Re-baking the base image matters only for *future* provisioning.
- **Backups**: boot-volume backup policy declared in the stack
  (Always Free includes 5 volume backups). If the machine grows real
  state, put it on a separate block volume so reprovisioning doesn't
  touch data.
- **Drift**: `nix run .#oci-anklab.plan` with `-detailed-exitcode`
  locally (or later as a scheduled, read-only CI job with a read-only
  API key).

### 5.7 Reprovision / rebuild

To replace an instance (corrupted, new base image wanted, change of
image-incompatible shape): `tofu apply -replace=…instance…` through the
wrapper (`nix run .#oci-anklab.terraform -- apply -replace=…` style),
then §5.4 again. The host key and secrets are unchanged, so no rekey is
needed. Reserved IP and block volumes survive.

### 5.8 Rotate

- **Host key**: generate new key → replace the bootstrap `.age` +
  `hostPubkey` → `agenix rekey` → push key + deploy (same bootstrap
  command, run against the live host).
- **OCI API key**: new key in OCI → new HM secret → remove old key.
- **State passphrase**: OpenTofu supports `fallback` key providers for
  migration: add new as primary, old as fallback, `apply`, remove fallback.

### 5.9 Decommission

`nix run .#oci-anklab.plan` with the instance removed from the stack →
apply (or `destroy` for the whole stack). Then remove the machine from
the registry, delete `modules/secrets/bootstrap/ghost001/` and
`modules/secrets/rekeyed/ghost001/`, `agenix rekey`, and remove the node
from the tailnet. Log it in `docs/porting.md`.

## 6. State and secrets

| Thing | Where | Protection |
|---|---|---|
| OCI API signing key | HM agenix secret → `~/.oci/` on the operator machine | master identity; never in store/flake |
| State-encryption passphrase | HM agenix secret, exported as `TF_VAR_state_passphrase` by the wrapper `prefixText` | master identity |
| OpenTofu state | `infra/<stack>/terraform.tfstate`, **committed to git, encrypted** (`encryption { state { enforced = true } plan { enforced = true } }`, pbkdf2 + AES-GCM) | OpenTofu native encryption; plaintext state can never be written |
| Host SSH private key | `modules/secrets/bootstrap/<host>/etc/ssh/…age` | master identity; pushed over SSH at bootstrap only |
| Host runtime secrets | normal agenix-rekey flow, `modules/secrets/rekeyed/<host>/` | host key |
| Image | public-ish (object storage, private bucket) | contains no secrets by construction |

**State in git, encrypted**, rather than an Object Storage backend, at
least for now: neusis has one operator, so locking isn't a real need;
git gives history and rollback for free; and there's no bucket to
bootstrap before the bucket stack can store its own state. If a second
operator or CI apply ever appears, migrate to OCI Object Storage through
the S3-compatible backend (`use_lockfile`; terranix's `backend.s3`
recently gained the `skip_*_validation` flags this needs), still with
client-side encryption on top.

`.gitignore` for `infra/*/`: `.terraform/`, `config.tf.json` (a symlink
to the store), crash logs. Committed: the encrypted `terraform.tfstate`.
`.terraform.lock.hcl` is moot with Nix-provided plugins (decide during
implementation).

## 7. Reusable vs fleet: what consumers get

Exported for consumer repos (via `flakeModules.default`): the
`terranixModules` option + modules, `features.nixos.oci-guest`, a
`mkOciBaseImage { system, extraModules }` lib helper (so a consumer can
bake their own base), and the `neusis cloud bootstrap` CLI. Fleet-only:
`modules/infra/*`, `modules/machines/ghost001.nix`, `infra/*` state.
A `templates/` entry for "cloud machine on OCI" can come later.

## 8. Alternatives considered

| Option | Verdict |
|---|---|
| **nixos-anywhere onto an Oracle Linux/Ubuntu platform image** (kexec + disko; `neusis anywhere` already does this; nixos-anywhere also ships Terraform modules usable from terranix) | **Kept as the fallback.** Proven, no image import, but the machine's first OS isn't ours, kexec on small shapes (E2.1.Micro, 1 GB) is fragile, and it needs a disko layout. Your brief asks for a repo-built image; this is the escape hatch if A1 custom-image import misbehaves. |
| Host-specific images (full host config baked in) | Rejected (§5.4): per-host imports, host key still needs injection, every OS change tempts an instance replacement. |
| Terraform instead of OpenTofu | Works with terranix the same way, but no native state encryption and unfree licence. |
| Hand-rolled `lib.terranixConfiguration` + own apps | Unnecessary. The upstream flake-module covers it; we only add defaults. |
| deploy-rs / colmena for day 2 | Not now. `nixos-rebuild --target-host` is enough for one host. Revisit deploy-rs (magic rollback is valuable when a bad network config can lock you out of a cloud box) once there are a few cloud hosts. |
| NixOS-only metadata tooling (cloud-init in image) | Rejected: the IMDS `fetch-ssh-keys` unit from nixpkgs is all we need; cloud-init adds state we don't want. |

## 9. Risks and unknowns (to retire in an early spike)

1. **A1 custom-image import details**: exact image capability settings
   (UEFI_64 firmware, paravirtualized launch mode) and shape
   compatibility for an imported aarch64 QCOW2 via the provider.
   Community reports confirm it works after marking A1-compatible; the
   provider resources are `oci_core_shape_management` and
   `oci_core_compute_image_capability_schema`.
2. **A1 capacity** in the home region. Mitigation: PAYG, retry, or
   smaller OCPU count.
3. **terranix `terraform.encryption` block**: confirm terranix's
   `terraform` attr passes OpenTofu's `encryption` block through
   verbatim (it's freeform JSON). If it doesn't, use the `TF_ENCRYPTION`
   env var from `prefixText`.
4. **Upload of a multi-GB object from tofu**: the provider supports
   multipart for `source`; confirm it's practical from a laptop, or fall
   back to `oci os object put` in a `prefixText`/local-exec.
5. **First real NixOS host on the new tree**: expect latent bugs in
   `mkNeusisOS` paths that only the fixture has exercised (the darwin
   port surfaced several). Budget time for this.
6. **Flake-module per-system outputs**: it creates
   `packages.<every-system>.oci-*`. T1 (`--no-build --all-systems`) is
   fine; T2 would build the image for the Linux variants. Acceptable, or
   gate with `exportDevShells = false` and per-system `optionalAttrs`.

## 10. Testing (mapped onto the existing ladder)

- **T0 (nix-unit)**, mirrored paths:
  - `tests/terranixModules/oci/instance.test.nix`: evaluate with
    `inputs.terranix.lib.evalTerranixConfiguration` and compare plain
    values: shape/ocpus/memory land in the resource; `ignore_changes`
    contains `source_details[0].source_id`; aarch64 machine + x86 shape
    → `expectedError` from the assertion; port 22 rule present iff
    `publicSsh`.
  - `tests/terranixModules/state-encryption.test.nix`: `enforced = true`
    for state and plan.
  - `tests/features/nixos/oci-guest.test.nix` +
    `tests/machines/ghost001.test.nix`: host and base image agree on
    `fileSystems."/"`, ESP, `boot.loader.grub.efiSupport`; the host
    imports secrets + tailscale; `hostPubkey` matches the bootstrap key's
    `.pub` (plain string compare).
- **T1**: `nix flake check --no-build --all-systems` instantiates
  `nixosConfigurations.ghost001`, the base image, and the stack packages.
- **T2**: `checks.<sys>.tofu-validate-<stack>`: build `config.tf.json`
  and run `tofu init -backend=false && tofu validate` offline with
  Nix-provided plugins. Catches freeform attribute typos without
  touching OCI.
- **T3**: `checks.aarch64-linux.vm-oci-guest`: boot the host config's
  module list (minus the image builder) in a NixOS test VM. Optionally
  boot the actual qcow2 with a fake IMDS serving `ssh_authorized_keys`
  to prove `fetch-ssh-keys` + sshd.
- **T4 (new, manual, never CI)**: `plan` against the live tenancy →
  no unexpected changes; bootstrap smoke check (tailscale up, agenix
  secrets present, `nixos-version` matches the flake rev).

## 11. Repository impact summary

- New input: `terranix` (declared in `features/flake/terranix.nix`;
  `nix run .#write-flake`; lock bump in the same commit).
- New schema entry: `flake.terranixModules` in `neusis-options.nix`.
- New directories: `modules/terranixModules/`, `modules/infra/`,
  `modules/images/`, `modules/features/nixos/`, `infra/` (state),
  `modules/secrets/bootstrap/`.
- First entry in `registry.machines.anklab.nixos`.
- `cli/`: `neusis cloud bootstrap` (and probably `neusis cloud deploy`).
- Docs: this spec → `docs/cloud/tutorial.md` once built; porting-log
  entries per milestone; `AGENTS.md` layout/commands updated.

## 12. Decisions (answered 2026-10-16)

1. **Machine name**: `ghost001` is a placeholder (rovers theme → e.g.
   `sojourner`/`curiosity`?).
   *Answer* Use the name "ghost001"
2. **Account and shape**: Always Free vs PAYG; region; A1.Flex size
   (all 4 OCPU / 24 GB in one host, or 2/12 to leave room for a second).
   *Answer* For now we will use Always Free
3. **What is the box for?** (builder, services, exit node…). This
   drives disk size, whether it joins `registry.builders`, and whether
   it needs a data volume.
   *Answer* I will use it experiment with self hosting apps. So, it will probably host a lot of apps.
   Add it as a builder as well, for checking the builder module but keep its speed low.
4. **OpenTofu** (recommended) vs Terraform.
   *Answer* Use OpenTofu
5. **State**: encrypted-in-git (recommended) vs Object Storage backend
   from day one.
   *Answer*  go with your recommedation
6. **Base image + bootstrap** (recommended) vs host-specific image.
   *Answer* go with your recommendation
7. **Bootstrap/deploy tooling home**: `neusis` Go CLI subcommands
   (recommended, reuses `anywhere`) vs a flake app script.
   *Answer* go with your recommendation
8. **Public SSH after bootstrap**: closed entirely, tailnet only
   (recommended), vs restricted to an IP allowlist.
   *Answer* Make this possible, but by default keep the public ssh open after bootstrap
9. **Users on the box**: `registry.users.anklab` (ank as admin) with the
   common initial password, or a narrower cloud registry.
   *Answer* go with your recommendation

