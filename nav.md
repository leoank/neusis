<!--
  The sidebar. This is mdBook's SUMMARY.md syntax with one addition:
  a line holding only the HTML comment "gen:NAME" is replaced by the
  pages generator NAME produces (see gen/render/__main__.py), indented
  like the marker. Comments are stripped from the generated SUMMARY.md.

  - src/…           hand-written pages, edited in this branch
  - upstream/…      guides imported from neusis's docs/ on main
  - reference/…     generated from the neusis source; never edit
-->

# Summary

[Introduction](index.md)

# Guide

- [Installation](guide/installation.md)
- [Quickstart](guide/quickstart.md)
- [Concepts](guide/concepts.md)
- [Using modules and features](guide/using-modules.md)
- [Secrets](guide/secrets.md)
- [Using neusis without the CLI](guide/library.md)

# Tutorials

- [supercharged-git](upstream/supercharged-git/tutorial.md)
- [supercharged-shell](upstream/supercharged-shell/tutorial.md)
- [terminal-velocity](upstream/terminal-velocity/tutorial.md)
- [agent-harness](upstream/agent-harness/tutorial.md)
- [hammerspoon](upstream/hammerspoon/tutorial.md)
- [kalam (Neovim)](upstream/kalam/base.md)
  - [Git workflow](upstream/kalam/git-workflow.md)
  - [kalam-full (LaTeX)](upstream/kalam/full.md)
  - [Writing LaTeX](upstream/kalam/latex-tutorial.md)

# Reference

- [Overview](reference/index.md)
- [CLI](reference/cli/index.md)
  <!-- gen:cli -->
- [flake.neusis schema](reference/flake-schema.md)
- [flakeModules](reference/flake-modules.md)
- [Library functions](reference/lib/index.md)
  <!-- gen:lib -->
- [Home Manager modules](reference/home-modules/index.md)
  <!-- gen:home-modules -->
- [System modules](reference/system-modules/index.md)
  <!-- gen:system-modules -->
- [Features](reference/features.md)
- [Packages & templates](reference/outputs.md)

# Development

- [Repository layout](upstream/overview.md)
- [Testing](upstream/testing.md)
- [Porting log](upstream/porting.md)
- [Future considerations](upstream/future-considerations.md)
- [About this site](contributing/docs-site.md)
