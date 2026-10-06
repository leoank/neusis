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
