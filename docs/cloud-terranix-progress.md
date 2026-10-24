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
- 2026-10-20 — **M4 T2 green.** `nixosConfigurations.ghost001` toplevel
  built through spirit/oppy:
  `/nix/store/3d70zg9bzgbldx9q1rw58rnzl09iy5xq-nixos-system-ghost001-26.05.20261015.26f4107`
  (first attempt lost `yajna`'s output to a transient "Nix daemon
  disconnected" while copying back from the builder; the retry went
  through). The closure is in rogue's store, so bootstrap will only copy,
  not build. Still blocked on the custom-image decision (PAYG vs
  nixos-anywhere fallback).
- 2026-10-24 — **PAYG upgrade; M5 done; M6 done; S1 retired.** After the
  upgrade `custom-image-count` is 25. `oci-images` apply needed two more
  fixes: capability-schema descriptors are camelCase in the API
  (`descriptorType`/`defaultValue`; snake_case → 500 InternalError,
  `3b218de`), and the import records `launch-options.firmware = BIOS`
  for the qcow2, so Arm instances now pin `launch_options = { firmware =
  UEFI_64; network_type/boot_volume_type = PARAVIRTUALIZED }` (OCI
  requires `network_type` whenever `launch_options` is set; `fd39a05`,
  `5a34f2c`). Image `oci-base-aarch64` is AVAILABLE and A1-compatible.
  `oci-anklab` apply: VCN/subnet/IGW/route/security list, ghost001
  (A1.Flex 4/24, launched in 46 s — capacity was there), 150 GB data
  volume attached, bronze backup policy, reserved IP 129.80.54.71. First
  boot over SSH: NixOS 26.05 aarch64, EFI, root grown to 49 GB, `sdb` =
  data disk (unformatted), fetch-ssh-keys/sshd/networkd active. Both
  states committed (ciphertext). Next: `neusis cloud bootstrap ghost001`.
- 2026-10-24 — **M7: ghost001 bootstrapped (with two CLI bugs found live).**
  Tailscale credentials moved to `modules/secrets/{ank,cslab}/` (real
  values + rekey by Ankur); ghost001 joins the **cslab** tailnet
  (`88f6c65`); `yajna` 0.7.1 does not build for aarch64-linux, dropped
  from ghost001's home for now (`6531672`). Bootstrap pushed and verified
  the host key, then: (1) `nixos-rebuild` inside `nix develop` died on a
  too-long ssh ControlPath (`$TMPDIR=/tmp/nix-shell.…`) → CLI forces
  `TMPDIR=/tmp` for the child (`d54a7f2`); (2) the key push extracted the
  tar stream's `.`/`etc` entries onto the real `/` and `/etc`, leaving
  `/` as `drwx------ UNKNOWN:wheel`, so every non-root unit (networkd,
  resolved, timesyncd, home-manager-ank) failed with `200/CHDIR` after
  the switch → repaired by hand (`chown root:root / /etc /etc/ssh; chmod
  755`), CLI now extracts with `--no-overwrite-dir --no-same-owner`
  (`eff0755`). After that: ghost001 runs
  `nixos-system-ghost001-26.05…`, agenix decrypted remoteBuildKey +
  the three cslab secrets, `ank` (wheel) + home-manager active, tailscale
  up as `ghost001` (100.65.218.47). Open: the autoconnect oneshot's
  key-expiry step fails ("Failed to obtain OAuth token") — cslab OAuth
  client credentials/scopes to check; and rogue is not on the cslab
  tailnet, so its builder entry `nixremote@ghost001` is unreachable
  from rogue (noisy "cannot build on" warnings) until rogue joins or the
  entry changes.
- 2026-10-24 — **M7 done.** After the repair ghost001 was rebooted into
  its generation (`systemctl reboot` — the first attempt silently never
  ran, a shell quoting slip on my side): hostname `ghost001` (NixOS sets
  the kernel hostname in stage 2, so a switch alone leaves the base
  image's transient `oci-base`), tailscale connects at boot as
  `ghost001` (100.65.218.47 on cslab), `/` and `/etc` root-owned, no
  failed units except `neusis-tailscale-autoconnect` (its
  disable-key-expiry step: "Failed to obtain OAuth token"). Lifecycle
  proven end to end: bake → upload/import → provision → bootstrap →
  deploy → reboot. Remaining before M8: the OAuth credentials, and how
  rogue reaches `nixremote@ghost001` (rogue is not on the cslab tailnet;
  its daemon now logs "cannot build on ssh-ng://nixremote@ghost001").
- 2026-10-24 — **cslab OAuth working.** The cslab profile's OAuth client
  now comes from the shared `secrets/common/tsclient.age` (id) and
  `secrets/common/tssecret.age` (secret) — `cslab_mesh` points its
  `tsClientIdCslab`/`tsClientSecretCslab` rekeyFiles there (the
  `secrets/cslab/tsClient*Cslab.age` copies are unreferenced now).
  Rekeyed, redeployed: `neusis-tailscale-autoconnect` finishes
  ("Successfully obtained OAuth token", key expiry already disabled).
  Gotcha on the way: a deploy right after `agenix rekey` failed at eval
  with "Rekeyed secret … not found" — the new `rekeyed/` files were
  untracked and a git flake only sees tracked files; `git add` them
  first. Found pre-existing: activation logs `age: error: no identity
  matched any of the recipients` for `commonInitialHashedPassword`
  (`passwd -S ank` → locked) — `mkNeusisOS` declares it as a classic
  agenix `age.secrets.….file`, so `secrets/common/hashedInitialPassword.age`
  must be encrypted to each host key directly, and ghost001 is not among
  its recipients (master + three older hosts). Present since the
  bootstrap switch (journal 20:03); fix = re-encrypt with ghost001's
  host key added.
- 2026-10-24 — **ghost001 login fixed.** `secrets/common/hashedInitialPassword.age`
  re-encrypted with ghost001's host key added (recipients: master,
  shantanu, karkinos, oppy, ghost001; `age -d | age -R`, plaintext never
  on disk), redeployed: activation decrypts
  `commonInitialHashedPassword` cleanly. The account stayed locked
  anyway — with `users.mutableUsers = true` NixOS keeps an existing
  shadow entry, so the `!` from the first (failed) activation persisted;
  applied the declared hash once by hand (`usermod -p` from
  `/run/agenix/commonInitialHashedPassword`), `passwd -S ank` → `P`.
  Lesson for the runbook: a classic-agenix `.file` secret must list
  every new host as a recipient *before* its first switch, or the seeded
  password never lands.
- 2026-10-24 — **M8 done.** Drift check: both stacks `plan
  -detailed-exitcode` → 0 (the terranix wrappers forward `"$@"`, so the
  S3 note about scripts not taking arguments is outdated for `.plan`).
  `publicSsh = false` → apply (security list updated in place) → port 22
  closed from the internet after a few seconds, SSH over the tailnet
  fine → reverted, port open again ~5 s after apply; state committed.
  Data volume: `/dev/sdb` (150 GB) was attached raw; `mkfs.ext4 -L data`
  once, `fileSystems."/srv"` by label with `nofail` in `ghost001.nix`,
  deployed, mounted (147 GB free). rogue is on the cslab tailnet now
  (manual join + policy) and a probe derivation built on ghost001 via
  rogue's daemon with the builders restricted to `nixremote@ghost001`.
  Consumer surface: `flakeModules.default` imports the terranix
  modules, `oci-guest` and `lib/cloud.nix` (consumer smoke test
  extended). Docs: `docs/cloud/tutorial.md` runbook, AGENTS.md layout +
  commands + T4, `docs/testing.md` T4 rung, porting entry. T0 295/295,
  `go test ./...` green; T1/T2: the host checks instantiate and the two
  `tofu-validate-*` checks build. Left for later: wrapping the bake in a
  `neusis` subcommand (ghost001 is now a native aarch64 builder, so the
  ad-hoc VM recipe may not be needed), a `templates/cloud-oci` entry,
  yajna back on ghost001 once 0.8.x builds on aarch64.
- 2026-10-25 — **Cloudflare: stack + connector, waiting on secrets.**
  New terranix modules `cloudflare-provider` (token/account as
  `TF_VAR_cloudflare_api_token` / `TF_VAR_cloudflare_account_id`, zones
  by name via a `cloudflare_zones` lookup) and `cloudflare-tunnel` (per
  machine: `cloudflare_zero_trust_tunnel_cloudflared` + remotely-managed
  `_config` with ordered ingress + 404 catch-all, a proxied CNAME per
  service in its longest declared zone, the tunnel token as a sensitive
  output). Provider pinned by nixpkgs (`cloudflare_cloudflare` 5.19.1, v5
  resource names verified against `tofu providers schema`). Stack
  `cloudflare-leoank` (zone leoank.me, tunnel for ghost001, no services
  yet) with its `tofu-validate` check. Host side:
  `nixosModules.cloudflare-tunnel` runs `cloudflared tunnel run
  --token-file` with the token as a systemd credential (DynamicUser,
  hardened); ghost001 enables it with the `cfTunnelGhost001` secret (a
  placeholder encrypted to the master key until the first apply yields
  the token — runbook §9). T0 306/306, both validate checks build,
  `nixos-ghost001` instantiates. Not deployed to ghost001 yet (the unit
  would loop on the placeholder); next: Ankur adds the two TF_VARs, first
  apply, token → secret, deploy, then declare the first service.
- 2026-10-25 — **Cloudflare tunnel live on ghost001.** Ankur added
  `TF_VAR_cloudflare_api_token` / `TF_VAR_cloudflare_account_id` to the
  tf.env secret; the deployed `~/.config/neusis/tf.env` was still the old
  copy (no HM switch yet), so the stack ran with the vars sourced
  in-process from the `.age`. First apply: tunnel + remote config (404
  catch-all only), zone lookup fine with the token's scopes. Token went
  from `output -raw tunnel_token_ghost001` straight into
  `cfTunnelGhost001.age` via `age -r <master>` (no temp file —
  `agenix edit -i` refuses to overwrite the placeholder), rekeyed.
  Deployed from a clean worktree at HEAD (the main checkout carries
  unrelated rc2s2 work in progress): `cloudflared-tunnel` active as a
  DynamicUser, pulled the remote config (version 1), registered four
  QUIC connections (iad). The pipeline for a public service is now: one
  `services.<n>` entry → `apply` → the CNAME and ingress rule exist,
  nothing to deploy on the host.
