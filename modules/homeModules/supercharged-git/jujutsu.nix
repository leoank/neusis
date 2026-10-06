# supercharged-git: jujutsu (jj) module.
# Enables `programs.jujutsu` and seeds user.name/email from the
# umbrella's `userName`/`userEmail` so jj and git agree on identity.
{ ... }:
{
  flake.homeModules.supercharged-git-jujutsu =
    {
      config,
      lib,
      ...
    }:
    let
      gitCfg = config.neusis.supercharged-git;
      cfg = config.neusis.supercharged-git.tools.jujutsu;
    in
    {
      options.neusis.supercharged-git.tools.jujutsu = {
        enable = lib.mkEnableOption "jujutsu (jj) VCS";

        extraSettings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Extra settings merged into `programs.jujutsu.settings`.";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.jujutsu = {
          enable = true;
          settings = lib.recursiveUpdate {
            user = {
              name = gitCfg.userName;
              email = gitCfg.userEmail;
            };
            ui.default-command = "log";
          } cfg.extraSettings;
        };
      };
    };
}
