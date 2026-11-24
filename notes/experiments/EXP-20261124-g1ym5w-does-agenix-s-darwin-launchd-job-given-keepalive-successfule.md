---
id: EXP-20261124-g1ym5w
type: experiment
schema_version: 1
title: Does agenix's darwin launchd job, given KeepAlive {SuccessfulExit=false} and a wrapper that clears unfinished generations, run once per load, re-run on a home-manager reload, and recover from a run killed mid-write?
project: PRJ-0001
status: concluded         # planned | active | paused | concluded | abandoned
outcome: positive         # null | positive | negative | inconclusive | infra
influenced_by: []
created: 2026-11-24
author: agent:claude
protocols: []
materials: []
tags: [agenix, darwin, launchd]
review: pending
---

## Question
On rogue, the launchd agent agenix's home-manager module installs (`activate-agenix`, ryantm/agenix
5e5b88a) re-decrypts ank's home secrets about every 10 s: by 2026-11-24 it was on generation
290,554 with a 550 MB stdout log. At 14:18 a switch killed it mid-run, and from then on every run
failed with `age: error: open …/agenix.d/290551/atuinKey.tmp: permission denied`, so the second
`ociTfEnv` update never reached `~/.config/neusis/tf.env` until the directory was removed by hand.

Upstream sets `KeepAlive = { Crashed = false; SuccessfulExit = false; }`. launchd reads
`Crashed = false` as "restart when it did not crash", which would explain the loop. Two candidate
home-manager modules for neusis:
- `keepalive.nix`: `KeepAlive = { SuccessfulExit = false; }` (restart only after a failure);
- `wrapper.nix`: run the mount script through `sh -c` that first removes every generation under
  `age.secretsMountPoint` except the one `age.secretsDir` points at.

Does the job with them run once per load, run again when a switch changes a secret, and recover
from what a killed run leaves behind? Which of the two does neusis need?

## Hypothesis and predictions
H1: `Crashed = false` causes the loop. If true, the upstream job runs 3 or more times in 35 s,
each a clean exit and a new generation; with `keepalive.nix` it runs once in 35 s. If false, the
upstream job also runs once and the loop on rogue has another cause.

H2: home-manager's reload on a switch (`bootout --wait`, `install`, `bootstrap`, the same calls
`setupLaunchAgents` makes when a plist changed) runs the `keepalive.nix` job once more and puts the
new secret in place. If false, a fixed job would leave changed secrets undecrypted until login.

H3: `keepalive.nix` alone does not heal a killed run: with a read-only `t.tmp` in the next
generation, every run fails with exit 1, retried every ~10 s, and the secret stays at the old
generation. If false (it recovers on its own), `wrapper.nix` is not needed.

H4: `keepalive.nix` + `wrapper.nix` clears that leftover: one run, exit 0, the next generation.

## Plan
1. [[RUN-20261124-g1z9kr]]: `run.sh` builds each variant as home-manager would install it
   (`mkhm.nix`: neusis's locked nixpkgs, home-manager and agenix; one throwaway secret, a
   throwaway age key, a scratch directory, a test label), loads it in ank's GUI domain, waits 35 s
   and reads the job's `runs` and `last exit code` from `launchctl print`, the generation the
   secrets symlink points at, and the decrypted test secret. Steps: (1) upstream, load;
   (2) `keepalive.nix`, load; (3) reload with a new secret value; (4) leave a read-only
   `agenix.d/3/t.tmp` and reload; (5) the same with `wrapper.nix`. ank's own agent and secrets
   are not touched; the scratch directory is deleted at the end.

## Success criteria
Each step's row in `results.tsv` matches its prediction (`ok = yes`): step 1 three or more runs;
steps 2, 3 and 5 exactly one run with exit 0 and the expected generation and secret; step 4 three
or more runs ending in exit 1 with the secret still at generation 2. All five holding means neusis
should add both modules for darwin; step 4 holding without step 5 means the wrapper needs another
design; step 1 failing means the loop has another cause and this fix is not it.

## Runs
One line per run after its link, what was tried and what it showed; `yajna validate`
rejects a bare link here. Metric runs also land in results.tsv.
- [[RUN-20261124-g1z9kr]] five loads of a test job on rogue: upstream reruns every ~10 s (4 runs in 35 s); `keepalive.nix` runs once per load, also on a reload with a new secret; over a killed run's leftover it fails forever; with `wrapper.nix` it clears it and succeeds once

## Conclusion
Draft for review. All four hypotheses held in [[RUN-20261124-g1z9kr]].

- H1: `Crashed = false` is what reruns agenix's darwin job: upstream ran 4 times in 35 s, each a
  clean exit and a new generation; with `KeepAlive = { SuccessfulExit = false; }` it ran once.
- H2: a reload as home-manager does it on a switch runs the fixed job once more and puts the new
  secret in place, so dropping the loop does not leave changed secrets behind.
- H3: the fixed KeepAlive does not heal a killed run: over the read-only `t.tmp` it failed every
  ~10 s with exit 1, the error seen on rogue, and the secret stayed at the old generation.
- H4: with the wrapper the same leftover was cleared and the job succeeded once.

For neusis: add both modules for darwin home-manager configurations that use agenix. The
KeepAlive change stops the rerun every ~10 s (and the log growing without end); the wrapper
makes a run killed by a switch or a logout recover at the next load instead of failing until
someone deletes the directory. Not shown: a real switch of rogue with them, which is the
check after building.
