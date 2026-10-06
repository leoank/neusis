# Evaluates every module neusis exports and returns the options that
# neusis itself declares, as nixosOptionsDoc JSON files — one per scope.
#
# Each scope is a full module-system evaluation (home-manager,
# nix-darwin, flake-parts) with *all* of that scope's neusis modules
# imported. Options are then filtered down to those whose declaration
# lives inside the neusis source tree *and* whose name sits under the
# scope's namespace (`neusis.*`, `flake.*`), so upstream options —
# including those of modules neusis imports, like agenix — never leak
# into the reference.
#
# To document a new class of module, add an entry to `scopes`.
{
  pkgs,
  neusis,
  # Revision used for "Declared in" source links.
  rev,
  repoUrl,
}:
let
  inherit (pkgs) lib;
  inputs = neusis.inputs;
  root = toString neusis.outPath;

  # Darwin evaluation target. Options are only *evaluated*, never built,
  # so this works from a Linux CI runner too.
  darwinSystem = "aarch64-darwin";
  darwinPkgs = import inputs.nixpkgs {
    system = darwinSystem;
    config.allowUnfree = true;
  };

  # Umbrella modules (supercharged-git, terminal-velocity, …) import
  # their `<umbrella>-<tool>` sub-modules themselves; importing those a
  # second time would declare every option twice.
  topLevel =
    modules:
    lib.attrValues (
      lib.filterAttrs (
        name: _: !lib.any (other: lib.hasPrefix "${other}-" name) (lib.attrNames modules)
      ) modules
    );

  specialArgs = {
    inherit inputs;
    outputs = neusis;
  };

  scopes = {
    # neusis.homeModules.* — evaluated as one home-manager config. This
    # mirrors home-manager's modules/default.nix but skips its
    # assertion checks, which fire on a config nobody filled in.
    home.namespace = "neusis";
    home.options =
      let
        hmLib = import "${inputs.home-manager}/modules/lib/stdlib-extended.nix" lib;
      in
      (hmLib.evalModules {
        class = "homeManager";
        specialArgs = {
          modulesPath = "${inputs.home-manager}/modules";
        }
        // specialArgs;
        modules =
          import "${inputs.home-manager}/modules/modules.nix" {
            pkgs = darwinPkgs;
            lib = hmLib;
            check = false;
          }
          ++ topLevel neusis.homeModules
          ++ [
            {
              home.username = "docs";
              home.homeDirectory = "/Users/docs";
              home.stateVersion = "25.05";
            }
          ];
      }).options;

    # neusis.agnosticModules.* (== darwinModules / nixosModules).
    system.namespace = "neusis";
    system.options =
      (inputs.darwin.lib.darwinSystem {
        system = darwinSystem;
        inherit specialArgs;
        modules = topLevel neusis.darwinModules ++ [
          # Upstream modules a neusis machine imports alongside these.
          inputs.home-manager.darwinModules.home-manager
          inputs.agenix.darwinModules.default
          inputs.agenix-rekey.darwinModules.default
          { system.stateVersion = 6; }
        ];
      }).options;

    # flakeModules.* — the `flake.neusis.*` schema consumers write to.
    flake.namespace = "flake";
    flake.options =
      (lib.evalModules {
        modules = [
          {
            # Keep declaration positions pointing at the source file.
            _file = root + "/modules/lib/neusis-options.nix";
            imports = [
              (import (root + "/modules/lib/neusis-options.nix") {
                inherit lib;
                flake-parts-lib = inputs.flake-parts.lib;
              })
            ];
          }
        ];
      }).options;
  };

  # Declarations look like "<root>/modules/x.nix, via option flake.homeModules.x".
  isOurs = decl: lib.hasPrefix "${root}/" (toString decl);
  splitDecl = decl: lib.splitString ", via option " (lib.removePrefix "${root}/" (toString decl));
  relPath = decl: lib.head (splitDecl decl);
  # The flake output a declaration was reached through, e.g. "flake.homeModules.brave".
  viaOption =
    decl:
    let
      parts = splitDecl decl;
    in
    if lib.length parts > 1 then lib.last parts else null;

  mkDoc =
    namespace: options:
    pkgs.nixosOptionsDoc {
      inherit options;
      warningsAreErrors = false;
      transformOptions =
        opt:
        let
          ours = lib.filter isOurs opt.declarations;
        in
        opt
        // {
          visible = opt.visible && ours != [ ] && lib.head opt.loc == namespace;
          neusisModule = if ours == [ ] then null else viaOption (lib.head ours);
          declarations = map (d: {
            name = relPath d;
            url = "${repoUrl}/blob/${rev}/${relPath d}";
          }) ours;
        };
    };
in
pkgs.linkFarm "neusis-options-json" (
  lib.mapAttrsToList (name: scope: {
    name = "${name}.json";
    path = "${(mkDoc scope.namespace scope.options).optionsJSON}/share/doc/nixos/options.json";
  }) scopes
)
