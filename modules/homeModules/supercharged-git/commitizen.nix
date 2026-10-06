# supercharged-git: commitizen module.
# Installs `cz` for guided conventional-commit prompts. Pairs well
# with pre-commit's commit-msg hook for enforcement.
{ ... }:
{
  flake.homeModules.supercharged-git-commitizen =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.supercharged-git.tools.commitizen;
    in
    {
      options.neusis.supercharged-git.tools.commitizen = {
        enable = lib.mkEnableOption "commitizen (`cz`) for conventional commits";
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ pkgs.commitizen ];
        programs.git.settings.alias = {
          cz = "!cz commit";
        };
      };
    };
}
