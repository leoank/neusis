# old_modules — the pre-refactor (v1) tree

This directory is the complete pre-refactor neusis repository, moved
here verbatim when the dendritic `new_modules/` refactor was merged to
`main`. Nothing is evaluated from here by the top-level flake
(`flake.nix` only imports `new_modules/`); it is kept so that old
machine/home/package definitions remain greppable and buildable while
they are ported.

- `flake.nix` + `flake.lock` are the old top-level flake and its lock,
  so the tree is still a self-contained flake:
  `nix build path:./old_modules#darwinConfigurations.<host>.system`.
- `flake.nix.bak` is an intermediate refactor-era flake kept for reference.
- `scripts/` and `templates/` were promoted back to the repo root after the
  merge; the copies here are kept so this archive stays complete and its
  `flake.nix` (`templates = import ./templates;`) still evaluates. The root
  copies are the live ones.
- `homes/common/astroank` is a git submodule (see `.gitmodules` at the
  repo root).
- The same code is also archived at the `v1` tag / `v1` branch.

See `docs/porting.md` for what has been ported and what hasn't.
