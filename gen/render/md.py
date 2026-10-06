"""Markdown building blocks shared by the generators."""

from __future__ import annotations

import re

from .context import Context


_CODE_SPAN = re.compile(r"(`+[^`]*`+)")


def prose(text: str) -> str:
    """Escape tag-like `<x>` outside code so mdBook doesn't read it as HTML.

    Source comments and option descriptions say things like `<leader>`
    or `<name>` in plain text; in Markdown those would vanish."""
    out, fenced = [], False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            fenced = not fenced
        if not fenced:
            line = "".join(
                part if part.startswith("`") else re.sub(r"<(?=[A-Za-z/])", "&lt;", part)
                for part in _CODE_SPAN.split(line)
            )
        out.append(line)
    return "\n".join(out)


def code(text: str, lang: str = "nix") -> str:
    fence = "````" if "```" in text else "```"
    return f"{fence}{lang}\n{text.rstrip()}\n{fence}"


def inline(text: str) -> str:
    return f"`` {text} ``" if "`" in text else f"`{text}`"


def value(v) -> str | None:
    """Render a nixosOptionsDoc default/example value."""
    if v is None:
        return None
    if isinstance(v, dict) and v.get("_type") == "literalMD":
        return v["text"]
    text = v["text"] if isinstance(v, dict) else str(v)
    return inline(text) if "\n" not in text else "\n\n" + code(text)


def anchor(name: str) -> str:
    return "opt-" + "".join(c if c.isalnum() or c in "-_" else "-" for c in name)


def option(ctx: Context, name: str, opt: dict, level: int = 3) -> str:
    """One option as a heading, its description, and a fact list."""
    parts = [f"{'#' * level} `{name}` {{#{anchor(name)}}}", ""]
    if opt.get("description"):
        parts += [prose(opt["description"].strip()), ""]
    facts = [f"- **Type:** {inline(opt['type'])}"]
    for key in ("default", "example"):
        rendered = value(opt.get(key))
        if rendered is not None:
            facts.append(f"- **{key.capitalize()}:** {rendered}")
    if opt.get("readOnly"):
        facts.append("- **Read-only**")
    decls = [ctx.source_link(d["name"]) for d in opt.get("declarations", [])]
    if decls:
        facts.append(f"- **Declared in:** {', '.join(decls)}")
    parts += ['<div class="option-facts">', "", "\n".join(facts), "", "</div>"]
    return "\n".join(parts)


def table(header: list[str], rows: list[list[str]]) -> str:
    cell = lambda s: prose(s).replace("|", "\\|").replace("\n", " ")
    lines = ["| " + " | ".join(header) + " |", "|" + "---|" * len(header)]
    lines += ["| " + " | ".join(cell(c) for c in row) + " |" for row in rows]
    return "\n".join(lines)


def first_sentence(text: str) -> str:
    lines = text.strip().splitlines()
    # Skip a title line like "supercharged-git: delta module." when prose follows.
    if len(lines) > 1 and re.search(r"module\.?$", lines[0], re.I) and lines[1].strip():
        lines = lines[1:]
    para = "\n".join(lines).split("\n\n")[0].replace("\n", " ")
    end = para.find(". ")
    return para if end == -1 else para[: end + 1]
