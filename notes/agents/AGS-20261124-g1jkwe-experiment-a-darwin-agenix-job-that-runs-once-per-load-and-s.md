---
id: AGS-20261124-g1jkwe
type: agent_session
schema_version: 1
title: "Experiment: a darwin agenix job that runs once per load and survives a killed run"
model: claude-opus-5-5
harness: claude-code
started: 2026-11-24T14:36+00:00
finished: 2026-11-24T14:52+00:00
created_entities: [EXP-20261124-g1ym5w, RUN-20261124-g1z9kr]
edited_entities: [PRJ-0001]
outcome: done             # done | failed | aborted | pending
created: 2026-11-24
author: agent:claude
---

## Task
ank: "yes, set up the experiment for the agenix fix", after rogue's agenix job wedged on a
killed run and kept ~/.config/neusis/tf.env on the old key.

## What happened
- Pages first: [[EXP-20261124-g1ym5w]] (question, four hypotheses with predictions, success
  criteria) and [[RUN-20261124-g1z9kr]] with its script, then the run.
- The run builds each variant as home-manager would install it, on a test label, throwaway key
  and secret in a scratch directory; ank's own agent was not touched.
- All five steps as predicted. Conclusion drafted, `review: pending`; the project page has the
  experiment's line and a new *Progress* item for the neusis module.
- Recorded with `commit: unknown` until the script is committed. One output file was written
  again after a fix to the script line that extracts it (said in the run's Notes).
- Then, at ank's go: the module in `modules/homeModules/secrets.nix` (darwin only) with a test
  in `secrets.test.nix`, committed with the pages. The loop was already upstream as
  ryantm/agenix#372 (fix in PR #352, open); the wedge was new and is now ryantm/agenix#463,
  with the tested wrapper and an untested in-script alternative.
- Mid-task, ank's third `ociTfEnv` update committed and pushed on its own (4fa1083).
- Left for ank: a switch of rogue to check the agent (the project page's *Progress* item).
