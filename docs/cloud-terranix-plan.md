# Cloud machines with terranix — build plan

Companion to `docs/cloud-terranix-spec.md` (the architecture; decisions
in its §12 are final). This file is the work breakdown: three spikes
that retire the unknowns, then eight milestones that land the design.
Each milestone is one or a few conventional commits, has an explicit
verification rung, and leaves `main` green. Progress and surprises go to
`docs/porting.md` as usual; this file only changes when the plan does.

Decisions carried in from the spec: machine **`ghost001`**, Always Free
A1.Flex (aarch64-linux), self-hosted-apps box that also joins
`registry.builders` at low priority, OpenTofu, encrypted state in git,
shared base image + bootstrap, bootstrap in the Go CLI, public SSH
**stays open by default** with a switch to close it, users from
`registry.users.anklab`.

Legend: **Verify** = the ladder rung(s) that must pass (T0 nix-unit,
T1 `nix flake check --no-build --all-systems`, T2 build, T3 VM, T4
manual against the live tenancy). **Live** = touches the OCI account.

---

## Phase 0 — Spikes (throwaway, `scratch/`, gitignored)

Goal: answer §9 of the spec with evidence before any module is written.
Nothing from here is committed except findings in `docs/porting.md`.

### S1 — Can OCI boot a repo-built aarch64 NixOS qcow2 on A1.Flex? (Live)

1. Account prep (manual, §5.0 of the spec): compartment, IAM user +
   policy, API key, `~/.oci/config` profile `neusis` — by hand for the
   spike; the HM-managed version lands in M4.
2. Build the stock image:
   `nix build --impure --expr '(import <nixpkgs>/nixos { configuration = { imports = [ <nixpkgs>/nixos/modules/virtualisation/oci-image.nix ]; nixpkgs.hostPlatform = "aarch64-linux"; }; }).config.system.build.OCIImage'`
   (or via the flake's nixpkgs). Note image size and build time through
   the aarch64 builders.
3. Hand-written `main.tf` with the `oci` provider from
   `pkgs.opentofu.withPlugins (p: [ p.oracle_oci ])`: bucket → object
   (upload) → `oci_core_image` (QCOW2, PARAVIRTUALIZED) →
   `oci_core_shape_management` for `VM.Standard.A1.Flex` →
   `oci_core_compute_image_capability_schema` (UEFI_64, paravirt boot/net)
   if the plain import doesn't boot → one A1 instance with
   `ssh_authorized_keys` metadata.
4. Record: the exact capability/schema settings needed, import duration,
   whether multipart upload from a laptop is fine (§9.4), whether A1
   capacity was available, and the console output on first boot.
5. Confirm `fetch-ssh-keys` populated root's keys; `ssh root@ip`; then
   `nixos-rebuild switch --flake` a trivial change onto it to prove the
   base→host path keeps the same bootloader/filesystems.
6. `tofu destroy`.

Exit: a written recipe (resources + attributes) that boots, or the
decision to fall back to nixos-anywhere onto a platform image (spec §8).

### S2 — Does terranix pass the OpenTofu `encryption` block through?

In `scratch/`, a 20-line flake importing `terranix.flakeModule` with a
config that sets `terraform.encryption = { … pbkdf2 + aes_gcm, state/plan
enforced … }` and `backend.local`. Check the generated `config.tf.json`,
run `init`/`apply` with a `null_resource`, inspect that
`terraform.tfstate` is ciphertext, and confirm that unsetting the
passphrase makes `plan` fail (enforced). Fallback if the block doesn't
serialise: the `TF_ENCRYPTION` env var from `prefixText`.

Exit: the exact Nix attrset shape for `state-encryption.nix` (M2).

### S3 — Flake-module ergonomics check

Still in `scratch/`: confirm `nix run .#foo.plan` / `.#foo.terraform --
state list` work, confirm `workdir` is relative to cwd (so the wrapper
needs a repo-root guard), and check what `nix flake check --all-systems`
does with `packages.<sys>.foo` for non-Linux systems (§9.6). Decide
`exportDevShells` on/off.

Exit: notes feeding M1's `terranix.nix` feature.

---

## Phase 1 — Foundations (no Live)

### M1 — terranix input + flake feature + schema

- `modules/features/flake/terranix.nix`: `flake-file.inputs.terranix`
  (`inputs.nixpkgs.follows = "nixpkgs"`), imports
  `inputs.terranix.flakeModule`, and a `flake.neusis.lib.cloud.mkStack`
  helper (or shared default module) that sets the neusis defaults for
  every stack: `terraformWrapper.package = pkgs.opentofu.withPlugins (p:
  [ p.oracle_oci ])`, repo-root guard (`test -f flake.nix || exit`),
  `prefixText` that sources `TF_VAR_state_passphrase` from a configurable
  path (default `$XDG_RUNTIME_DIR`/HM secret path, M4), `exportDevShells`
  per S3.
- `neusis-options.nix`: `flake.terranixModules` (`lazyAttrsOf
  deferredModule`, mirrors `agnosticModules`) and
  `flake.neusis.lib.cloud` namespace.
- `nix run .#write-flake`, `nix flake update terranix`; `flake.nix` +
  `flake.lock` in the same commit.
- `infra/` directory with `.gitignore` (`.terraform/`, `config.tf.json`,
  `*.tfplan`, crash logs) and `.gitkeep`.
- Tests: `tests/features/flake/terranix.test.nix` (option exists, default
  package is `opentofu`, plugin list contains `oracle_oci`) and
  `tests/lib/cloud.test.nix`.
- **Verify**: T0, T1. Commits: `feat(cloud): terranix input + flake
  feature + terranixModules schema`.

### M2 — Reusable terranix modules + unit tests

Under `modules/terranixModules/`, each exported as
`flake.terranixModules.<name>`, each with a mirrored nix-unit test using
`inputs.terranix.lib.evalTerranixConfiguration` and plain-value compares:

- `state-encryption.nix` — `neusis.state.{passphraseVar}`; emits the
  encryption block from S2 with state+plan enforced.
- `oci/provider.nix` — `neusis.oci.{profile, region, compartment}` →
  `provider.oci` using `config_file_profile`; `locals`/`variable` for the
  compartment OCID.
- `oci/network.nix` — `neusis.oci.network.<name> = { cidr; publicSsh =
  true; sshAllowCidrs = ["0.0.0.0/0"]; }` → VCN, IGW, route table,
  subnet, security list (ICMP, UDP 41641 always; TCP 22 iff `publicSsh`,
  from `sshAllowCidrs`).
- `oci/image.nix` — `neusis.oci.images.<name> = { qcow2 = <drv>; shapes =
  [...]; }` → bucket, object (name with store hash), `oci_core_image`,
  shape management, capability schema per S1, `create_before_destroy`,
  timeouts.
- `oci/instance.nix` — `neusis.oci.instances.<host> = { machine; network;
  shape = { name; ocpus; memoryGb; }; bootVolumeGb; dataVolumeGb ?;
  image; reservedIp; sshAuthorizedKeys; }` → `oci_core_images` data
  lookup by display name, instance with `ignore_changes` on image +
  metadata, reserved public IP, optional block volume + paravirt
  attachment, backup policy assignment, `output.instances.<host>`.
  Assertion: `machine.system` arch ↔ shape family.
- Tests (examples): aarch64 machine + `VM.Standard.E4.Flex` →
  `expectedError`; `publicSsh = false` → no TCP-22 rule; ignore_changes
  list; data volume only when requested.
- **Verify**: T0, T1. Commits: one per module or one for `oci/*`;
  `feat(cloud): reusable terranix modules for OCI`.

### M3 — OCI guest profile + base image

- `modules/features/nixos/oci-guest.nix` →
  `flake.neusis.features.nixos.oci-guest`: imports nixpkgs
  `virtualisation/oci-common.nix`, serial getty, `boot.loader.timeout`,
  `services.openssh` hardening consistent with the base image.
  (First file under `features/nixos/`; `featuresType.nixos` already
  exists.)
- `modules/images/oci-base.nix` → `packages.{aarch64,x86_64}-linux.
  oci-base-image` built with `nixpkgs.lib.nixosSystem` + `oci-image.nix`
  + `oci-guest` + `features.agnostic.nix-settings`; plus
  `flake.neusis.lib.cloud.mkOciBaseImage { system; extraModules; }` so
  consumers can bake their own. Not a `nixosConfiguration`.
- Tests: `tests/features/nixos/oci-guest.test.nix` (filesystems, GRUB
  EFI removable, networkd, kernel params); `tests/images/oci-base.test.nix`
  (image config has no users beyond root, no agenix, `system.build.image`
  is the OCI image).
- **Verify**: T0, T1; T2 `nix build .#packages.aarch64-linux.oci-base-image`
  through the aarch64 builders (note: with rogue's `linux-builder` removed
  this routes to spirit/oppy). Commits: `feat(cloud): oci-guest profile`,
  `feat(cloud): oci base image`.

### M4 — `ghost001` the machine, secrets, operator credentials

- `modules/machines/ghost001.nix`: `system = "aarch64-linux"`,
  `hostPubkey` from the pre-generated key, `primaryUser = "ank"`,
  `userRegistries = [ anklab ]`, `initialHashedPassword =
  secrets/common/hashedInitialPassword.age`, module imports: `oci-guest`,
  `nixosModules.secrets` + agenix nixos modules, `nixosModules.tailscale`
  + `ank_mesh`, `features.agnostic.{nix-settings,nix-pkgs,
  distributed-builds}` (build-server side), docker/podman for the apps
  later. Data volume mount (`/srv` by label) if S1/M2 chose one.
- `registry/machines/anklab.nix`: first `nixos = [ ghost001 ]` entry.
- `registry/builders/anklab.nix`: ghost001 as a builder, `systems =
  [ "aarch64-linux" ]`, `maxJobs = 2`, `speedFactor = 1`, `sshUser =
  "nixremote"`.
- Host key: `ssh-keygen -t ed25519` → private half as
  `modules/secrets/bootstrap/ghost001/etc/ssh/ssh_host_ed25519_key.age`
  (encrypted to the master identity; same root-shaped layout `neusis
  anywhere` consumes) + `.pub` in clear; `agenix rekey` → `rekeyed/ghost001/`.
- Operator side (ank's HM bundle, `modules/users/ank/`): agenix secrets
  for the OCI API private key and the state passphrase; HM writes
  `~/.oci/config` (`[neusis]` profile) and exposes the passphrase path
  the M1 `prefixText` reads. `oci-cli` + `opentofu` in the bundle's
  packages (or only via the stack devShells — decide in M1/S3).
- Tests: `tests/machines/ghost001.test.nix` (evaluates via `evalNixos`;
  `hostPubkey` == bootstrap `.pub` content; filesystems/bootloader equal
  the base image's; secrets + tailscale enabled; users alice-style
  checks via the real registry: `ank` in wheel), `registry.test.nix`
  updated (one nixos machine), `tests/registry/builders` updated.
- **Verify**: T0, T1 (`nixosConfigurations.ghost001` instantiates), T3
  extend `vm-neusis-os`-style test to boot ghost001's module list minus
  the OCI hardware bits (or a new `vm-oci-guest`). Commits:
  `feat(ghost001): machine, registry, builder entry`,
  `feat(secrets): ghost001 host key + rekey`, `feat(ank): OCI operator
  credentials`.

---

## Phase 2 — Stacks and first contact (Live from M5)

### M5 — Stack `oci-images` (Live)

- `modules/infra/oci-images.nix`: `terranix.terranixConfigurations.
  oci-images` via the M1 helper, `workdir = "infra/oci-images"`, modules
  `state-encryption`, `oci/provider`, `oci/image` with
  `images.oci-base-aarch64.qcow2 = self.packages.aarch64-linux.oci-base-image`.
- Checks: `checks.<linux>.tofu-validate-oci-images` (`tofu init
  -backend=false && tofu validate` offline with Nix plugins).
- Run `nix run .#oci-images.plan`, then `.apply`; commit the encrypted
  `infra/oci-images/terraform.tfstate`.
- **Verify**: T0/T1/T2 (validate check), T4: image visible in the
  console, A1-compatible. Commits: `feat(infra): oci-images stack`,
  `chore(infra): oci-images state`.

### M6 — Stack `oci-anklab` (Live)

- `modules/infra/oci-anklab.nix`: network `anklab` (`publicSsh = true`
  default), instance `ghost001` (4 OCPU / 24 GB, boot + data volume
  within the 200 GB Always Free budget, reserved IP, ank's pubkey),
  backup policy.
- Check `tofu-validate-oci-anklab`; T0 test that the stack's instance
  references `self.neusis.machines.ghost001` (hostname/system).
- `plan` → review → `apply` (retry on "Out of host capacity"); commit
  state. `ssh root@<ip>` works via `fetch-ssh-keys`.
- **Verify**: T0/T1/T2, T4. Commits: `feat(infra): oci-anklab stack with
  ghost001`, `chore(infra): oci-anklab state`.

### M7 — `neusis cloud bootstrap` + first deploy (Live)

- `cli/cmd/cloud.go` + `cli/internal/cloud/`: `neusis cloud bootstrap
  <host> [--stack oci-anklab] [--ip …]`: read `tofu output -json` from
  `infra/<stack>/` (or `--ip`), wait for SSH, decrypt
  `modules/secrets/bootstrap/<host>/` with the existing `anywhere`
  decryptor, `scp` the key tree into place (0600/0644), restart sshd,
  verify the host key fingerprint equals the registry `hostPubkey`, then
  `nixos-rebuild switch --flake .#<host> --target-host root@<ip>`
  (optionally `--build-host`). Idempotent. Also `neusis cloud deploy
  <host>` = the `nixos-rebuild --target-host` step over the tailnet for
  day 2.
- Go tests in `cli/internal/cloud` (output parsing, fingerprint compare,
  command assembly); `cd cli && go test ./...`.
- Flake app wiring is free (`packages.<sys>.neusis`).
- Run it: ghost001 comes up with agenix secrets, users, tailscale
  (`tailscale status` lists ghost001); `ssh ank@ghost001` over the
  tailnet; `nix store ping --store ssh://nixremote@ghost001` from rogue
  proves the builder entry.
- **Verify**: go tests, T1, T4. Commits: `feat(cli): neusis cloud
  bootstrap/deploy`, porting-log entry.

---

## Phase 3 — Day 2 and polish

### M8 — Operations, docs, consumer surface

- Drift check script/app: `nix run .#oci-anklab.plan -- -detailed-exitcode`
  documented; `publicSsh = false` path exercised once (apply, confirm
  port closed, revert) so the switch is known to work.
- Always Free idle-reclamation note (A1 instances idle for 7 days can be
  reclaimed): keep the builder/apps busy or move to PAYG.
- `docs/cloud/tutorial.md` (operator runbook: account setup, bake,
  provision, bootstrap, deploy, reprovision, rotate, decommission),
  `AGENTS.md` layout + commands (`nix run .#oci-*`, `neusis cloud …`),
  `docs/testing.md` T4 rung, porting-log entry.
- Consumer exports via `flakeModules.default`: `terranixModules`,
  `features.nixos.oci-guest`, `lib.cloud.mkOciBaseImage`; a
  `templates/cloud-oci` entry is optional/later.
- **Verify**: T0–T2 green, `nix flake check --no-build --all-systems`,
  `cd cli && go test ./...`.

---

## Ordering and parallelism

S1 is the long pole (account prep + import ≈ an afternoon, capacity
permitting) and gates M2's `oci/image.nix` details and M3's guest tweaks.
S2/S3 take an hour and gate M1. M1→M2→M3→M4 are sequential but Live-free
and can proceed while S1's image imports. M5–M7 are strictly sequential
and Live. M8 is polish.

## Out of scope for this plan

deploy-rs/colmena, a second region or x86 host, Object Storage state
backend, CI applies, the self-hosted apps themselves (they are ordinary
NixOS modules on ghost001 once M7 is done).
