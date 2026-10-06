"""Reference pages for everything neusis exports as a module:
home-manager modules, system (agnostic/NixOS/darwin) modules,
features, flakeModules, and the `flake.neusis.*` schema."""

from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path

from . import md, nixsrc
from .context import Context, Entry

_DEF = re.compile(
    r"^\s*flake\.(?P<kind>homeModules|agnosticModules|nixosModules|darwinModules)\.(?P<name>[\w-]+)\s*="
    r"|^\s*flake\.neusis\.features\.(?P<fcat>\w+)\.(?P<fname>[\w-]+)\s*=",
    re.M,
)


def discover(ctx: Context) -> dict[str, dict[str, dict]]:
    """Find every module definition in the source tree.

    Returns {kind: {name: {file, line, header}}}, where kind is
    `homeModules`, `agnosticModules`, … or `features.<category>`.
    Files and directories prefixed `_` are skipped, as import-tree does.
    """
    found: dict[str, dict[str, dict]] = defaultdict(dict)
    root = ctx.neusis / "modules"
    for path in sorted(root.rglob("*.nix")):
        rel = path.relative_to(ctx.neusis)
        if any(part.startswith("_") for part in rel.parts):
            continue
        text = path.read_text()
        header = nixsrc.header_comment(text.splitlines())
        for m in _DEF.finditer(text):
            kind = m["kind"] or f"features.{m['fcat']}"
            name = m["name"] or m["fname"]
            found[kind][name] = {
                "file": str(rel),
                "line": text.count("\n", 0, m.start()) + 1,
                "header": header,
            }
    return found


def _options_by_module(ctx: Context, scope: str, kind: str) -> dict[str, dict]:
    grouped: dict[str, dict] = defaultdict(dict)
    for name, opt in ctx.options(scope).items():
        via = opt.get("neusisModule") or ""
        if via.startswith(f"flake.{kind}."):
            grouped[via.removeprefix(f"flake.{kind}.")][name] = opt
    return grouped


def _tutorial_link(ctx: Context, name: str, page: str) -> str | None:
    target = f"upstream/{name}/tutorial.md"
    if target not in ctx.nav_paths:
        return None
    depth = page.count("/")
    return "../" * depth + target


# How a module output is written in code: `homeModules.x`, `self.homeModules.x`,
# `inputs.neusis.homeModules.x`, …
_OUTPUT_PREFIXES = ("", "neusis.", "inputs.neusis.", "self.", "outputs.", "flake.")


def _module_symbols(ctx: Context, kinds: list[str], name: str, page: str) -> None:
    for kind in kinds:
        for prefix in _OUTPUT_PREFIXES:
            ctx.symbol(f"{prefix}{kind}.{name}", page)
    # A bare module name only when it can't be mistaken for the program it
    # configures (`supercharged-git` yes, `tailscale` no).
    if "-" in name:
        ctx.symbol(name, page)


def _module_pages(
    ctx: Context,
    *,
    out_dir: str,
    title: str,
    kind: str,
    export_kinds: list[str],
    scope: str,
    consumer_attr: str,
    intro: str,
    usage: str,
) -> list[Entry]:
    modules = discover(ctx).get(kind, {})
    options = _options_by_module(ctx, scope, kind)

    # `supercharged-git-delta` nests under the umbrella `supercharged-git`
    # (the shortest matching prefix, so `…-gh-dash` doesn't land under `…-gh`).
    parent_of = {
        n: min((p for p in modules if n.startswith(p + "-")), key=len, default=None) for n in modules
    }

    def page_for(name: str) -> str:
        return f"{out_dir}/{name}.md"

    for name, mod in modules.items():
        page = page_for(name)
        opts = options.get(name, {})
        children = sorted(c for c, p in parent_of.items() if p == name)
        enable = min((o for o in opts if o.endswith(".enable")), key=len, default=None)

        lines = [f"# {name}", ""]
        if parent_of[name]:
            parent = parent_of[name]
            lines += [f"*Part of [{parent}]({parent}.md) — imported automatically by it.*", ""]
        if mod["header"]:
            lines += [md.prose(mod["header"]), ""]

        snippet = usage.format(attr=f"inputs.neusis.{consumer_attr}.{name}")
        if enable:
            snippet += f"\n{enable} = true;"
        lines += ["## Usage", "", md.code(snippet), ""]
        lines += [f"Defined in {ctx.source_link(mod['file'], mod['line'])}."]
        tutorial = _tutorial_link(ctx, name, page)
        if tutorial:
            lines += ["", f"See the [{name} tutorial]({tutorial}) for a guided walkthrough."]

        if children:
            lines += ["", "## Sub-modules", ""]
            lines += [
                md.table(
                    ["Module", "Summary"],
                    [
                        [f"[{c}]({c}.md)", md.first_sentence(modules[c]["header"]) or ""]
                        for c in children
                    ],
                )
            ]

        _module_symbols(ctx, export_kinds, name, page)
        for k in export_kinds:
            for prefix in _OUTPUT_PREFIXES:
                for generic in (f"{prefix}{k}", f"{prefix}{k}.<name>"):
                    ctx.symbol(generic, f"{out_dir}/index.md")
        for o in opts:
            ctx.symbol(o, f"{page}#{md.anchor(o)}")

        lines += ["", "## Options", ""]
        if opts:
            lines += [md.option(ctx, o, opts[o]) + "\n" for o in sorted(opts)]
        else:
            lines += ["This module declares no options of its own."]
        ctx.write(page, "\n".join(lines))

    rows = [
        [f"[{n}]({n}.md)", md.first_sentence(modules[n]["header"]), str(len(options.get(n, {})))]
        for n in sorted(modules)
    ]
    ctx.write(
        f"{out_dir}/index.md",
        "\n".join([f"# {title}", "", intro, "", md.table(["Module", "Summary", "Options"], rows)]),
    )

    def entry(name: str) -> Entry:
        kids = sorted(c for c, p in parent_of.items() if p == name)
        label = name.removeprefix(parent_of[name] + "-") if parent_of[name] else name
        return Entry(label, page_for(name), [entry(k) for k in kids])

    return [entry(n) for n in sorted(modules) if parent_of[n] is None]


def home_modules(ctx: Context) -> list[Entry]:
    return _module_pages(
        ctx,
        out_dir="reference/home-modules",
        title="Home Manager modules",
        kind="homeModules",
        export_kinds=["homeModules"],
        scope="home",
        consumer_attr="homeModules",
        intro=(
            "Exported as `neusis.homeModules.<name>`. Import them from a user's "
            "home-manager bundle; every module is inert until its `enable` option is set."
        ),
        usage="# inside a home-manager module, e.g. a user's hmBundle\nimports = [ {attr} ];",
    )


def system_modules(ctx: Context) -> list[Entry]:
    return _module_pages(
        ctx,
        out_dir="reference/system-modules",
        title="System modules",
        kind="agnosticModules",
        export_kinds=["agnosticModules", "nixosModules", "darwinModules"],
        scope="system",
        consumer_attr="darwinModules",
        intro=(
            "Platform-agnostic system modules, exported identically as "
            "`neusis.nixosModules.<name>` and `neusis.darwinModules.<name>` "
            "(and `neusis.agnosticModules.<name>`)."
        ),
        usage="# inside a machine's `module` (use nixosModules on NixOS)\nimports = [ {attr} ];",
    )


def features(ctx: Context) -> list[Entry]:
    found = discover(ctx)
    cats = sorted(k.removeprefix("features.") for k in found if k.startswith("features."))
    lines = [
        "# Features",
        "",
        "Features are opt-in, config-only modules with no options of their own: "
        "importing one *is* the switch. They are exported as "
        "`neusis.neusis.features.<category>.<name>` (`self.neusis.features…` inside neusis).",
        "",
        md.table(
            ["Category", "Import into"],
            [
                ["`agnostic`", "a NixOS or nix-darwin machine `module`"],
                ["`darwin`", "a nix-darwin machine `module`"],
                ["`nixos`", "a NixOS machine `module`"],
                ["`hm`", "a home-manager bundle"],
                ["`flake`", "your flake-parts `imports`"],
            ],
        ),
    ]
    for prefix in _OUTPUT_PREFIXES:
        for generic in ("neusis.features", "neusis.features.<category>.<name>"):
            ctx.symbol(prefix + generic, "reference/features.md")
    for cat in cats:
        lines += ["", f"## {cat}"]
        for name, mod in sorted(found[f"features.{cat}"].items()):
            target = f"reference/features.md#{cat}-{name}"
            ctx.symbol(f"features.{cat}.{name}", target)
            for prefix in _OUTPUT_PREFIXES:
                ctx.symbol(f"{prefix}neusis.features.{cat}.{name}", target)
            src = "\n".join(ctx.read_source(mod["file"]))
            lines += [
                "",
                f"### `{cat}.{name}` {{#{cat}-{name}}}",
                "",
                md.prose(mod["header"]) or "*No description in source.*",
                "",
                md.code(f"imports = [ inputs.neusis.neusis.features.{cat}.{name} ];"),
                "",
                f"Defined in {ctx.source_link(mod['file'], mod['line'])}.",
                "",
                "<details><summary>Source</summary>",
                "",
                md.code(src),
                "",
                "</details>",
            ]
    ctx.write("reference/features.md", "\n".join(lines))
    return []


def flake_modules(ctx: Context) -> list[Entry]:
    rel = "modules/flakeModules.nix"
    src = ctx.read_source(rel)
    rows = []
    for i, line in enumerate(src, start=1):
        m = re.match(r"^    ([\w-]+) = \{", line)
        if not m:
            continue
        imports = []
        for nxt in src[i:]:
            if nxt.startswith("    }"):
                break
            imp = re.match(r"^\s+\./(\S+)", nxt)
            if imp:
                imports.append(f"`{imp.group(1)}`")
        rows.append((m.group(1), i, nixsrc.comment_above(src, i), imports))

    lines = [
        "# flakeModules",
        "",
        "flake-parts modules for consumer repos, exported as `neusis.flakeModules.<name>`. "
        "Most consumers import `default`; `neusis init` does this for you.",
        "",
        md.code(
            "# a flake-parts module in your repo\n{ inputs, ... }: {\n"
            "  imports = [ inputs.neusis.flakeModules.default ];\n}"
        ),
    ]
    for prefix in _OUTPUT_PREFIXES:
        for generic in ("flakeModules", "flakeModules.<name>"):
            ctx.symbol(prefix + generic, "reference/flake-modules.md")
    for name, line, doc, imports in rows:
        for prefix in _OUTPUT_PREFIXES:
            ctx.symbol(f"{prefix}flakeModules.{name}", f"reference/flake-modules.md#flakemodule-{name}")
        lines += [
            "",
            f"## `{name}` {{#flakemodule-{name}}}",
            "",
            md.prose(doc) or "*No description in source.*",
            "",
        ]
        lines += [f"Imports: {', '.join(imports)} (relative to `modules/`)."] if imports else []
        lines += ["", f"Defined in {ctx.source_link(rel, line)}."]
    ctx.write("reference/flake-modules.md", "\n".join(lines))
    return []


def flake_schema(ctx: Context) -> list[Entry]:
    opts = ctx.options("flake")
    sections: dict[str, list[str]] = defaultdict(list)
    for name in sorted(opts):
        if "." in name:  # not the top-level `flake`, which usually means something else
            ctx.symbol(name, f"reference/flake-schema.md#{md.anchor(name)}")
        loc = opts[name]["loc"]
        key = ".".join(loc[:3]) if loc[:2] == ["flake", "neusis"] else ".".join(loc[:2])
        sections[key].append(name)

    lines = [
        "# flake.neusis schema",
        "",
        "The typed flake-parts options your repo writes to — machines, users, "
        "registries, features and the lib namespace. Declared by "
        "`flakeModules.options` (and therefore by `flakeModules.default`).",
        "",
        "`<name>` stands for an attribute name you choose; `*` for a list element.",
    ]
    for key in sorted(sections):
        lines += ["", f"## `{key}`", ""]
        lines += [md.option(ctx, n, opts[n]) + "\n" for n in sections[key]]
    ctx.write("reference/flake-schema.md", "\n".join(lines))
    return []
