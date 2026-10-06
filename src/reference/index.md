# Reference

Every page in this section is **generated from the neusis source** each
time the site is built. Option types, defaults and descriptions come from
evaluating the modules. Function and module descriptions come from the
comments above them in the source. CLI pages come from the command tree
compiled into the `neusis` binary. To fix something here, fix it in the
source; it shows up on the next site build.

| Section | What it covers |
|---|---|
| [CLI](cli/index.md) | every `neusis` command and flag |
| [flake.neusis schema](flake-schema.md) | the options your repo sets: machines, users, registries |
| [flakeModules](flake-modules.md) | the flake-parts modules a consumer imports |
| [Library functions](lib/index.md) | `mkNeusisFlake`, `mkNeusisOS`, the kalam helpers, … |
| [Home Manager modules](home-modules/index.md) | `neusis.homeModules.*` and all their options |
| [System modules](system-modules/index.md) | `neusis.{nixos,darwin}Modules.*` and all their options |
| [Features](features.md) | config-only `neusis.features.*` bundles, with source |
| [Packages & templates](outputs.md) | `nix run` / `nix flake init -t` targets |

Each option shows a **Declared in** link to the line in neusis that
defines it, at the revision this site was built from.
