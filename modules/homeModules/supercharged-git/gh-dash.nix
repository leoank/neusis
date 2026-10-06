# supercharged-git: gh-dash module.
# Standalone gh-dash binary on PATH. If you already enabled the `gh`
# tool module its `extensions` default already includes gh-dash; this
# module is for the rare case where you want the binary without
# enabling gh itself.
{ ... }:
{
  flake.homeModules.supercharged-git-gh-dash =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.supercharged-git.tools.gh-dash;
    in
    {
      options.neusis.supercharged-git.tools.gh-dash = {
        enable = lib.mkEnableOption "gh-dash (GitHub PR/issue dashboard)";
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ pkgs.gh-dash ];
      };
    };
}
