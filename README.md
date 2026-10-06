# neusis documentation site

Source for <https://leoank.github.io/neusis/>. This is an orphan branch;
the neusis code itself is on `main`.

```sh
nix run .#serve                                        # live preview
nix run .#serve --override-input neusis path:../main   # preview against a local checkout
nix build .#site                                       # full build → ./result
```

```text
book.toml        mdBook config
nav.md           the sidebar — the one file to touch when adding/moving pages
src/             hand-written pages
theme/           CSS overrides
gen/             generators for the reference section (see src/contributing/docs-site.md)
flake.nix        pins the neusis being documented (input `neusis`)
.github/         Pages deploy workflow
```

Generated files (`src/SUMMARY.md`, `src/reference/*` except `index.md`,
`src/upstream/`) are gitignored.
