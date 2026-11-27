# ADR-0022: darwin programs that need a privacy grant run a copy signed by a launchd job with rcodesign, from self-signed keys kept in agenix

Status: accepted
Date: 2026-11-24

## Context
macOS keeps a privacy grant (TCC: Input Monitoring, Local Network, App Management, …) per
program, keyed by its signature's designated requirement. Nix builds are ad-hoc,
linker-signed, so the requirement is the build's cdhash: every rebuild is a new program to
macOS and the grant is gone. On rogue that means, after rebuilds:

| Program | Runs as | Grant lost | Seen |
|---|---|---|---|
| kanata | root launchd daemon | Input Monitoring: the keyboard stops remapping | 2026-11-19, kanata `vi58cvzv…` → `xc7wblmc…` |
| saarthi's node | ank's launchd agent | Local Network: the dialog returns | several times a day while saarthi moves fast |
| kitty | ank's app (`~/Applications/Home Manager Apps`) | App Management (and any other grant) | 2026-11-22, during the GC fix |

A signature from a fixed identity gives a requirement of `identifier "<id>" and
certificate root = H"<cert>"`, the same for every build, so a grant given once survives
rebuilds. EXP-20261123-gmpz81 (RUN-20261123-gmqqh7) checked the tool this rests on:
`rcodesign` (apple-codesign, in nixpkgs), signing from a PEM key and certificate with no
keychain, embeds that requirement, the same across two different builds, and the signed
binaries verify and run.

Alternatives considered:
- **A keychain identity and Apple's `codesign`** (the two scratch handoffs of 2026-11-18/19).
  The first signing with a new key asks "Always Allow", and an activation run by comin as
  root, or before login, cannot reach the login keychain. Rejected for unattended deploys.
- **An Apple Developer ID.** A paid account, and the key still has to live somewhere the
  activation can use; notarization buys nothing for programs only these machines run.
- **Signing at build time in the derivation.** The private key would enter the build
  sandbox and could end up in the world-readable store. Rejected.
- **One key for everything.** A home secret is readable by every process running as ank, and
  a user process holding kanata's key could sign a program as kanata and inherit Input
  Monitoring, that is, a keylogger. Rejected in favour of two keys.
- **Re-granting by hand after rebuilds** (today). Works, keeps happening.

## Decision
- **Two self-signed code-signing identities**, each a private key in agenix and its
  certificate in the repo (public):
  - `neusis-codesign-system`: a system secret, readable by root only, for system daemons
    (kanata);
  - `neusis-codesign-ank`: a home secret of ank's, for ank's programs (saarthi's node,
    kitty).
  ank creates the keys with `agenix edit` (the recipe is in `docs/darwin-signing.md`); no
  agent sees the plaintext.
- **A signing step in a launchd job of its own** (one darwin helper in neusis,
  `neusis.lib.darwinSigning.mkSignScript`, used by the modules): sign the store program
  straight into a fixed path outside the store with `rcodesign sign --pem-file <key>
  --pem-file <cert> --timestamp-url none --binary-identifier <id> <program> <copy>`, only
  when the store path changed (a stamp file beside the copy), then restart what runs it.
  The program runs from that copy.
  - Not an activation step (revised 2026-11-27, while building it): nix-darwin's agenix
    decrypts in its `activate-agenix` launchd daemon, beside activation and at boot, so the
    key may not exist yet when activation runs. The job waits for the key (up to a minute),
    and its plist names the program, so a rebuild reloads and reruns it.
  - No time-stamp server: rcodesign asks timestamp.apple.com by default; a grant needs no
    timestamp, and signing must not depend on the network.
  - System daemons' copies go to `/Library/Application Support/neusis/signed/<id>/` (a
    launchd daemon signs them); ank's to `~/Library/Application Support/neusis/signed/<id>/`
    (a launchd agent of his).
  - If signing fails (key missing, rcodesign error), keep the previous signed copy and
    warn; with no previous copy, run the store program and warn. Never fail the switch, and
    never leave launchd retrying.
- **Identifiers are fixed once and never changed**: `dev.leoank.kanata`,
  `dev.leoank.saarthi`, `dev.leoank.kitty`. A grant is tied to identifier and certificate.
- **Order**: kanata first (the grant that hurts most, and a single binary), then saarthi's
  node, then kitty. kitty is an app bundle with nested Python frameworks; signing a bundle
  with rcodesign gets its own experiment first.

## Consequences
- A grant is given once per machine and survives rebuilds, as long as the identifier and
  certificate stay the same. Rotating a certificate costs one re-grant per program.
- The signing jobs need `rcodesign`; the system key decrypts to `/run/agenix` (root
  only), ank's to ank's agenix directory.
- Any process running as ank can read ank's key, so it could sign a program as saarthi's
  node or kitty and inherit their grants (Local Network, App Management). Accepted:
  those grants are weaker than Input Monitoring, which stays behind the root-only key.
- saarthi's node module runs `lib.getExe cfg.package`; running the signed copy needs either
  an option in saarthi's module (the 2026-11-18 handoff) or a neusis-side package whose
  `bin/saarthi` points at the copy. Which one is settled when that step is built; whether
  TCC follows a symlink to the signed copy is checked by experiment then.
- Still unverified until it is built: that a real grant (kanata's Input Monitoring)
  survives a kanata rebuild. That check is the project page's *Stable signing 2*.
- The scratch handoffs `scratch/saarthi-stable-signing-handoff.md` and
  `scratch/kanata-stable-signing.md` are superseded by this record.
