---
id: AGS-20261111-h1kr9f
type: agent_session
schema_version: 1
title: "Onboard bbaum-pc-7 as curiosity: N1X live disk with secrets, tailnet and neusis checkout"
model: "claude-opus-5-5"
harness: "claude-code"
started: 2026-11-11T15:31+00:00
finished: null
created_entities: []
edited_entities: []
outcome: pending          # done | failed | aborted | pending
created: 2026-11-11
author: agent:claude
---

## Task

Ank, 2026-11-11, working from the anvesana repo (where Linux on bbaum-pc-7 was brought up):
onboard the laptop into neusis as `curiosity`, as a live disk he can boot with his secrets and
tailscale, to run Claude Code sessions there and change curiosity live; neusis checked out at a
fixed path. Answers to the setup questions: N1X support from the anvesana flake input; home
bundle, nix settings + distributed builds, secrets + tailscale + auto-update; findings document
in anvesana `docs/n1x-linux.md`, linked from here.

## What happened

- anvesana (commit b2bb0aa, branch exp/nvpcf-throttle): the live desktop image's GNOME parts
  moved into `nixosModules.n1x-desktop`; `docs/n1x-linux.md` written.
- `machines/curiosity.nix`: ISO from `iso-image.nix`, anvesana `n1x` + `n1x-desktop`,
  `acpi_osi="!Windows 2022"`, GNOME with autologin, agenix + secrets, distributed builds,
  cslab tailnet, comin. Host key pre-generated (public half in the file, age copy in
  `secrets/bootstrap/curiosity/`, private half on the SPARKDATA drive only), copied in by an
  initrd service (ADR-0020, proposed). ank's key optional from SPARKDATA; `gclb-sync` as a
  user service. New `live` deploy group so its kernel build never blocks canary or stable.
- Registry, ank's bundle map, the deploy-group and home tests updated; `tests/machines/
  curiosity.test.nix` added. T0 (`nix run .#neusis-test`) 335/335.
- Ank: no curiosity test yet, it is still iterated by hand. Removed `curiosity.test.nix`; a
  todo in notes/tasks.md brings it back. The registry, deploy-group and home tests keep their
  curiosity entries, since they pin the full lists and fail without them.
- Decided without asking: the `live` deploy group (not canary); curiosity's bundles (rogue's
  workstation set minus darwin-only and mail); Tailscale state not persisted (re-auth with
  force-claim each boot).
- Not done, needs Ank: `agenix rekey` on a machine with the master identity (curiosity has no
  rekeyed secrets yet, so its ISO does not build); optionally put ank's key on SPARKDATA; the
  CI `live` gate builds the N1X kernel.
- rc2s2 on curiosity (Ank): new `hmBundles.rc2s2-node-curiosity`, rogue's node settings minus
  the macOS-only seatbelt profile and keepAwake, plus the rc2s2 CLI. Its node token is a
  placeholder (`secrets/ank/rc2s2CuriosityNodeToken.age`, a dummy value encrypted to the master
  identity) until Ank issues the real one. T0 328/328.
