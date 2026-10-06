"""Reference page for the flake's packages and templates."""

from __future__ import annotations

from . import md
from .context import Context, Entry


def packages_and_templates(ctx: Context) -> list[Entry]:
    pkgs = ctx.meta["packages"]
    tmpls = ctx.meta["templates"]
    lines = [
        "# Packages & templates",
        "",
        "## Packages",
        "",
        md.code("nix run github:leoank/neusis#<name>", "sh"),
        "",
        md.table(["Package", "Description"], [[f"`{n}`", pkgs[n]] for n in sorted(pkgs)]),
        "",
        "## Templates",
        "",
        "Project starters for `nix flake init`; sources live in "
        f"{ctx.source_link('templates')}.",
        "",
        md.code("nix flake init -t github:leoank/neusis#<name>", "sh"),
        "",
        md.table(["Template", "Description"], [[f"`{n}`", tmpls[n]] for n in sorted(tmpls)]),
    ]
    ctx.write("reference/outputs.md", "\n".join(lines))
    return []
