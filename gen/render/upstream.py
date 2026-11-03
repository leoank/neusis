"""Import the guides that live next to the code (neusis's docs/) into
src/upstream/, rewriting links so they keep working on the site.

Notebook links (`[[PRJ-0001]]`, `[[ID|label]]`) point at pages of the yajna
notebook under neusis's notes/, which the site doesn't publish; they become
links to the page on GitHub. Cross-repo (`[[ns/ID]]`) and unknown IDs are
left as written."""

from __future__ import annotations

import posixpath
import re
import shutil

from .context import Context, Entry

_LINK = re.compile(r"(!?)\[([^\]]*)\]\(([^)\s]+)\)")
_IMAGE = (".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp")
_WIKI = re.compile(r"\[\[([^\]|/@]+)(?:@\d+)?(?:\|([^\]]+))?\]\]")
_ID = re.compile(r"^id:\s*(\S+)", re.M)


def upstream_docs(ctx: Context) -> list[Entry]:
    dest = ctx.src / "upstream"
    shutil.rmtree(dest, ignore_errors=True)
    pages = _notebook_pages(ctx)
    for path in sorted((ctx.neusis / "docs").rglob("*.md")):
        rel = path.relative_to(ctx.neusis / "docs").as_posix()
        text = _LINK.sub(lambda m: _rewrite(ctx, rel, m), path.read_text())
        text = _WIKI.sub(lambda m: _wiki(ctx, pages, m), text)
        ctx.write(f"upstream/{rel}", text)
    return []


def _notebook_pages(ctx: Context) -> dict[str, str]:
    """ID → repo-relative path of every page in the notebook (frontmatter `id:`)."""
    notes = ctx.neusis / "notes"
    pages = {}
    for path in sorted(notes.rglob("*.md")) if notes.is_dir() else []:
        text = path.read_text()
        if text.startswith("---") and (m := _ID.search(text.split("---", 2)[1])):
            pages[m.group(1)] = path.relative_to(ctx.neusis).as_posix()
    return pages


def _wiki(ctx: Context, pages: dict[str, str], m: re.Match) -> str:
    ident, label = m.group(1).strip(), m.group(2)
    if ident not in pages:
        return m.group(0)
    return f"[{label or ident}]({ctx.source_url(pages[ident])})"


def _rewrite(ctx: Context, doc: str, m: re.Match) -> str:
    bang, label, target = m.groups()
    if re.match(r"^[a-z]+:|^#|^/", target):
        return m.group(0)
    path, _, frag = target.partition("#")
    resolved = posixpath.normpath(posixpath.join("docs", posixpath.dirname(doc), path))

    # A guide that's also on the site: keep the relative link.
    on_site = "upstream/" + resolved.removeprefix("docs/")
    if resolved.startswith("docs/") and on_site in ctx.nav_paths:
        # mdBook renders a README.md chapter as index.html, but turns a link
        # to README.md into README.html; point the link at index.md instead.
        if posixpath.basename(path) == "README.md":
            path = posixpath.join(posixpath.dirname(path), "index.md")
            return f"{bang}[{label}]({path}" + (f"#{frag}" if frag else "") + ")"
        return m.group(0)

    # Anything else (source files, unlisted docs): link to GitHub.
    if bang and resolved.lower().endswith(_IMAGE):
        url = ctx.repo_url.replace("github.com", "raw.githubusercontent.com") + f"/{ctx.rev}/{resolved}"
    else:
        url = ctx.source_url(resolved) + (f"#{frag}" if frag else "")
    return f"{bang}[{label}]({url})"
