# ADR-0003: flake.neusis.* is a typed schema, and every module that writes under it imports the options that declare it

Status: accepted
Date: 2026-05-31
Backfilled: 2026-11-03, from `porting.md` (*The single most important rule*, *Schema
cheat sheet*, the 2026-05-31 entry's schema section and *Patterns*).

## Context
With ADR-0002, users, registries, machines, features and lib helpers are written into
`flake.neusis.*` from many files. Without a declared option, flake-parts treats
`flake.neusis` as freeform `raw`, and two files writing under it fail to merge
("defined multiple times while it's expected to be unique"). Typing the data also
mattered: storing data attrsets in `listOf deferredModule` silently wraps each entry in
`{ imports = [ … ]; }`, so fields like `username` go missing.

No untyped alternative was recorded; the freeform behaviour is the failure this
decision avoids.

## Decision
- `modules/lib/neusis-options.nix` declares the schema: users, `hmBundles`,
  `machineToBundlesMap`, registries, `machines.<name>` (`machineType`), features, lib
  namespaces, and later deploy groups, signers and terranix modules.
- Every `flakeModules.*` export that writes under `flake.neusis.*` imports that options
  module first, so consumers get the same merge semantics.
- `deferredModule` only for values that are modules; data uses `attrs`, `listOf attrs`
  or typed submodules. Lib namespaces are `lazyAttrsOf raw`: one file per namespace.
- New data extends the existing types rather than adding loose `flake.neusis.<x>`
  attributes.

## Consequences
- Contributions from many files merge, and type errors point at the bad value.
- Schema changes touch `neusis-options.nix`, and consumer repos see them through
  `flakeModules.default`.
- Exposing `roleSpecs` as an option is still open (`future-considerations.md`).
