# supercharged-git: lazygit module.
# Enables `programs.lazygit` with delta as the diff pager by default
# (only takes effect if you also enable the delta tool module).
{ ... }:
{
  flake.homeModules.supercharged-git-lazygit =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.neusis.supercharged-git.tools.lazygit;
    in
    {
      options.neusis.supercharged-git.tools.lazygit = {
        enable = lib.mkEnableOption "lazygit TUI";

        settings = lib.mkOption {
          type = lib.types.attrs;
          default = {
            git.paging = {
              colorArg = "always";
              pager = "delta --paging=never";
            };
          };
          description = "lazygit settings written to its config.yml.";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.lazygit = {
          enable = true;
          settings = cfg.settings;
        };
      };
    };
}
