# supercharged-git: act module.
# Installs `act` for running GitHub Actions workflows locally via
# Docker / Podman / OrbStack containers.
{ ... }:
{
  flake.homeModules.supercharged-git-act =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.supercharged-git.tools.act;
    in
    {
      options.neusis.supercharged-git.tools.act = {
        enable = lib.mkEnableOption "act (local GitHub Actions runner)";
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ pkgs.act ];
      };
    };
}
