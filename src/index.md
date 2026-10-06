# neusis

> In geometry, the neusis (νεῦσις; from Ancient Greek νεύειν, *incline
> towards*) is a geometric construction method that was used in antiquity
> by Greek mathematicians. — Wikipedia

**neusis** is a flake-based configuration library for
[NixOS](https://nixos.org), [nix-darwin](https://github.com/nix-darwin/nix-darwin)
and [home-manager](https://github.com/nix-community/home-manager). You
describe your fleet — machines, the people who log into them, and which
home-manager setup each person gets on each machine — as typed data. neusis
turns that into `nixosConfigurations`, `darwinConfigurations` and
`homeConfigurations`.

It ships:

- **A schema and builders.** `flake.neusis.{machines,users,registry}` options
  plus `mkNeusisFlake`, which assembles every system and home configuration
  from them.
- **A module library.** Opt-in home-manager modules (`supercharged-git`,
  `supercharged-shell`, `terminal-velocity`, `agent-harness`, …), system
  modules that work on both NixOS and nix-darwin (`tailscale`, `kanata`,
  `secrets`, distributed builds, …) and config-only *features*.
- **The `neusis` CLI**, a wizard that scaffolds a fleet repo and adds
  machines, users, labs and secrets to it.

neusis is also its author's own fleet config. The same flake that exports
the library builds those machines.

## Where to start

| You want to… | Read |
|---|---|
| set up a new fleet repo | [Installation](guide/installation.md), then [Quickstart](guide/quickstart.md) |
| understand machines, users and labs | [Concepts](guide/concepts.md) |
| turn on a module such as `supercharged-git` | [Using modules and features](guide/using-modules.md) and its tutorial |
| look up an option, function or CLI flag | [Reference](reference/index.md) |
| wire neusis into an existing flake by hand | [Using neusis without the CLI](guide/library.md) |
