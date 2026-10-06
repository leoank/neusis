# supercharged-shell: zoxide module.
# Smarter `cd`. After a few visits, `z partial-name` jumps you to
# the highest-ranked match. `zi` opens an fzf-style interactive
# picker over your frecency-ranked history.
{ ... }:
{
  flake.homeModules.supercharged-shell-zoxide =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.neusis.supercharged-shell.tools.zoxide;
    in
    {
      options.neusis.supercharged-shell.tools.zoxide = {
        enable = lib.mkEnableOption "zoxide smarter-cd";
      };

      config = lib.mkIf cfg.enable {
        programs.zoxide = {
          enable = true;
          enableBashIntegration = true;
          enableZshIntegration = true;
        };
      };
    };
}
