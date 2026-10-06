# Re-export every `flake.agnosticModules.<name>` as both
# `flake.nixosModules.<name>` and `flake.darwinModules.<name>`.
#
# Agnostic modules only touch options common to NixOS and nix-darwin
# (e.g. `home-manager.users.<name>`), so this lets a single definition
# be consumed by either system builder without writing the module twice
# or maintaining parallel `nixosModules.foo` / `darwinModules.foo`
# files.
#
# Lazy-attrset merging means modules set directly on
# `flake.{nixos,darwin}Modules.<name>` still merge cleanly alongside the
# re-exported ones.
{ config, ... }:
{
  flake.nixosModules = config.flake.agnosticModules;
  flake.darwinModules = config.flake.agnosticModules;
}
