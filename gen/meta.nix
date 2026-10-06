# Everything render.py needs that isn't a module option, as one JSON
# file:
#   lib        neusis.neusis.lib.<group>.<fn>: source position, named
#              arguments (true = has a default). render.py reads the
#              comment block above each position for the prose.
#   templates  neusis.templates.<name>.description
#   packages   neusis.packages.<system>.<name>.meta.description
{
  pkgs,
  neusis,
}:
let
  inherit (pkgs) lib;
  root = toString neusis.outPath;
  system = pkgs.stdenv.hostPlatform.system;

  describeFn =
    group: name: value:
    let
      pos = builtins.unsafeGetAttrPos name group;
    in
    {
      type = builtins.typeOf value;
      args = if lib.isFunction value then lib.functionArgs value else null;
      file = if pos == null then null else lib.removePrefix "${root}/" pos.file;
      line = if pos == null then null else pos.line;
    };
in
pkgs.writeText "neusis-meta.json" (
  builtins.toJSON {
    lib = lib.mapAttrs (_: group: lib.mapAttrs (describeFn group) group) neusis.neusis.lib;
    templates = lib.mapAttrs (_: t: t.description or "") neusis.templates;
    packages = lib.mapAttrs (_: p: p.meta.description or "") (neusis.packages.${system} or { });
  }
)
