# supercharged-git: mergiraf module.
# Installs `mergiraf` (semantic 3-way merge for Markdown/Nix/JSON/…)
# and registers it as a git merge driver. To opt a path in, add to
# the repo's `.gitattributes`:
#   *.nix merge=mergiraf
#   *.md  merge=mergiraf
{ ... }:
{
  flake.homeModules.supercharged-git-mergiraf =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.supercharged-git.tools.mergiraf;
    in
    {
      options.neusis.supercharged-git.tools.mergiraf = {
        enable = lib.mkEnableOption "mergiraf semantic merge driver";
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ pkgs.mergiraf ];
        programs.git.settings.merge.mergiraf = {
          name = "mergiraf";
          driver = "${pkgs.mergiraf}/bin/mergiraf merge --git %O %A %B -s %S -x %X -y %Y -p %P";
          recursive = "binary";
        };
      };
    };
}
