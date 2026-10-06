"""Pulling prose out of Nix source: header comments, comments above a
definition, and the argument list of a function."""

from __future__ import annotations

import re


def _strip(line: str) -> str:
    body = line.strip()[1:]
    return body[1:] if body.startswith(" ") else body


def header_comment(lines: list[str]) -> str:
    """The `#` comment block at the top of a file."""
    out = []
    for line in lines:
        if not line.strip().startswith("#"):
            break
        out.append(_strip(line))
    return "\n".join(out).strip()


def comment_above(lines: list[str], line_no: int) -> str:
    """The `#` comment block directly above 1-indexed `line_no`."""
    out = []
    i = line_no - 2
    while i >= 0 and lines[i].strip().startswith("#"):
        out.append(_strip(lines[i]))
        i -= 1
    # Section separators like `# ---- System builders ----` aren't prose.
    out = [line for line in out if not re.fullmatch(r"-+ .* -+", line.strip())]
    return "\n".join(reversed(out)).strip()


_ARG = re.compile(r"^\s*([A-Za-z_][\w'-]*)\s*(?:\?\s*(.*?))?\s*,?\s*$")


def function_args(lines: list[str], line_no: int) -> tuple[list[dict], list[str]]:
    """Parse the function defined at `line_no` (`name = <args>: body`).

    Returns (named, positional): `named` is a list of {name, default,
    doc} for an attrset pattern `{ a, b ? 1 }:`; `positional` is the
    names of curried `x: y:` arguments.
    """
    text = "\n".join(lines[line_no - 1 : line_no + 80])
    text = text.split("=", 1)[1] if "=" in text else ""

    positional = []
    while True:
        m = re.match(r"\s*([A-Za-z_][\w'-]*)\s*:(?!:)", text)
        if not m:
            break
        positional.append(m.group(1))
        text = text[m.end() :]

    named = []
    if not positional and text.lstrip().startswith("{"):
        doc: list[str] = []
        for raw in text.lstrip()[1:].splitlines():
            stripped = raw.strip()
            if stripped.startswith("}"):
                break
            if stripped.startswith("#"):
                doc.append(_strip(stripped))
                continue
            if stripped in ("", "..."):
                continue
            m = _ARG.match(stripped)
            if m:
                named.append({"name": m.group(1), "default": m.group(2), "doc": " ".join(doc)})
            doc = []
    return named, positional
