"""Shared state handed to every generator."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Entry:
    """One sidebar entry. `path` is relative to src/."""

    title: str
    path: str
    children: list["Entry"] = field(default_factory=list)


@dataclass
class Context:
    src: Path  # the book's src/ directory (we write into it)
    neusis: Path  # neusis source tree being documented
    options_dir: Path  # <scope>.json files from gen/options.nix
    meta: dict  # gen/meta.nix output
    cli: dict  # gen/cli output
    rev: str
    repo_url: str
    nav_paths: set[str] = field(default_factory=set)  # every path listed in nav.md

    def options(self, scope: str) -> dict:
        return json.loads((self.options_dir / f"{scope}.json").read_text())

    def source_url(self, rel: str, line: int | None = None) -> str:
        url = f"{self.repo_url}/blob/{self.rev}/{rel}"
        return f"{url}#L{line}" if line else url

    def source_link(self, rel: str, line: int | None = None) -> str:
        return f"[`{rel}`]({self.source_url(rel, line)})"

    def read_source(self, rel: str) -> list[str]:
        return (self.neusis / rel).read_text().splitlines()

    def write(self, rel: str, text: str) -> None:
        out = self.src / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text.rstrip() + "\n")
