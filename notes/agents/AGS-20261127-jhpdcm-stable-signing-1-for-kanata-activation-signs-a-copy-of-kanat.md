---
id: AGS-20261127-jhpdcm
type: agent_session
schema_version: 1
title: "Stable signing 1 for kanata: activation signs a copy of kanata with rcodesign from a root-only agenix key (ADR-0022)"
model: "claude-opus-5-5"
harness: "claude-code"
started: 2026-11-27T16:53+00:00
finished: null
created_entities: []
edited_entities: []
outcome: pending          # done | failed | aborted | pending
created: 2026-11-27
author: agent:claude
---

## Task

ank: "continue the macos keysigning work". The next step of ADR-0022 (still proposed) and
the project page's *Stable signing 1*: kanata runs a copy signed with rcodesign from a
root-only agenix key, so Input Monitoring survives rebuilds. Rests on [[EXP-20261123-gmpz81]];
the work stays under [[REV-20261123-gmqq87]].

## What happened

- Found while building: nix-darwin's agenix decrypts in its `activate-agenix` launchd
  daemon, not in activation, so the ADR's "signing step at activation" could run before the
  key exists (first switch, boot). The signing is a launchd job of its own instead, which
  waits for the key; its plist names the package, so a kanata rebuild reruns it. ADR-0022
  revised accordingly (still proposed).
- Found: rcodesign asks timestamp.apple.com for every signature by default. Signing now
  passes `--timestamp-url none` (no network dependence; a grant needs no timestamp). Also in
  the ADR.
- `modules/lib/darwin-signing.nix`: `neusis.lib.darwinSigning.mkSignScript`, the shared step
  (sign when the store program changed, keep the previous signed copy or run unsigned on
  failure, always exit 0).
- `neusis.services.kanata.darwin.signing.{enable,keyFile,certFile,identifier}`: the daemons
  run `/Library/Application Support/neusis/signed/dev.leoank.kanata/kanata`; the
  `kanata-sign` job (`org.neusis.kanata-sign`) signs it and kickstarts the daemons. Test
  `test-darwin-signing-runs-a-signed-copy`; T0 362/362 on both sets.
- Checked by hand, throwaway keys in the scratchpad, deleted after: rcodesign signs rogue's
  real kanata 1.11.0 store binary straight to an output path, the copy verifies strictly,
  runs, and carries `identifier "dev.leoank.kanata" and certificate root = H"…"`. The
  generated script went through six cases (first sign, idle rerun, no key with and without a
  signed copy, key back, a rebuild) and behaved as designed. Not a recorded run: these check
  the code, not a question.
- `docs/darwin-signing.md`: the key recipe for ank (`openssl` into `agenix edit -i`), the
  machine wiring, and the one-time grant.
- ank created the key; rogue opts in (`age.secrets.neusisCodesignSystem`, kanata
  `darwin.signing`), test `machine-rogue.test-kanata-runs-signed-copy`; T0 363/363.
- Not done: `agenix rekey -a` (ank's step) before rogue evaluates; and
  *Stable signing 2*, whether the real Input Monitoring grant survives a kanata rebuild,
  which needs the deployed job and a grant given by hand.
