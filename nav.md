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
- [Architecture](upstream/architecture.md)
- [Decisions](upstream/decisions/README.md)
  - [ADR-0001: Lab notebook and ADRs](upstream/decisions/ADR-0001-record-work-in-a-yajna-notebook.md)
  - [ADR-0002: Dendritic layout](upstream/decisions/ADR-0002-dendritic-layout.md)
  - [ADR-0003: Typed flake.neusis schema](upstream/decisions/ADR-0003-typed-neusis-schema.md)
  - [ADR-0004: Cross-platform modules](upstream/decisions/ADR-0004-cross-platform-modules.md)
  - [ADR-0005: Opt-in modules and features](upstream/decisions/ADR-0005-opt-in-modules-and-features.md)
  - [ADR-0006: Secrets with agenix-rekey](upstream/decisions/ADR-0006-agenix-rekey-secrets.md)
  - [ADR-0007: Test ladder](upstream/decisions/ADR-0007-test-ladder.md)
  - [ADR-0008: One tailnet with profiles](upstream/decisions/ADR-0008-one-tailnet-with-profiles.md)
  - [ADR-0009: Archiving v1](upstream/decisions/ADR-0009-archive-v1.md)
  - [ADR-0010: OpenTofu and encrypted state](upstream/decisions/ADR-0010-opentofu-terranix-encrypted-state.md)
  - [ADR-0011: Base image and bootstrap](upstream/decisions/ADR-0011-base-image-and-bootstrap.md)
  - [ADR-0012: comin and signed deploy branches](upstream/decisions/ADR-0012-comin-signed-deploy-branches.md)
  - [ADR-0013: GitHub App bot](upstream/decisions/ADR-0013-github-app-bot.md)
  - [ADR-0014: attic binary cache](upstream/decisions/ADR-0014-attic-cache-on-spirit.md)
  - [ADR-0015: Design records on this site](upstream/decisions/ADR-0015-site-publishes-design-records.md)
  - [ADR-0016: kalam-zero](upstream/decisions/ADR-0016-kalam-zero.md)
  - [ADR-0017: Plugins inlined into kalam-zero](upstream/decisions/ADR-0017-kalam-zero-inlines-pure-lua-plugins.md)
- [Testing](upstream/testing.md)
- [Porting log (frozen)](upstream/porting.md)
- [Future considerations](upstream/future-considerations.md)
- [About this site](contributing/docs-site.md)
