# About this site

The site's source is on the `gh-pages` branch of
[leoank/neusis](https://github.com/leoank/neusis/tree/gh-pages). It's an
[mdBook](https://rust-lang.github.io/mdBook/) built by a small Nix flake.
Content comes from three places:

| Where | What | Edit it in |
|---|---|---|
| `src/` | hand-written guide pages (like this one) | the `gh-pages` branch |
| `src/upstream/` | the tutorials and dev docs from neusis's `docs/` | `docs/` on `main` |
| `src/reference/` | everything under **Reference**, generated from the source | the neusis source on `main` |

The sidebar is defined in one file, `nav.md`.

## Common changes

- **Edit or add a guide page:** add a Markdown file under `src/` and list it
  in `nav.md`.
- **Publish another doc from `main`:** list `upstream/<path under docs/>` in
  `nav.md`. Links in it to other listed docs stay relative. Links to source
  files, or to docs that aren't listed, are rewritten to GitHub URLs.
- **Fix a reference page:** change the option `description`, the comment
  above the function, or the cobra `Short`/`Long` text in neusis itself.
- **Restyle:** `theme/neusis.css`, and the `[output.html]` table in
  `book.toml`.

## Preview

From the `gh-pages` worktree:

```sh
nix run .#serve                                        # docs for github:leoank/neusis (locked rev)
nix run .#serve --override-input neusis path:../main   # docs for your local checkout
```

Hand-written pages reload live. If you change `nav.md` or the neusis source,
restart `serve`.

To do a full build the way CI does:

```sh
nix build .#site && open result/index.html
```

## How generation works

```text
gen/options.nix   evaluate homeModules / darwinModules / the flake schema,
                  keep the options neusis declares        → <scope>.json
gen/meta.nix      lib function positions + args, templates, packages → meta.json
gen/cli/          compile a docgen helper against the CLI's cobra tree → cli.json
gen/render/       Python: JSON + source comments → src/reference/*.md,
                  docs/ → src/upstream/, nav.md → src/SUMMARY.md
gen/site.nix      ties it together and runs `mdbook build`
```

Inline code that names something the reference documents (an option,
module, feature, flakeModule, lib function or CLI command) is linked to
its reference page by an mdBook preprocessor, `gen/autolink.py`, on every
page, including hand-written and upstream ones. The term index,
`symbols.json`, is written by the generators. Each one registers what it
documents with `ctx.symbol(term, "page.md#anchor")`. Terms that could mean
something else are deliberately left out, such as single-word names like
`tailscale` or names registered for two different pages. Code blocks,
headings and code that is already part of a link are never touched.

Each generated section is one function in `gen/render/`, registered in
`GENERATORS` in `gen/render/__main__.py`. A marker comment `gen:<name>`
on its own line in `nav.md` inserts that generator's pages into the
sidebar. To add a section, write the function, register it, and add the
marker.

## Deploying

Two workflows publish the site to GitHub Pages, and they build it the same way:

- `.github/workflows/pages.yml` on `gh-pages` runs on every push to this
  branch. It updates the `neusis` input to the tip of `main`, then builds.
- `.github/workflows/docs.yml` on `main` runs when something the site
  documents changes (`modules/`, `cli/`, `docs/`, `templates/`, the flake).
  It checks out this branch and builds against the commit just pushed.

Both can also be started by hand from the Actions tab.
