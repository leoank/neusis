# Living with auto-updates — operator guide

**Audience:** Ankur, working on neusis day to day. How changes reach the
machines, how to try something before pushing, and what to do when the
pipeline holds. The design and its reasons are in
`docs/auto-update-spec.md`; the GitHub side is in
`docs/github-bot-setup.md`.

## How a change reaches a machine

```
you push (signed) to main ─┐
daily input bump (03:17 UTC)┴─► pipeline.yml: gates (tests, VM tests, every
                                 member's system and home build)
                                      │ green and signed
                                      ▼
                                deploy/canary ──► rogue's comin (polls every 60 s)
                                      │ after 24 h on canary
                                      ▼
                                deploy/stable ──► ghost001's comin (once enrolled)
```

- Work on `main` and sign your commits. An unsigned head (a web-editor
  commit, a merge made in the GitHub UI) holds every group until a
  signed commit follows.
- A commit reaches rogue about 35 minutes after it lands on `main`,
  mostly the rogue build in CI. You don't switch rogue yourself.
- Groups only fast-forward. A rollback is a revert on `main`, which goes
  through the same gates.
- Membership is `modules/registry/deploy-groups/anklab.nix`: `canary` is
  rogue, `stable` is ghost001.

## Trying a change before it goes out

| You want to | Do |
|---|---|
| see that it builds | `darwin-rebuild build --flake .#rogue` (or `nix build .#checks.aarch64-darwin.darwin-rogue`) |
| try uncommitted changes live | `darwin-rebuild switch --flake .#rogue` |
| try a commit live, without CI | `git push origin HEAD:testing-rogue` |
| ship it | `git push origin main` |

**Build only.** Nothing activates, so neither comin nor the switch check
is involved.

**Uncommitted changes, switched locally.** The switch check sees a dirty
tree and only warns. The change stays live until `deploy/canary` next
moves (your next green push, or the daily bump); then comin deploys the
branch over it. To keep it longer, suspend comin *after* the switch:

```
sudo comin suspend      # … and later: sudo comin resume
```

Whether a suspend survives comin restarting (a switch that changes its
config, a reboot) isn't verified; `sudo comin status` shows it. The blunt
alternative is unloading the daemon,
`sudo launchctl bootout system/com.github.nlewo.comin`, which the next
switch or a reboot undoes.

**A commit, on the testing branch.** comin also follows `testing-rogue`.
Push a signed commit there and rogue deploys it within a minute, with no
gates: only the signature is checked. When it works, push it to `main`;
the next `deploy/canary` commit replaces the test deploy.

**What the switch check refuses.** A manual switch to a *committed*
revision that neither `deploy/canary` nor `testing-rogue` contains, for
example a local commit you haven't pushed. comin would replace it within
minutes, and on a first enrollment it would remove comin. Push it to
`testing-rogue`, or skip the check once:

```
sudo mkdir -p /var/lib/neusis-auto-update && sudo touch /var/lib/neusis-auto-update/force-switch
```

A refused switch changes nothing; it also points the system profile back
at the running system, so a reboot doesn't pick up the refused
generation. Switching to exactly what a group runs always passes:

```
darwin-rebuild switch --flake github:leoank/neusis/deploy/canary#rogue
```

## Stopping and pausing

| Scope | How | Undo |
|---|---|---|
| one machine, for now | `sudo comin suspend` | `sudo comin resume` |
| a whole group | add its name to the repo variable `DEPLOY_HOLD` (space or comma separated) | remove it; the next run promotes |
| the daily bump | repo variable `UPDATE_INPUTS_PAUSED=true` | unset it |
| only some inputs | repo variable `UPDATE_INPUTS="nixpkgs home-manager"` | unset it (all inputs) |

The bump cadence is the `cron` line in `.github/workflows/update-inputs.yml`.

## Alerts

Failures open a GitHub issue labelled `auto-update` and send **one**
email (from ghcibot@leoank.me) when the issue opens; repeats only comment.
The next success closes it.

| Issue | Means | Usually |
|---|---|---|
| auto-update: input update failing | the daily bump's gates failed, or it couldn't land on `main` | an upstream break; the comment links the run |
| auto-update: `<group>` held | the group didn't move: red gates, an unsigned head, no fast-forward, or a commit that would unenroll a member | fix on `main`; a runner flake clears on the next green push or a re-run |
| auto-update: promotion failing | the promote job itself broke | a CI problem; see the run |
| (email only) auto-update failed on `<host>` | the host's switch failed | look at the host |

A failed **build** on the host isn't alerted (comin v0.14 has no hook for
it); the CI gate builds the same closure first, so it is rare.

## Looking at a machine

```
sudo comin status                          # what comin fetched, built and deployed
sudo comin fetch                           # poll now instead of within the minute
tail /var/log/neusis/auto-update.jsonl     # one line per deploy (darwin: with the Homebrew delta)
darwin-version --configuration-revision    # the commit the running system was built from
```

## Enrolling a machine

1. Add it to a group in `modules/registry/deploy-groups/anklab.nix`.
2. In its machine file import `inputs.comin.<nixos|darwin>Modules.comin`,
   `self.<nixos|darwin>Modules.auto-update` and
   `self.neusis.features.agnostic.auto-update`; for failure emails set
   `age.secrets.autoUpdateNotify.rekeyFile =
   ../secrets/common/auto-update-notify.age` and
   `neusis.services.auto-update.notify.environmentFile =
   config.age.secrets.autoUpdateNotify.path`, then `agenix rekey` (stage
   the rekeyed file).
3. Push, and **wait until the group's branch contains that commit**
   (for `stable`, 24 h after canary got it).
4. Switch the machine once: `… switch --flake
   github:leoank/neusis/deploy/<group>#<host>`. From then on comin keeps
   it current.

Step 3 matters: comin deploys its branch's head, and a head from before
the enrollment has no comin in it, so deploying it removes comin. The
switch check refuses an early switch for this reason.

## Unenrolling a machine

Take it out of its group (and drop its imports) in one commit. While it
is still listed in a group, promotion refuses a commit that turns its
comin off ("would unenroll"). Once comin deploys that commit it's gone
from the machine; nothing else is needed.
