# Cloud machines with terranix — progress log

Timestamped record of what happened while executing
`docs/cloud-terranix-plan.md`. Newest entry last. Decisions and
rationale that outlive this project go to `docs/porting.md`; this file
is the day-to-day trail (what was tried, what was measured, what is
blocked on whom).

Status line format: `<date> <time TZ> — <phase/milestone> — <what>`.

---

- 2026-10-07 — spec drafted (`docs/cloud-terranix-spec.md`), nine open
  decisions.
- 2026-10-16 — all nine decisions answered in §12 (ghost001, Always Free
  A1, apps box + low-priority builder, OpenTofu, encrypted state in git,
  base image + bootstrap, Go CLI, public SSH open by default, anklab
  users). Spec committed (`3374f0c`), decisions folded in + build plan
  added (`4786050`).
- 2026-10-17 — housekeeping — rogue drops the ephemeral linux-builder VM
  (24 GB resident); the feature is renamed `features.darwin.linux-builder`
  and kept opt-in. All aarch64-linux builds (base image, T3 VM tests) now
  route to spirit/oppy via the builders registry. T0 222/222 (`d8f1a93`).
- 2026-10-17 — Phase 0 — S2/S3 started in `scratch/s2` (gitignored):
  terranix flake-module + OpenTofu with `null` and `oracle_oci` plugins,
  `terraform.encryption` block, repo-root guard + passphrase env in
  `prefixText`.
- 2026-10-17 — Phase 0 — **S2 done.** `terraform.encryption` serialises
  through terranix; OpenTofu's JSON syntax needs bare reference strings
  (`"method.aes_gcm.main"`), not `${…}`. Applied a `null_resource` with
  pbkdf2+AES-GCM, state+plan enforced: state file is ciphertext, no
  plaintext output values in it, wrong passphrase → "decryption failed",
  `state list` and `output -json` work with the right one. No
  `TF_ENCRYPTION` fallback needed. First attempt failed on my Nix
  quoting (`''${` inside a `"…"` string), second on a stale
  `config.tf.json` (see S3), third passed.
- 2026-10-17 — Phase 0 — **S3 done.** Flake-module gotchas recorded in
  the plan: `prefixText` runs inside `workdir`; `workdir` is cwd-relative
  (made `/tmp/infra/spike` when run from `/tmp`); scripts don't forward
  args; the bare `.terraform` wrapper doesn't relink `config.tf.json`;
  offline `tofu validate` works; `--no-build --all-systems` fine;
  `.terraform.lock.hcl` still written. `tofu destroy` ran; `scratch/s2`
  kept as a reference until M1 lands.
- 2026-10-17 — Phase 0 — Operator checklist (account, compartment, IAM
  policy, API key, the four secrets + region) written into the plan
  (Phase 0 → "Operator prerequisites"). **Blocked on Ankur** for S1 and
  M4's credential wiring; M1–M3 can proceed meanwhile.
- 2026-10-19 — **M1 done.** `terranix` input (locked at terranix main
  2026-09-21, follows nixpkgs), `features/flake/terranix.nix` +
  `_terranix-defaults.nix` (OpenTofu + pinned `oracle_oci`, `workdir =
  infra/<stack>`, repo-root guard, config relink, `~/.config/neusis/tf.env`
  secrets, passphrase required), `flake.terranixModules` schema,
  `flakeModules.terranix` export, `infra/.gitignore`. Gotcha: write-flake
  can't run while the new module already imports from the new input —
  bootstrap with empty `imports`, then restore. T0 227/227 on both test
  sets, T1 all-systems green. Ankur is doing the OCI account prep in
  parallel (S1 still blocked on it).
- 2026-10-19 — **M2 done.** `terranixModules/{state-encryption,oci/*}` +
  mirrored nix-unit tests (22 cases: wiring, `publicSsh` rules, store-hash
  object naming, A1 shape + UEFI capability schema, reserved IP, data
  volume, backup policy, arch/shape and unknown-network assertions).
  Attribute names taken from `tofu providers schema -json` (oracle/oci
  v8.14.0); the full module set passes an offline `tofu validate` in
  `scratch/s2` (stack `validate`). Hit and fixed: top-level `mkIf`
  recursion, `//` dropping sibling keys, terranix dropping empty blocks.
  T0 246/246, T1 green. Next: M3 (oci-guest profile + base image).
- 2026-10-19 — **M3 done.** `features.nixos.oci-guest`,
  `lib.cloud.mkOciBaseImage`, `packages.<linux>.oci-base-image`, tests for
  the guest layout, the host-independence of the image and the
  base↔guest layout invariant. T0 255/255, T1 green (the image drvs
  instantiate for both Linux systems), T2: the aarch64 image built on
  spirit/oppy (`nixos-image-oci-26.05.20261015.26f4107-aarch64-linux.qcow2`).
- 2026-10-19 — **M4 code done, blocked on rekey.** `machines/ghost001.nix`,
  registry (first `nixos` entry) + builders entry, ank's bundles for
  ghost001, host keypair generated and the private half encrypted to the
  master pubkey under `secrets/bootstrap/ghost001/`, placeholder HM secrets
  `ociApiKey`/`ociConfig`/`ociTfEnv` wired into ank's `secrets` bundle,
  machine test + registry/builder/home test updates. T0 261/261. T1 fails
  only on `nixos-ghost001`: `modules/secrets/rekeyed/ghost001` does not
  exist yet → needs `agenix rekey` (master identity, Ankur). Ankur has
  created the `neusis` compartment (OCID noted locally, to go into
  `ociTfEnv.age`, not the repo).
- 2026-10-19 — **Correction on M3's T2.** The first aarch64 image build was
  reported green by mistake (the exit code read was `tail`'s). The real
  build fails on spirit/oppy inside `make-disk-image`'s `runInLinuxVM`:
  virtiofsd aborts with "Mount point's (/nix/store) mount ID (0) does not
  match expected value" under the Nix sandbox (Nix 2.31.3, kernel 6.12,
  `sandbox = true`), so QEMU never gets its store socket. M3's
  code/tests are unaffected (the commit claims eval/T1 only in its
  message; the progress line above overstated T2). Trying the build on
  spirit with `--option sandbox false` (ank is a trusted user there) as
  the workaround; if that is the only way, baking becomes a documented
  "build on a builder with the sandbox off" step until the virtiofsd/
  sandbox issue is fixed upstream or the builders' config can change.
- 2026-10-19 — **M5/M6 code (Live-free part).** `modules/infra/
  oci-images.nix` (bakes `oci-base-aarch64` from
  `packages.aarch64-linux.oci-base-image.qcow2`) and `oci-anklab.nix`
  (network 10.42.0.0/16, `publicSsh = true`, ghost001 = A1.Flex 4/24,
  50 GB boot + 150 GB data volume, reserved IP, ank's keys), each with a
  `checks.<sys>.tofu-validate-<stack>` built by
  `lib.cloud.mkValidateCheck` (offline `tofu init -backend=false` +
  `validate` in the sandbox; the images check stands in an empty store
  file for the qcow2). The region joined the env file as `TF_VAR_region`
  so no tenancy fact is in the repo. T0 265/265, both validate checks
  build green on aarch64-darwin. Applies wait for the secrets + rekey.
- 2026-10-19 — **M7 code (Live-free part).** `cli/internal/cloud` +
  `neusis cloud {bootstrap,deploy}`: bootstrap reads the IP from
  `nix run .#<stack>.terraform -- output -json`, reads the pinned
  `hostPubkey` with `nix eval`, waits for SSH, decrypts
  `modules/secrets/bootstrap/<host>/` with the master identity (reusing
  the `anywhere` decryptor), streams the tree to `/` over ssh + restarts
  sshd, then talks to the host only through a temp known_hosts pinned to
  the registry key (`StrictHostKeyChecking=yes`, also passed to
  `nixos-rebuild` via `NIX_SSHOPTS`) and runs `nixos-rebuild switch
  --flake .#<host> --target-host`. `deploy` is the day-2 subset. Dev
  shell gains `age` and `nixos-rebuild`. `go vet`/`go test ./...` green,
  `nix build .#neusis` green. Commit order once the rekey lands and T1 is
  green: M4 → M5/M6 → M7.
- 2026-10-19 — image bake: `--option sandbox false` over `--store
  ssh-ng://spirit` was not honoured (build still ran in `/build`, same
  virtiofsd error); retrying with `nix build` run directly on spirit as
  ank (trusted user there).
- 2026-10-19 — **Image bake root cause.** Not the sandbox: the aarch64
  `oci-image` derivation runs on spirit/oppy under binfmt (qemu-user)
  emulation, and the *emulated* aarch64 `virtiofsd` gets no mount ID
  from `statx` there (virtiofsd 1.13.3 falls back to
  `name_to_handle_at`, then to 0 → "mount ID (0) does not match"). A
  native x86_64 virtiofsd inside a Nix build on spirit works, sandbox on
  or off. So `make-disk-image` (= `vmTools.runInLinuxVM`) needs a
  *native* aarch64 Linux builder. Trying nixpkgs' ad-hoc
  `nix run nixpkgs#darwin.linux-builder` VM on rogue (no config change;
  `QEMU_OPTS="-m 8G -smp 4"`, ssh `builder@localhost:31022` with the
  key it drops in `./keys`), building inside it with
  `--option system-features kvm` (no /dev/kvm; runInLinuxVM's qemu is
  `accel=kvm:tcg`, so it falls back to TCG). If this works, "bake" =
  start that VM, `nix copy --derivation` the image drv in, build there,
  `nix copy` the qcow2 back — to be wrapped in the plan/runbook.
- 2026-10-19 — **Image baked; M3 T2 green for real.** Native build inside
  the ad-hoc `darwin.linux-builder` VM on rogue (8 GB/4 vCPU, TCG for the
  inner VM) succeeded in ~10 min; copied back with `--no-check-sigs`:
  `/nix/store/6hvs4yrq…-oci-image/nixos-image-oci-26.05.20261015.26f4107-aarch64-linux.qcow2`,
  2.6 GB (8 GiB virtual). Procedure recorded in the plan ("Baking the
  image"). The VM has been stopped; restart it for the next bake.
- 2026-10-19 — **First live contact (M5).** Ankur filled the three HM
  secrets and ran `agenix rekey` + `home-manager switch`; `~/.oci/*` and
  `~/.config/neusis/tf.env` are agenix symlinks. The API key
  authenticates (`oci iam region-subscription list`: home region
  us-ashburn-1; compartment `neusis` ACTIVE). Two fixes from the first
  `nix run .#oci-images.plan`: the console's config preview writes a
  `[DEFAULT]` profile, so `neusis.oci.profile` now defaults to that
  (`770bf3d`); and `oci_core_compute_global_image_capability_schemas`
  filtered by our compartment returns null — global schemas are
  tenancy-scoped, so the data source now takes no arguments (`a02844b`;
  terranix keeps an empty block as long as the top-level key isn't
  empty). Second plan: 5 to add (bucket, object, image, A1 shape
  compatibility, capability schema), namespace and AD lookups resolved.
  `apply -auto-approve` started (2.6 GB upload + import).
