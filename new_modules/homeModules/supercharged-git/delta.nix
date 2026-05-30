# supercharged-git: delta module.
# Wires `delta` in as the git pager via home-manager's
# `programs.git.delta`. Defaults to a `decorations + navigate` feature
# set which gives line numbers and Tab/N navigation between hunks.
{ ... }:
{
  flake.homeModules.supercharged-git-delta =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.neusis.supercharged-git.tools.delta;
    in
    {
      options.neusis.supercharged-git.tools.delta = {
        enable = lib.mkEnableOption "delta diff pager for git";

        options = lib.mkOption {
          type = lib.types.attrs;
          default = {
            features = "decorations navigate";
            navigate = true;
            line-numbers = true;
            side-by-side = true;
            dark = true;
          };
          description = "Options written to git's `[delta]` section.";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.git.delta = {
          enable = true;
          options = cfg.options;
        };
      };
    };
}
