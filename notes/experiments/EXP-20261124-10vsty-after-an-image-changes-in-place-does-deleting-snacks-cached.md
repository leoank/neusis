---
id: EXP-20261124-10vsty
type: experiment
schema_version: 1
title: After an image changes in place, does deleting snacks' cached conversion and clearing its in-memory images make snacks show the new contents?
project: PRJ-0001
status: concluded            # planned | active | paused | concluded | abandoned
outcome: positive             # null | positive | negative | inconclusive | infra
influenced_by: []
created: 2026-11-24
author: agent:claude
protocols: []
materials: []
tags: [kalam, snacks, images]
review: pending
---

## Question
kalam renders images with snacks.nvim's `image` module (defaults). snacks converts each
source with ImageMagick into `stdpath("cache")/snacks/image/<sha256(path..page)[1:8]>-<name>.<ext>`
and skips a conversion step whenever that output file exists; loaded images are also kept
in a per-session table keyed by the converted file. Reading the code suggests an image
edited in place keeps showing its old conversion. Does deleting the cached files for it
and calling `Snacks.image.image.clear()` make snacks produce and use a conversion of the
new contents, so a `:KalamImageRefresh` command can rely on that?

## Hypothesis and predictions
H1 (staleness): after the source changes, converting it again yields the *old* output
(same file, same hash), because the step is skipped when the output exists.
H2 (refresh): after deleting `<prefix>.*` from the cache, converting again yields output
whose pixels match the new source.
H3 (memory): `Snacks.image.image.new(src)` returns the same object for the same source
until `Snacks.image.image.clear()`, and a new one after it.
If H1 is false, the command is unnecessary for in-place edits. If H2 is false, deleting
the cache is not enough (another cache layer exists). If H3 is false, `clear()` is not
needed or not sufficient, and the command must reset something else.

## Plan
1. kalam built from the repo (`.#kalam`), headless, with `XDG_CACHE_HOME` pointed at a
   temp dir, so the real cache is untouched; ImageMagick from flake.lock's nixpkgs.
2. Make a 64×64 red PNG; convert it with `Snacks.image.convert.convert{src}`; record the
   output path and the colour of its centre pixel.
3. Overwrite the source with blue at the same path; convert again; record (H1).
4. Delete the cache files with that prefix; convert again; record (H2).
5. `image.new(src)` twice, `clear()`, `image.new(src)` again; compare identities (H3).
   Headless has no graphics terminal; if `image.new` cannot run there, record that and
   leave H3 to a check in kitty.

## Success criteria
H1 and H2 hold (the stale output stays red; after deletion the output is blue), and H3
holds or is shown untestable headless. Then the command is: delete the cache files of the
current buffer's images (or the whole cache), `clear()`, re-edit the buffer.

## Runs
One line per run after its link, what was tried and what it showed; `yajna validate`
rejects a bare link here. Metric runs also land in results.tsv.
- [[RUN-20261124-10vt37]] PNG and JPEG edited in place: the JPEG's cached conversion stays stale until deleted (PNG has none); clear() gives fresh image objects for both; H2 and H3 hold, H1 holds for converted formats only

Still open, by hand in kitty after the switch (headless has no graphics terminal, and
kitty's remote control is not reachable from an agent shell): open a markdown file with a
JPEG and an image-file buffer, overwrite the JPEG, run `:KalamImageRefresh`; both should
show the new picture without `:edit`. The command re-places a document's images through
the inline update (`BufWinEnter`) because `:edit` keeps `vim.b.snacks_image_attached` and
would not re-attach; that path is read from snacks' code, not yet seen working.

## Conclusion
Yes, for what snacks keeps. A JPEG (any format snacks converts) is converted into
`snacks/image/<hash of the path>-<name>.png`; after the source changes in place the
conversion stays stale, and once it is deleted the next conversion has the new contents. A
PNG is used as is, so it has no stale copy on disk. For both, `Snacks.image.image.new`
returns the old loaded image until `Snacks.image.image.clear()`, a new one after it
([[RUN-20261124-10vt37]]; a first PNG-only run suggested no staleness at all, which the JPEG
case corrected). For the project this is what `:KalamImageRefresh` does (1437e2f), plus
re-placing the buffer's images, since `:edit` would not re-attach a document. Not shown
headless: kitty drawing the new picture after the command, a check of the command left to
ank.

