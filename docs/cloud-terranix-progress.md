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
