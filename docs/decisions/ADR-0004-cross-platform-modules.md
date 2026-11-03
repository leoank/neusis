# ADR-0004: A module that runs on NixOS and nix-darwin dispatches on its options set, and the machine imports the platform-specific input module

Status: accepted
Date: 2026-08-16 (the platform import rule dates from 2026-05-31)
Backfilled: 2026-11-03, from `porting.md` (2026-05-31 *hm-system-init* and *Patterns*,
2026-08-12 *agenix-rekey on darwin*, 2026-08-16 *The agnostic-module platform-key
problem*, 2026-10-22 auto-updates M2).

## Context
`agnosticModules/` holds system modules re-exported as both `nixosModules.*` and
`darwinModules.*`. Two things kept breaking them:

1. **Platform-only option keys.** A tailscale autoconnect needs `systemd.services` on
   NixOS and `launchd.daemons` on darwin. Three approaches were tried:
   - `lib.mkIf pkgs.stdenv.isLinux { systemd.… }` fails: `mkIf` registers the option
     path before testing the condition, so the other platform errors with "option does
     not exist".
   - `lib.optionalAttrs pkgs.stdenv.isLinux { … }` at the top level recurses forever:
     deciding which keys exist forces `pkgs`, which needs the config.
   - Testing the options set (`options ? systemd`, `options ? launchd`) works: option
     declarations are known before config.
2. **Platform-specific input modules.** Choosing `darwinModules.home-manager` or
   `nixosModules.home-manager` inside `imports` from `pkgs.stdenv.isDarwin` is infinite
   recursion, because `pkgs` is a config value.

## Decision
- An agnostic module computes `isLinux = options ? systemd` and
  `isDarwin = options ? launchd`, keeps its top-level config keys static, and adds
  platform keys with `lib.optionalAttrs` on those flags inside a `lib.mkMerge`.
- An agnostic module never imports a platform-specific module. The machine (or the
  system builder) imports it next to the agnostic module: home-manager,
  agenix / agenix-rekey and comin all follow this.

## Consequences
- One module covers both platforms, and its tests evaluate it on both.
- A machine file must remember the platform imports. Missing one shows up as an unknown
  option, which the machine's test catches.
- The 2026-10-06 test suite found two modules (kanata, build-server) still using `mkIf`
  over `pkgs.stdenv`; both were moved to this pattern.
