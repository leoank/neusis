"""Generate the reference half of the book.

    python3 -m render --root <site> --neusis <src> --options <dir> \
        --meta <json> --cli <json> --rev <rev> --repo-url <url>

Writes generated pages into <site>/src/{reference,upstream}/ and expands
<site>/nav.md into <site>/src/SUMMARY.md. A line `<!-- gen:NAME -->` in
nav.md is replaced by the sidebar entries generator NAME returns,
indented to match the marker.

To add a generated section: write a function `(ctx) -> list[Entry]`,
register it in GENERATORS, and reference it from nav.md.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from . import cli, libref, modules, outputs, upstream
from .context import Context, Entry

GENERATORS = {
    # upstream runs first: it only needs nav.md, and others link into it.
    "upstream": upstream.upstream_docs,
    "home-modules": modules.home_modules,
    "system-modules": modules.system_modules,
    "features": modules.features,
    "flake-modules": modules.flake_modules,
    "flake-schema": modules.flake_schema,
    "lib": libref.lib,
    "cli": cli.cli,
    "outputs": outputs.packages_and_templates,
}

_MARKER = re.compile(r"^(?P<indent>\s*)<!--\s*gen:(?P<name>[\w-]+)\s*-->\s*$")


def _entries(entries: list[Entry], indent: str) -> list[str]:
    out = []
    for e in entries:
        out.append(f"{indent}- [{e.title}]({e.path})")
        out += _entries(e.children, indent + "  ")
    return out


def _write_symbols(ctx: Context, out: Path) -> None:
    """Add option namespaces to the symbol index and write it for autolink.

    `neusis.supercharged-git` links to the page holding all of its direct
    child options; a namespace whose children are spread over several
    pages (`neusis.supercharged-git.tools`, `neusis.services`) stays plain.
    """
    children: dict[str, list[tuple[str, str]]] = {}  # namespace → [(option, target)]
    on_page: dict[str, list[str]] = {}  # page → options documented there
    for name, target in list(ctx.symbols.items()):
        if target and "#opt-" in target:
            page = target.split("#")[0]
            children.setdefault(name.rsplit(".", 1)[0], []).append((name, target))
            on_page.setdefault(page, []).append(name)
    for prefix, kids in children.items():
        owners = {t.split("#")[0] for _, t in kids}
        if prefix.count(".") < 1 or len(owners) != 1 or prefix in ctx.symbols:
            continue
        page = owners.pop()
        # A page wholly about this namespace (a module page) links to its
        # top; on a mixed page (the flake schema), jump to the first option.
        if all(o.startswith(prefix + ".") for o in on_page[page]):
            ctx.symbol(prefix, page)
        else:
            ctx.symbol(prefix, min(kids)[1])
    symbols = {k: v for k, v in sorted(ctx.symbols.items()) if v}
    out.write_text(json.dumps(symbols, indent=1) + "\n")


def main() -> None:
    p = argparse.ArgumentParser()
    for flag in ("root", "neusis", "options", "meta", "cli", "rev", "repo-url"):
        p.add_argument(f"--{flag}", required=True)
    a = p.parse_args()

    root = Path(a.root)
    nav = (root / "nav.md").read_text()
    ctx = Context(
        src=root / "src",
        neusis=Path(a.neusis),
        options_dir=Path(a.options),
        meta=json.loads(Path(a.meta).read_text()),
        cli=json.loads(Path(a.cli).read_text()),
        rev=a.rev,
        repo_url=a.repo_url,
        nav_paths=set(re.findall(r"\]\(([^)]+\.md)\)", nav)),
    )

    results = {name: gen(ctx) for name, gen in GENERATORS.items()}
    _write_symbols(ctx, root / "symbols.json")

    summary = []
    for line in nav.splitlines():
        m = _MARKER.match(line)
        link = re.search(r"\]\((upstream/[^)]+)\)", line)
        if link and not (ctx.src / link.group(1)).exists():
            # Upstream docs live on another branch; one going missing
            # shouldn't break the site.
            print(f"warning: nav.md: {link.group(1)} not in neusis docs/, skipping", file=sys.stderr)
        elif not m:
            summary.append(line)
        elif m["name"] not in results:
            raise SystemExit(f"nav.md: unknown generator {m['name']!r}")
        else:
            summary += _entries(results[m["name"]], m["indent"])
    text = re.sub(r"<!--.*?-->\n*", "", "\n".join(summary), flags=re.S)
    ctx.write("SUMMARY.md", text)


if __name__ == "__main__":
    main()
