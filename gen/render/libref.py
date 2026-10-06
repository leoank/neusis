"""Reference pages for `neusis.neusis.lib.<group>.<fn>`."""

from __future__ import annotations

from . import md, nixsrc
from .context import Context, Entry


def lib(ctx: Context) -> list[Entry]:
    groups = ctx.meta["lib"]
    entries = []
    for group in sorted(groups):
        fns = groups[group]
        lines = [
            f"# lib.{group}",
            "",
            f"Available as `self.neusis.lib.{group}` inside a flake that imports "
            f"`neusis.flakeModules.default`, or directly as `inputs.neusis.neusis.lib.{group}`.",
        ]
        for name in sorted(fns):
            fn = fns[name]
            lines += ["", f"## `{name}` {{#{name}}}", ""]
            src = ctx.read_source(fn["file"]) if fn["file"] else []
            doc = nixsrc.comment_above(src, fn["line"]) if src else ""
            lines += [md.prose(doc) or "*No description in source.*", ""]

            if fn["type"] == "lambda" and src:
                named, positional = nixsrc.function_args(src, fn["line"])
                if named:
                    rows = [
                        [
                            md.inline(a["name"]),
                            md.inline(a["default"]) if a["default"] else "*required*",
                            a["doc"],
                        ]
                        for a in named
                    ]
                    lines += [md.table(["Argument", "Default", "Notes"], rows), ""]
                elif positional:
                    lines += [md.code(f"{name} " + " ".join(positional)), ""]
            elif fn["type"] != "lambda":
                lines += [f"*Value of type `{fn['type']}`.*", ""]

            if fn["file"]:
                lines += [f"Defined in {ctx.source_link(fn['file'], fn['line'])}."]
        page = f"reference/lib/{group}.md"
        ctx.write(page, "\n".join(lines))
        entries.append(Entry(group, page))

    rows = [[f"[`{g}`]({g}.md)", ", ".join(f"`{f}`" for f in sorted(groups[g]))] for g in sorted(groups)]
    ctx.write(
        "reference/lib/index.md",
        "\n".join(
            [
                "# Library functions",
                "",
                "Plain Nix functions under the `neusis.lib` namespace. "
                "`neusisOS` holds the system builders most repos need.",
                "",
                md.table(["Group", "Functions"], rows),
            ]
        ),
    )
    return entries
