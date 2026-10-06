# supercharged-git: pre-commit module.
# Installs `pre-commit` and wires it as the default git hooks template
# directory so `git init` in any new repo gets the hooks scaffold.
{ ... }:
{
  flake.homeModules.supercharged-git-pre-commit =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.supercharged-git.tools.pre-commit;
    in
    {
      options.neusis.supercharged-git.tools.pre-commit = {
        enable = lib.mkEnableOption "pre-commit hooks framework";

        autoInstall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Set git's `init.templateDir` so `pre-commit init-templatedir`
            scaffolds the hook on every newly cloned/init'd repo.
            Disable if you want fully per-repo opt-in.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ pkgs.pre-commit ];
        programs.git.settings = lib.mkIf cfg.autoInstall {
          init.templateDir = "~/.config/git/template";
        };
      };
    };
}
