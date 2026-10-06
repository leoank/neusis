"""Reference pages for the `neusis` CLI, one per command."""

from __future__ import annotations

from . import md
from .context import Context, Entry


def _page(cmd: dict) -> str:
    parts = cmd["path"].split()[1:]
    return "reference/cli/" + ("-".join(parts) if parts else "index") + ".md"


def _flags(flags: list[dict]) -> str:
    rows = []
    for f in flags:
        if f["name"] == "help":
            continue
        name = f"`--{f['name']}`" + (f", `-{f['shorthand']}`" if f["shorthand"] else "")
        default = f["default"] if f["default"] not in ("", "[]", "false") else ""
        rows.append([name, f"`{f['type']}`", md.inline(default) if default else "", f["usage"]])
    return md.table(["Flag", "Type", "Default", "Description"], rows) if rows else ""


def _render(ctx: Context, cmd: dict) -> Entry:
    page = _page(cmd)
    if " " in cmd["path"]:  # not bare `neusis`, which usually means the project
        ctx.symbol(cmd["path"], page)
    lines = [f"# {cmd['path']}", "", cmd["short"], ""]
    if cmd["long"]:
        lines += [md.prose(cmd["long"]), ""]
    if cmd["runnable"]:
        lines += ["## Usage", "", md.code(cmd["use"], "sh"), ""]
    if cmd["aliases"]:
        lines += [f"Aliases: {', '.join(f'`{a}`' for a in cmd['aliases'])}", ""]
    if cmd["example"]:
        lines += ["## Examples", "", md.code(cmd["example"], "sh"), ""]
    for title, key in (("Flags", "flags"), ("Inherited flags", "inherited")):
        rendered = _flags(cmd[key])
        if rendered:
            lines += [f"## {title}", "", rendered, ""]
    if cmd["commands"]:
        rows = [
            [f"[`{c['path']}`]({_page(c).removeprefix('reference/cli/')})", c["short"]]
            for c in cmd["commands"]
        ]
        lines += ["## Subcommands", "", md.table(["Command", "Description"], rows)]
    ctx.write(page, "\n".join(lines))
    return Entry(cmd["path"].split()[-1], page, [_render(ctx, c) for c in cmd["commands"]])


def cli(ctx: Context) -> list[Entry]:
    # The root command renders as the section's index page (linked from
    # nav.md); its subcommands become the sidebar children.
    return _render(ctx, ctx.cli).children
