# Auto-updates — architecture

Status: **decided** (2026-10-21/22; decisions in §14). Open items left are
in §13 and are external dependencies, not design choices. The build
plan is §15, and work that lands is logged in `docs/porting.md`.
Companion doc for the lab admin: `docs/attic-cache-setup.md`.

Goal: keep the fleet current without anyone running `nix flake update`
or `*-rebuild switch` by hand.

1. **Inputs loop.** Bump `flake.lock` daily. Run the full test ladder and
   build every host's system and image. Land the bump on `main` only if
   everything passes. If anything fails, alert by ntfy and email.
2. **Promotion.** Every commit on `main` goes through the same gates. A
   commit that passes moves the `deploy/<group>` branches forward, each
   group gated by its own machines. Groups update independently. The
   first groups are `canary` and `stable`.
3. **Hosts loop.** Each enrolled host runs **comin**. It polls its
   group's branch (every 60 s by default), checks the head commit's
   signature, and switches to its own configuration.
4. **Binary cache.** CI pushes what it builds to an attic cache on
   spirit, so a host downloads its update instead of compiling it.

---

## 1. Where neusis is today (the constraints)

- **Fleet:** `rogue` (aarch64-darwin, Ankur's laptop) and `ghost001`
  (aarch64-linux, OCI). `darwin001` **no longer exists**. It is still
  defined in `machines/darwin001.nix`, the anklab registry and
  `machineToBundlesMap`, and removing it is a separate cleanup commit
  (§15, M0). Nothing below includes it.
- Each host has a flake check: `checks.aarch64-darwin.darwin-rogue`,
  `checks.aarch64-linux.nixos-ghost001`, the `home-<user>@<host>`
  checks, and `checks.<sys>.pkg-oci-base-image` (ghost001's base
  image). These are the "full images" CI builds (§7).
- `deploy.nix` exposes `nixosConfigurations.<hostname>` and
  `darwinConfigurations.<hostname>`, which is the attribute comin builds
  by default.
- home-manager is **embedded** via `hm-system-init`, so a system switch
  also updates the homes.
- Secrets are agenix-rekey with rekeyed files **committed**
  (`modules/secrets/rekeyed/<host>/`). Evaluation needs no master
  identity, and a missing rekey is an eval failure, which is a safe
  no-op.
- `flake.nix` is generated (flake-file). `nix flake update` touches only
  `flake.lock`, and `check-flake-file` keeps the two in sync.
- CI today: T0 nix-unit, T1 instantiation and T2 packages on hosted
  runners, and T3 VM tests on pushes to `main`. No CI job builds a
  system closure.
- **Measured: rogue's system closure is 28.1 GiB.** A hosted macOS
  runner guarantees about 14 GB of free disk (§7.2).
- **Measured: 194 of the last 200 commits are SSH-signed**
  (`supercharged-git`, `~/.ssh/id_ed25519`).
- **Tailnets (measured from rogue):**
  - `spirit` and `oppy` are owned by `shntnu@` on the **`shntnu.github`**
    tailnet (`tail5e510f.ts.net`). **Ankur doesn't administer them.**
    They are identical NixOS boxes (384 threads, KVM).
  - `ghost001` is on **`leoank.github`** today (`ank_mesh`).
  - `rogue` has both profiles and is usually on `shntnu.github`.
  - **Decision (2026-10-22): every device lives on `shntnu.github`.**
    ghost001 moves there (its machine file swaps `ank_mesh` for
    `cslab_mesh`, a separate change made before M3), and CI joins it
    too (§8.3). There are no cross-tailnet shares.
- Homebrew on rogue (`machines/_homebrew.nix`): `upgrade = true`,
  `cleanup = "uninstall"`. **Unchanged by decision.** We collect data
  first (§9.4).
- Agnostic modules dispatch on `options ? systemd` / `options ? launchd`.
  Platform-specific upstream modules are imported per platform by the
  machine (the agenix pattern).

## 2. Design principles

1. **Pull, not push.** Hosts update themselves, with no inbound access.
2. **A failed build is a no-op.** A host activates only a successful
   build of a signed commit that CI promoted.
3. **`main` is history; `deploy/<group>` is what runs.** Humans push to
   `main` directly. Only CI moves the deploy branches.
4. **Groups are independent.** A group is held only by its own members'
   gates.
5. **Opt-in per machine:** import the feature, and be in a group.
6. **Tunables live in one place.** Groups, poll periods, soak times and
   signers are in the registry (Nix). The bump cadence is the `cron`
   line (§6.1). Pauses and holds are repo variables.
7. **Ask as little as possible of machines we don't control.** spirit
   only hosts the cache. CI builds on hosted runners, not on lab boxes.

## 3. Host tool: comin (decided)

comin v0.14.0 (2026-07, `github:nlewo/comin`) exports
`nixosModules.comin` and `darwinModules.comin` and deploys
`<kind>Configurations.<hostname>`. It polls git remotes and deploys only
on a new commit. Features we use:

- SSH or GPG signature checks on the **head commit**
  (`sshAllowedSignersPath`);
- per-host testing branches (`testing-<hostname>`, activated with
  `test`);
- `postDeploymentCommand`;
- retention;
- build and deploy confirmers and switch inhibitors;
- reboot detection;
- a Prometheus exporter and `comin status`.

The other tools surveyed and rejected are in the first revision of this
doc (git history): colmena (push, NixOS-only), deploy-rs (push),
`system.autoUpgrade` (NixOS-only timer), a hand-rolled timer, Cachix
Deploy (paid) and bento/morph/krops.

## 4. Branch model and deploy groups

### 4.1 Branches

| Branch | Writer | Meaning |
|---|---|---|
| `main` | humans (signed, direct) and the bot (signed lock bumps) | history; nothing runs from it |
| `auto/update-inputs` | bot, force-pushed | lock bump under test |
| `deploy/<group>` | bot only, **fast-forward only** | what that group's hosts run |
| `testing-<hostname>` | humans | comin trial branch (`test`, nothing persistent) |

Git can't hold a branch `deploy` next to branches `deploy/<group>`,
because `refs/heads/deploy` can't be both a file and a directory. So
every deploy branch is `deploy/<group>`.

### 4.2 Groups, in the registry

```nix
# modules/registry/deploy-groups/anklab.nix
flake.neusis.registry.deployGroups.anklab = {
  canary = {
    machines = [ m.ghost001 ];
    after = null;        # promote from a green main
    soakHours = 0;
    pollPeriod = 60;     # seconds; comin poller period for members
  };
  stable = {
    machines = [ m.rogue ];
    after = "canary";    # only commits canary has run …
    soakHours = 24;      # … for at least this long
    pollPeriod = 60;
  };
};
```

More groups come later. Each is one attrset with no code change. nix-unit
tests enforce these invariants:

- every enrolled machine is in exactly one group;
- group names are valid ref components;
- `after` chains are acyclic and name existing groups.

The feature looks up the host's group here. A machine file never
repeats it.

### 4.3 Promotion

For each group, commit `C` on `main` is promoted when **all** of these
hold:

1. **Shared gates** passed on `C`: T0, T1, T2 packages, T3 VM tests, and
   `check-flake-file`.
2. **Group gate** passed on `C`: every member's system check, plus its
   image and home checks if any, built in CI (§7).
3. **The head is signed by an allowed signer.** CI runs `git
   verify-commit` with the same file comin uses (§5).
4. `deploy/<group>` **fast-forwards** to `C` (`main` is linear).
5. If `after` is set: `C` (or a descendant) has been the head of the
   `after` group for at least `soakHours`. A scheduled `promote.yml`
   (hourly) re-checks soak-gated groups.
6. The group isn't listed in the repo variable `DEPLOY_HOLD`.

A group that fails a gate stays at its last good commit and alerts
(§6.4). Rollback is a **revert on `main`** that flows through the gates.
CI never moves a deploy branch backwards. Emergency stop: put the group
in `DEPLOY_HOLD`, or suspend comin on the host.

## 5. Commit signing (humans and CI)

- **Trust root:** `modules/registry/signers/anklab.nix`, a list of
  `{ principal; key; }` entries. Today they are ank's `id_ed25519` and
  the **bot key**. The feature renders it into an `allowed_signers` file
  (`namespaces="git"`; comin accepts only key entries and `namespaces=`)
  for `services.comin.sshAllowedSignersPath`. CI's `git verify-commit`
  uses the same render.
- **CI signing:** a dedicated ed25519 SSH key used only for lock-bump
  commits. The private half is an Actions secret in a GitHub
  **Environment** `auto-update` restricted to `main`. The public half is
  in the signers registry. Commits are signed with
  `git -c gpg.format=ssh -c user.signingkey=<file> commit -S`.
- **Rotation can't be hijacked:** hosts verify with the signers file of
  the config they are *running*. A commit that changes the signers must
  itself be signed by a currently trusted key.
- **github.com badge:** bot commits show *Unverified*, because a bot user
  can't register SSH signing keys. comin doesn't care.
- **Rejected:** API-created commits signed by GitHub's web-flow key. That
  key signs every web-UI and API commit by anyone with write access, so
  it is far too broad a trust root.
- **Unsigned heads** (web-editor commits, GitHub-made merges) are caught
  by promotion step 3. The group holds, and the alert says "unsigned
  head".

## 6. CI pipelines

Every bot action authenticates as the **GitHub App** `neusis-bot` (§10).

### 6.1 `update-inputs.yml`: daily lock bump

- **Trigger:** `schedule: cron: "17 3 * * *"` and `workflow_dispatch`
  (optional `inputs`: a space-separated subset). GitHub reads the cron
  from the YAML only, so **this line is the cadence knob**. Repo
  variables: `UPDATE_INPUTS` (default subset; empty means all) and
  `UPDATE_INPUTS_PAUSED`.
- **`bump`** (hosted):
  1. Mint an App token.
  2. Run `nix flake update [inputs]`, and exit with success if nothing
     changed.
  3. Commit `build(flake): update inputs`, with nix's per-input old→new
     list as the body and signed with the bot key.
  4. Force-push `auto/update-inputs`.
- **`gates`:** `gates.yml` (§6.3) on that commit.
- **`land`** (all gates green): fast-forward `main` to the commit. If
  `main` moved meanwhile, rebase, re-sign and push. The `main` pipeline
  then gates it again before any group sees it.
- **`alert`** (any gate red): §6.4.

### 6.2 `pipeline.yml`: every push to `main`

Runs `gates.yml` on the head, then promotion (§4.3). App-token pushes
trigger it; `GITHUB_TOKEN` pushes wouldn't. A bump that already passed
re-runs quickly, because the Linux closures substitute from attic.

### 6.3 `gates.yml`: the reusable gate set (`workflow_call`)

| Gate | Runner | What |
|---|---|---|
| T0 | ubuntu | `nix run .#neusis-test` (both sets) |
| T1 | ubuntu + macOS | instantiate every system's checks |
| T2 | ubuntu | `pkg-*`, `check-flake-file`, `tofu-validate-*` |
| T3 | ubuntu (KVM) | `vm-*`, now a gate on every candidate |
| **system/ghost001** | `ubuntu-24.04-arm` (native aarch64, free for public repos) | `nixos-ghost001`, `pkg-oci-base-image`, `home-ank@ghost001`, then `attic push` |
| **system/rogue** | `macos-latest` (experiment, §7.2) | `darwin-rogue`, `home-ank@rogue` |

The system matrix comes from the registry (`nix eval --json` over the
deploy groups), so enrolling a machine needs no YAML change. Each system
job reports a per-machine status that promotion reads.

### 6.4 Alerts: ntfy and email (plus a GitHub issue)

A single package, `neusis-notify` (`modules/packages/`), is used by CI
and by hosts. Usage: `neusis-notify --title … --priority … --tags … <body>`.
It sends to every configured channel and fails only if all of them
fail.

- **ntfy:** an HTTP `POST` to `${NTFY_URL}/${NTFY_TOPIC}` with an access
  token if set. Default server: ntfy.sh with a long random topic (the
  topic is the secret). Self-hosting on ghost001 is possible later, but
  ghost001 is a deploy target, so it shouldn't be the only alert path.
- **Email:** the **SendGrid** v3 API (`POST
  https://api.sendgrid.com/v3/mail/send`, `Authorization: Bearer
  $SENDGRID_API_KEY`) through `curl`, so no third-party Action is
  involved. It sends from `ghcibot@leoank.me` to `leoank98@gmail.com`
  by default; both addresses can be overridden (`ALERT_FROM`,
  `ALERT_TO`). SendGrid rejects mail from a sender it hasn't verified,
  so `ghcibot@leoank.me` (or the `leoank.me` domain) has to be verified
  in SendGrid once.
- **GitHub issue:** one rolling issue per failure kind ("input update
  failing", "promotion held: `<group>`", "unsigned head"). It is
  commented on each failure and closed on the next success, so there is
  a durable record of what ntfy and email announced.

Sources:

| Event | Sent from | Channels |
|---|---|---|
| bump gates failed | `update-inputs.yml` | ntfy + email + issue |
| group held (gate red, unsigned head) | `pipeline.yml` / `promote.yml` | ntfy + email + issue |
| a fixed failure recovered | same | ntfy (low priority) + closes the issue |
| host switch failed | comin `postDeploymentCommand` on the host | ntfy + email |
| host deployed successfully | same | ntfy (min priority; muteable) |

comin v0.14.0 runs `postDeploymentCommand` only after a *deployment*
(`COMIN_STATUS` = `done` or `failed`). Host-side **eval and build**
failures don't reach the hook. comin's unreleased `main` adds
`postBuildCommand`, and we adopt it once it's released. Until then, CI's
group gate (§6.3) builds the same closures first, so a host-side build
failure means something host-specific went wrong, and it shows in
`comin status`.

On hosts, the credentials (`SENDGRID_API_KEY`, `NTFY_TOPIC`, an
optional `NTFY_TOKEN`) are one agenix secret holding a dotenv file,
which `neusis-notify` reads (`--env-file`). In CI they are Actions
secrets of the same names.

## 7. Where the full builds run

### 7.1 Linux: hosted, native

ghost001 and its OCI base image build on GitHub's **`ubuntu-24.04-arm`**
runners (native aarch64, free for public repos), substituting from
cache.nixos.org and attic. Then the job pushes to attic with the CI
token. This keeps CI independent of spirit and oppy, which we don't
control. If a build ever outgrows the runner (time or disk), offload it
to spirit/oppy as remote builders over the tailnet (§8.3). That is a
config change, not a redesign.

### 7.2 Mac: an experiment, with the host as the backstop

rogue's closure (28.1 GiB) is bigger than a hosted macOS runner's
guaranteed free disk (about 14 GB). The images do ship many GB of
preinstalled Xcode versions and SDKs, and deleting them is a common way
to free space. The plan:

1. **Experiment (M4):** on `macos-latest`, remove the unused Xcodes,
   simulators and caches, measure the free space, then build
   `darwin-rogue` with substitution on and record the time and peak
   disk use.
2. **If it fits:** `system/rogue` becomes a real gate for `stable`. Don't
   push the result to attic. Only rogue consumes it, the upload would be
   large, and rogue has to reach attic over its `shntnu.github` profile
   anyway.
3. **If it doesn't:** the `stable` group's darwin gate is T1
   instantiation on macOS plus T0. The **real** build gate is rogue
   itself: comin builds, and a failure is a no-op plus an alert. This is
   the fallback, not the goal. Revisit if a Mac mini or another
   always-on Mac joins the fleet (as a self-hosted runner or remote
   builder).

Building on rogue over the tailnet from CI was considered and dropped.
rogue is a laptop, often asleep or on the other tailnet profile, so the
gate would be flaky.

## 8. Binary cache

### 8.1 Choice: attic on spirit

attic (self-hosted) on **spirit**, set up by the lab admin following
`docs/attic-cache-setup.md`:

- nixpkgs' `services.atticd`;
- SQLite plus local storage on spirit;
- zstd, content-defined chunking (daily rebuilds dedup);
- 30-day retention;
- listening only on `tailscale0`.

It holds one cache, `neusis`, public-read inside the tailnet. Ankur
gets an owner token for the `neusis*` caches, and CI gets a push token.

`oppy` (identical) can run the same config later as a **second,
independent** cache. CI would push to both and hosts would list both,
for redundancy. It isn't needed to start.

### 8.2 Options considered

| Option | Why not (now) |
|---|---|
| harmonia / nix-serve-ng on spirit's own store | It's tied to a shared lab store's GC and has no retention of its own. |
| niks3 + Cloudflare R2 | Good for reads off the tailnet and offsite durability. A later step if spirit's availability becomes an issue. |
| attic on ghost001 with R2 or OCI Object Storage | Fully under Ankur's control. **This is the fallback if the admin declines** (§13, Q1). |
| Cachix / FlakeHub Cache | Paid at these sizes. |
| magic-nix-cache | CI-only, and hosts can't read it. |
| Cloudflare tunnel in front of spirit | Not needed, since everything is on Tailscale, and it can't carry pushes: proxied request bodies are capped (100 MB on Free), and single NARs exceed that. Only relevant later for public read-only access. |

### 8.3 Reaching the cache: one tailnet

Every device lives on `shntnu.github`:

| Client | Reaches `spirit:8080` |
|---|---|
| rogue | directly (its `cslab` profile) |
| ghost001 | directly, once it moves to `cslab_mesh` (§1) |
| CI jobs | as an **ephemeral node tagged `tag:neusis-ci`**, joined with `tailscale/github-action` and an OAuth client the admin issues for that tag. A policy rule lets `tag:neusis-ci` reach only `spirit:8080` (and later `oppy:8080`). |

Moving ghost001 also closes a latent gap: it lists spirit and oppy as
remote builders, but it can't reach them from `leoank.github` today.

### 8.4 Client side: `features.agnostic.neusis-cache`

An opt-in feature that adds the substituter
(`http://spirit.tail5e510f.ts.net:8080/neusis`) and its public key, with
`connect-timeout = 5` and `fallback = true`. When spirit is unreachable,
a deploy costs a few seconds and then substitutes from cache.nixos.org
or builds as today.

## 9. Host side: the comin feature

### 9.1 Code by layer

| Layer | File | Content |
|---|---|---|
| input + module | `modules/agnosticModules/auto-update.nix` | `flake-file.inputs.comin = { url = "github:nlewo/comin/v0.14.0"; inputs.nixpkgs.follows = "nixpkgs"; }` and the reusable `neusis.services.auto-update` module (re-exported as `{nixos,darwin}Modules.auto-update`). It turns `url`, `branch`, `pollPeriod`, `signers` and `notify.*` into one comin remote, `sshAllowedSignersPath` and the `postDeploymentCommand` hook (§9.4), and pins `services.comin.package` to the comin flake. It configures comin but does not import it (an import can't depend on the platform). |
| registry | `modules/registry/deploy-groups/anklab.nix`, `modules/registry/signers/anklab.nix` (schema in `lib/neusis-options.nix`, helpers in `lib/auto-update.nix`) | §4.2, §5 |
| feature | `flake.neusis.features.agnostic.auto-update` | anklab policy, config only: this repo's URL, the branch and poll period of the host's group, the anklab signers, and mail from `ghcibot@leoank.me` to `leoank98@gmail.com`. A host in no group fails an assertion. |
| package | `modules/packages/neusis-notify/` | §6.4 |
| cache | `flake.neusis.features.agnostic.neusis-cache` | §8.4 |
| machine | `machines/<host>.nix` | `imports = [ inputs.comin.<nixos\|darwin>Modules.comin self.<nixos\|darwin>Modules.auto-update self.neusis.features.agnostic.auto-update self.neusis.features.agnostic.neusis-cache ];` plus `neusis.services.auto-update.notify.environmentFile` once the notify secret exists. |

### 9.2 Configurability

| Knob | Where | Default |
|---|---|---|
| poll period | `deployGroups.<g>.pollPeriod`; per machine via `services.comin.remotes` | 60 s |
| branch | the host's group → `deploy/<group>` | — |
| order and soak | `deployGroups.<g>.{after,soakHours}` | stable: after canary, 24 h |
| bump cadence | the `cron` line in `update-inputs.yml` | daily 03:17 UTC |
| inputs bumped | `UPDATE_INPUTS` variable / dispatch input | all |
| pause / hold | `UPDATE_INPUTS_PAUSED` / `DEPLOY_HOLD` | off |
| alert channels | `NTFY_*` / `SENDGRID_API_KEY` / `ALERT_FROM` / `ALERT_TO` (CI secrets, host agenix env file) | ntfy + email (`ghcibot@leoank.me` → `leoank98@gmail.com`) |

### 9.3 A deploy on a host

1. The poller sees a new head on `deploy/<group>` and verifies its
   signature. A missing or unknown signature means skip and alert.
2. Evaluate `<kind>Configurations.<host>` from comin's checkout.
3. Build: mostly substitution from attic (ghost001); rogue builds most
   of its own closure. **A failure stops here**: the system stays put,
   comin retries per `buildAttemptsLimit`, and an alert goes out.
4. Switch (agenix, embedded home-manager, Homebrew on rogue).
5. `postDeploymentCommand`: §9.4.

### 9.4 Deploy log and Homebrew data

Homebrew stays as it is. The post-deployment command:

- appends one JSON line per deploy to `/var/log/neusis/auto-update.jsonl`:
  time, host, status, commit, ref (`origin/deploy/<group>`), comin
  generation and error. comin doesn't pass timings to the hook, so
  durations come from `comin status`;
- on darwin, also records the Homebrew delta (a diff of `brew list
  --versions` and `brew list --cask --versions` against the previous
  entry);
- calls `neusis-notify`. A failure is high priority, ntfy plus email; a
  success is min priority, ntfy only.

After a few weeks of data we decide about `upgrade` and `cleanup`.

## 10. GitHub App or a token? An App

One App, `neusis-bot`, installed only on `leoank/neusis`, with
Contents (write), Issues (write), Pull requests (write) and Actions
(read).

| | GitHub App | Fine-grained PAT |
|---|---|---|
| Identity | `neusis-bot[bot]` | acts **as you** |
| Token life | minted per run, 1 h | long-lived, rotate by hand |
| Triggers workflows | yes | yes |
| Ruleset bypass | the App can be the *only* actor allowed to move `deploy/*` | bypass would mean "you", with no separation from your pushes |
| If leaked | short-lived, one repo | until expiry, whatever it covers |
| Setup | create the App; `APP_ID` variable + private-key secret | one token |

Rulesets:
- `deploy/*`: only neusis-bot creates or updates; no force pushes or
  deletions.
- `main`: no force pushes or deletions, and your direct pushes keep
  working.

## 11. Security model

- Root on an enrolled host requires a commit that is **signed by a
  trusted key** and **promoted by CI**. Write access to `main` alone
  isn't enough.
- Secrets that matter:
  - the bot signing key (Environment, `main` only);
  - the App private key (can move branches, can't forge signatures);
  - your SSH key;
  - the attic tokens: the push token can poison the cache, which is
    mitigated by the hosts' `trusted-public-keys` plus attic's own
    signing;
  - the notify credentials (low impact).
- CI's Tailscale node is ephemeral and tagged, and reaches only
  `spirit:8080`.
- Hosts need no write credential and no inbound access.
- **spirit is a third-party-run machine serving our closures.** Its
  admin could in principle substitute content, but attic signs with a
  key that lives on spirit. Accepting that is part of using spirit. If
  that isn't acceptable, CI can sign with our own key (`nix store sign`
  before the push) and the hosts can trust only that key. We take this
  option: see §14.

## 12. Out of scope (for now)

- Standalone `home-manager switch` homes.
- Automatic reboots for kernel changes on ghost001 (comin reports
  `need_to_reboot`, and the success notification says so).
- Automatic rollback on health checks.
- Consumer repos.

## 13. Open items (external)

1. **The admin applies `docs/attic-cache-setup.md`.** They have agreed.
   That covers atticd on spirit, the tokens and the `tag:neusis-ci`
   OAuth client.
2. **SendGrid sender verification** for `ghcibot@leoank.me` (single
   sender, or domain authentication for `leoank.me`), plus the
   `SENDGRID_API_KEY` Actions secret (Ankur).
3. **ntfy topic:** pick a long random topic on ntfy.sh, stored as the
   `NTFY_TOPIC` secret.

## 14. Decisions

2026-10-22:

- **One tailnet: `shntnu.github`** for every device and for CI. No
  shares; ghost001 moves over.
- **Email via SendGrid** from `ghcibot@leoank.me` to
  `leoank98@gmail.com`. The API key comes from the environment
  (`SENDGRID_API_KEY`).
- **The admin agrees** to run attic on spirit.
- **comin pinned to `v0.14.0`.** Its package comes from the comin flake,
  not nixpkgs, so the binary matches the module's config schema.

2026-10-21:

- **comin** on NixOS and nix-darwin.
- **Daily** input bumps. They land on `main` only when every gate is
  green; otherwise there is an alert. The cadence is the cron line, and
  the subset and pause are repo variables.
- **60 s poll** by default, configurable per group and per machine.
- **Signed commits everywhere.** CI signs with a dedicated SSH key.
  comin and CI verify against one signers registry.
- **Deploy branches `deploy/<group>`.** The first groups are `canary`
  (ghost001) and `stable` (rogue, after canary plus a 24 h soak). More
  groups come later, as registry entries.
- **Homebrew unchanged.** Collect per-deploy data (§9.4).
- **CI builds the full systems and images.** Linux natively on hosted
  arm64 runners. Mac on hosted macOS as an experiment, with rogue's own
  comin build as the backstop.
- **Binary cache: attic on spirit**, set up by the lab admin; oppy is an
  optional second cache. Reached over Tailscale. No Cloudflare tunnel.
- **Our own signing key for cached paths.** CI runs `nix store sign`
  with a neusis cache key before `attic push`, and hosts trust that key
  for the attic substituter. Trust then doesn't depend on spirit's
  operator.
- **Alerts:** ntfy and email from CI and hosts, plus a rolling GitHub
  issue from CI.
- **Bot auth: a GitHub App.**
- **darwin001 is gone.** It's removed from the repo in its own cleanup
  commit.

## 15. Build plan

Each milestone ends at the listed check:

0. **M0 Cleanup:** remove darwin001 (machine file, registry,
   `machineToBundlesMap`, `home-kumarank@darwin001`, its rekeyed
   secrets, its tests). Check: T0 + T1.
1. **M1 Registries:** deploy groups and signers, with options and
   nix-unit invariants. Check: T0 + T1.
2. **M2 `neusis-notify` + the comin feature:** the input (`write-flake` +
   lock), the feature and tests, and the notify package. Plus a
   `vm-auto-update` T3 test with a local bare repo inside the VM, in
   which:
   - a signed good commit switches;
   - a broken commit is a no-op with a notification (to a stub ntfy in
     the VM);
   - an unsigned commit is refused.

   Check: T0, T1, T3.
3. **M3 Cache:** the admin applies `docs/attic-cache-setup.md`. We
   create the cache and add the `neusis-cache` feature and the cache
   signing key. Before this, ghost001 moves to `cslab_mesh`. Check: a
   push from rogue, then substitution on ghost001.
4. **M4 CI builds:** the App, the `tag:neusis-ci` OAuth client, `gates.yml`
   (with the arm64 ghost001 build + sign + push), and the macOS rogue
   experiment. Check: a dispatched run builds and pushes ghost001, and
   the experiment is recorded either way.
5. **M5 Pipelines:** `update-inputs.yml`, `pipeline.yml`,
   `promote.yml`, alerts and rulesets. Check: a dispatched bump lands
   and promotes canary; a deliberately broken bump fires ntfy, email
   and the issue.
6. **M6 Enroll:** ghost001 (canary), then rogue (stable). Check: a
   deploy visible in `comin status`, the JSONL log and ntfy.

### Risks to retire

| # | Question | In |
|---|---|---|
| R1 | Does comin's darwin module work with nix-darwin 26.05 (root-only activation, `system.primaryUser`, Homebrew activation as the primary user)? Partly answered: comin v0.14 runs `$out/activate-user` and then `$out/activate`. In 26.05, `activate-user` is a deprecated stub that warns and exits 0, so activation works today, but comin breaks once nix-darwin removes the stub (announced for after 25.11). Watch comin releases. | M6 (rogue) |
| R2 | Can a host evaluate from comin's checkout with no master identity? | M2, M6 |
| R3 | Does rogue's closure build on a hosted macOS runner after freeing disk? | M4 |
| R5 | Can a GitHub App be a ruleset bypass actor on a personal-account repo? | M5 |
| R6 | Do comin retention and `nix.gc.automatic` agree? | M6 |
| R7 | ~~What does comin pass to the hook?~~ Answered from the v0.14.0 source: `COMIN_GIT_SHA`, `COMIN_GIT_REF`, `COMIN_GIT_MSG`, `COMIN_HOSTNAME`, `COMIN_GENERATION`, `COMIN_STATUS` (`done`/`failed`) and `COMIN_ERROR_MSG`, after deployments only (§6.4). | — |
| R8 | Does attic keep the signatures already on pushed paths (our `nix store sign` key) in the narinfo it serves, so hosts can trust only our key? If not, trust attic's key and accept spirit's operator in the trust base (§11). | M3 |
