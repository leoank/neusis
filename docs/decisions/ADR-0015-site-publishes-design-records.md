# ADR-0015: The documentation site publishes the architecture and every ADR, and links notebook IDs to their pages on GitHub

Status: accepted
Date: 2026-11-03

## Context
ADR-0001 put the design in `docs/architecture.md` and the decisions in `docs/decisions/`,
and listed as a consequence that the site would show their `[[ID]]` notebook links as
plain text. The site (the `gh-pages` branch) imports all of `docs/` but only puts pages
in the sidebar if `nav.md` lists them. Links to unlisted pages are rewritten to GitHub
URLs, so without nav entries the ADRs were reachable only through GitHub. Two link
problems remained:
- `[[PRJ-0001]]` rendered as raw brackets, because the site doesn't publish `notes/`.
- `porting.md`'s link to `decisions/README.md` was dead: mdBook renders a README chapter
  as `index.html` but turns a link to it into `README.html`.

Alternatives considered:
- **Publish `notes/` on the site.** It would mean rendering yajna's frontmatter and page
  types in mdBook. `yajna site` already renders the notebook, so a second renderer
  isn't worth it.
- **Leave the links as text.** Readers of `architecture.md` would lose the way to the
  project page that the document points them to.

## Decision
- `nav.md` on `gh-pages` lists *Architecture* and *Decisions* under *Development*, with
  every ADR as a child entry, and labels the porting log *frozen*. A new ADR gets a nav
  line when it lands.
- `gen/render/upstream.py` maps each notebook ID to its file through the page's `id:`
  frontmatter, and rewrites `[[ID]]` / `[[ID|label]]` to a link to that page on GitHub.
  Cross-repo links (`[[ns/ID]]`) and unknown IDs are left as written.
- The same file rewrites links to a listed `README.md` to point at `index.md`, which
  mdBook renders correctly.

## Consequences
- ADR-0001's "plain text on the site" consequence no longer holds.
- Adding an ADR is two edits on two branches: the record on `main` and its nav line on
  `gh-pages`. An ADR missing from `nav.md` is still imported, but links to it go to
  GitHub instead of staying on the site.
- Notebook links on the site lead out to GitHub, which renders the markdown but not
  yajna's links between pages.
