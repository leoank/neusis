"""Import the guides that live next to the code (neusis's docs/) into
src/upstream/, rewriting links so they keep working on the site."""

from __future__ import annotations

import posixpath
import re
import shutil

from .context import Context, Entry

_LINK = re.compile(r"(!?)\[([^\]]*)\]\(([^)\s]+)\)")
_IMAGE = (".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp")


def upstream_docs(ctx: Context) -> list[Entry]:
    dest = ctx.src / "upstream"
    shutil.rmtree(dest, ignore_errors=True)
    for path in sorted((ctx.neusis / "docs").rglob("*.md")):
        rel = path.relative_to(ctx.neusis / "docs").as_posix()
        text = _LINK.sub(lambda m: _rewrite(ctx, rel, m), path.read_text())
        ctx.write(f"upstream/{rel}", text)
    return []


def _rewrite(ctx: Context, doc: str, m: re.Match) -> str:
    bang, label, target = m.groups()
    if re.match(r"^[a-z]+:|^#|^/", target):
        return m.group(0)
    path, _, frag = target.partition("#")
    resolved = posixpath.normpath(posixpath.join("docs", posixpath.dirname(doc), path))

    # A guide that's also on the site: keep the relative link.
    on_site = "upstream/" + resolved.removeprefix("docs/")
    if resolved.startswith("docs/") and on_site in ctx.nav_paths:
        return m.group(0)

    # Anything else (source files, unlisted docs): link to GitHub.
    if bang and resolved.lower().endswith(_IMAGE):
        url = ctx.repo_url.replace("github.com", "raw.githubusercontent.com") + f"/{ctx.rev}/{resolved}"
    else:
        url = ctx.source_url(resolved) + (f"#{frag}" if frag else "")
    return f"{bang}[{label}]({url})"
