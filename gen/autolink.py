#!/usr/bin/env python3
"""mdBook preprocessor: link inline `code` that names something the
reference documents (an option, module, feature, lib function, CLI
command, …) to its reference page.

The term → page index is symbols.json at the book root, written by
gen/render (see `_write_symbols` and the `ctx.symbol(...)` calls in each
generator). Code blocks, headings, and code that is already part of a
link are left alone, as are terms that would link a page to itself.
Without symbols.json this is a no-op.
"""

from __future__ import annotations

import json
import posixpath
import re
import sys
from pathlib import Path

_FENCE = re.compile(r"^\s*(```|~~~)")
_HEADING = re.compile(r"^ {0,3}#{1,6}\s")
_LINK = re.compile(r"!?\[(?:[^\[\]]|\[[^\]]*\])*\]\([^)]*\)|<https?://[^>]+>")
_CODE = re.compile(r"(?<!`)(`+)(?!`)(.+?)(?<!`)\1(?!`)")


_PLACEHOLDER = re.compile(r"^<[\w-]+>$")
_IDENT = re.compile(r"^[\w<>*-]+(\.[\w<>*\"-]+)+$")


def _wildcard(term: str, symbols: dict[str, str]) -> str | None:
    """Match an instance or placeholder path against documented `<name>` /
    `*` paths: `flake.neusis.users.alice` and `flake.neusis.users.<u>` both
    resolve via `flake.neusis.users.<name>`. Only a unique target counts."""
    parts = term.split(".")
    targets = set()
    for key, target in symbols.items():
        kparts = key.split(".")
        if len(kparts) != len(parts) or not any(_PLACEHOLDER.match(k) or k == "*" for k in kparts):
            continue
        if all(k == p or _PLACEHOLDER.match(k) or k == "*" or _PLACEHOLDER.match(p) for k, p in zip(kparts, parts)):
            targets.add(target)
    return targets.pop() if len(targets) == 1 else None


def resolve(term: str, symbols: dict[str, str]) -> str | None:
    term = re.sub(r"\.\*$", "", term.strip().rstrip(";").strip())
    if term in symbols:
        return symbols[term]
    if _IDENT.match(term):
        # `self.neusis.machines.x` is the value of option `flake.neusis.machines.x`.
        for alias in (term, re.sub(r"^(self|outputs|inputs\.neusis)\.neusis\.", "flake.neusis.", term)):
            if alias in symbols:
                return symbols[alias]
            found = _wildcard(alias, symbols)
            if found:
                return found
    # `neusis init my-fleet --darwin` → the `neusis init` page.
    words = term.split()
    if len(words) > 1 and words[0] == "neusis":
        for n in range(len(words) - 1, 1, -1):
            if " ".join(words[:n]) in symbols:
                return symbols[" ".join(words[:n])]
    return None


def relative(target: str, page: str) -> str | None:
    path, _, frag = target.partition("#")
    if path == page:
        return f"#{frag}" if frag else None
    rel = posixpath.relpath(path, posixpath.dirname(page) or ".")
    return rel + (f"#{frag}" if frag else "")


def link_line(line: str, page: str, symbols: dict[str, str]) -> str:
    protected = [m.span() for m in _LINK.finditer(line)]

    def replace(m: re.Match) -> str:
        if any(a <= m.start() < b for a, b in protected):
            return m.group(0)
        target = resolve(m.group(2), symbols)
        href = relative(target, page) if target else None
        return f"[{m.group(0)}]({href})" if href else m.group(0)

    return _CODE.sub(replace, line)


def link_chapter(content: str, page: str, symbols: dict[str, str]) -> str:
    out, fence = [], None
    for line in content.split("\n"):
        m = _FENCE.match(line)
        if fence:
            if m and m.group(1) == fence:
                fence = None
        elif m:
            fence = m.group(1)
        elif not _HEADING.match(line):
            line = link_line(line, page, symbols)
        out.append(line)
    return "\n".join(out)


def walk(node, symbols: dict[str, str]) -> None:
    if isinstance(node, list):
        for item in node:
            walk(item, symbols)
    elif isinstance(node, dict):
        chapter = node.get("Chapter")
        if chapter is not None:
            if chapter.get("path"):
                chapter["content"] = link_chapter(chapter["content"], chapter["path"], symbols)
            walk(chapter.get("sub_items", []), symbols)
        else:
            for value in node.values():
                walk(value, symbols)


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "supports":
        sys.exit(0)
    ctx, book = json.load(sys.stdin)
    index = Path(ctx["root"]) / "symbols.json"
    if index.exists():
        walk(book, json.loads(index.read_text()))
    json.dump(book, sys.stdout)


if __name__ == "__main__":
    main()
