# supercharged-git: graphite-cli module.
# Installs `gt` for stacked-PR workflows on GitHub.
{ ... }:
{
  flake.homeModules.supercharged-git-graphite =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.supercharged-git.tools.graphite;
    in
    {
      options.neusis.supercharged-git.tools.graphite = {
        enable = lib.mkEnableOption "graphite-cli (stacked PRs)";
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ pkgs.graphite-cli ];
      };
    };
}
