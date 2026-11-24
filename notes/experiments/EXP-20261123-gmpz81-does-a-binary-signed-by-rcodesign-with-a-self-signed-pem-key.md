---
id: EXP-20261123-gmpz81
type: experiment
schema_version: 1
title: Does a binary signed by rcodesign with a self-signed PEM key keep the same designated requirement across rebuilds?
project: PRJ-0001
status: concluded            # planned | active | paused | concluded | abandoned
outcome: positive             # null | positive | negative | inconclusive | infra
influenced_by: []
created: 2026-11-23
author: agent:claude
protocols: []
materials: []
tags: [darwin, codesign, tcc]
review: pending
---

## Question
macOS keeps a privacy grant (Input Monitoring, Local Network, App Management) per program,
keyed by its signature's designated requirement. Nix builds are ad-hoc, linker-signed, so
the requirement is the build's cdhash and every rebuild loses the grant: kanata's Input
Monitoring, saarthi's node's Local Network, kitty's App Management (all on rogue). The
plan is to keep a self-signed signing key in agenix and re-sign a copy of each binary at
activation with `rcodesign`, from a PEM file, without a keychain. Does a binary signed that
way get a designated requirement that stays the same from one build to the next?

## Hypothesis and predictions
H1: rcodesign embeds `identifier "<id>" and certificate root|leaf = H"<cert sha1>"`, so two
different builds signed with the same key and identifier carry the same requirement, and
each satisfies the other's. If false, the requirement falls back to the cdhash (as for an
ad-hoc build) or is missing, and we would have to compile one with `csreq` and pass it with
`--code-requirements-path`, or sign with Apple's `codesign` against a keychain after all.
(Stated in the session before the first probe: rcodesign's `--help` says it only adds a
requirement automatically for Apple-issued certificates, which made H1 uncertain.)

## Plan
1. Make a throwaway self-signed certificate with the codeSigning extended key usage
   (openssl, PEM), never the real key.
2. Build two binaries that differ by one string with `/usr/bin/cc` (ad-hoc,
   linker-signed, like Nix's).
3. Sign each with `rcodesign sign --pem-file … --binary-identifier dev.leoank.sigtest`.
4. Compare `codesign -d -r-` of the two, check build 2 against build 1's requirement and an
   ad-hoc build against it (it must fail), `codesign --verify --strict`, and run both.

## Success criteria
The two signed builds show the same requirement, embedded (no `#` before `designated`),
without a cdhash; build 2 satisfies build 1's and the ad-hoc build does not; both verify
and run. A pass supports building the agenix + rcodesign signing; the grants themselves
surviving a rebuild still needs a check on rogue with kanata after the change lands.

## Runs
One line per run after its link, what was tried and what it showed; `yajna validate`
rejects a bare link here. Metric runs also land in results.tsv.
- [[RUN-20261123-gmqqh7]] two builds signed by rcodesign from a PEM key: same embedded requirement (identifier + certificate root, no cdhash), cross-verified; every criterion met

## Conclusion
Yes. rcodesign 0.29.0, signing from a self-signed PEM key and certificate with no keychain
and a fixed `--binary-identifier`, embeds the designated requirement
`identifier "<id>" and certificate root = H"<cert sha1>"` (no cdhash), the same for two
different builds; each build satisfies the other's requirement, an ad-hoc build does not,
and both verify and run ([[RUN-20261123-gmqqh7]], with a hand probe before it giving the
same). rcodesign's `--help` says it adds a requirement automatically only for Apple-issued
certificates, yet it did here, so no `csreq` step is needed. For the project: macOS grants
keyed on that requirement can survive rebuilds, which ADR-0022 (proposed) builds on. Not
shown here: a real TCC grant surviving a rebuild (Progress, *Stable signing 2*) and signing
an app bundle with nested frameworks (kitty).

