# Extracts option descriptions from neusis-options.nix into a flat
# { machine = {...}; user = {...}; } map, for the CLI wizard's help text.
#
# Regenerate the embedded snapshot with:
#   NEUSIS_ROOT=<path-to-neusis-repo> \
#     nix eval --impure --json -f extract.nix > files/schema.json
let
  root = builtins.getEnv "NEUSIS_ROOT";
  flake = builtins.getFlake ("path:" + root);
  lib = flake.inputs.nixpkgs.lib;
  fpLib = flake.inputs.flake-parts.lib;

  optMod = import (root + "/new_modules/lib/neusis-options.nix") {
    inherit lib;
    flake-parts-lib = fpLib;
  };
  evaluated = lib.evalModules { modules = [ optMod ]; };

  flakeOpts = evaluated.options.flake.type.getSubOptions [ ];
  neusisOpts = flakeOpts.neusis.type.getSubOptions [ ];
  machineOpts = neusisOpts.machines.type.nestedTypes.elemType.getSubOptions [ ];
  userOpts =
    (neusisOpts.users.type.nestedTypes.elemType.getSubOptions [ ]).neusisOS.type.getSubOptions [ ];

  # Collapse the multi-line option description into a single line.
  clean = s: lib.concatStringsSep " " (lib.filter (x: x != "") (lib.splitString "\n" s));
  fields =
    opts: lib.mapAttrs (_: o: clean (o.description or "")) (lib.filterAttrs (n: _: n != "_module") opts);
in
{
  machine = fields machineOpts;
  user = fields userOpts;
}
