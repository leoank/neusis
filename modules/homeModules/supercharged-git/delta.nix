# supercharged-git: delta module.
# Wires `delta` in as the git pager via home-manager's standalone
# `programs.delta` with `enableGitIntegration = true`. The defaults
# ship a side-by-side, dark, dracula-themed config with custom
# decoration / line-number styles (yellow file headers, cyan hunk
# headers, color-coded line numbers, plus/minus background tinting).
# Override `options` to swap the theme or change the layout.
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
            features = "side-by-side line-numbers decorations navigate";
            syntax-theme = "dracula";
            navigate = true;
            decorations = {
              commit-decoration-style = "bold yellow box ul";
              file-decoration-style = "none";
              file-style = "bold yellow ul";
              hunk-header-decoration-style = "cyan box ul";
            };
            plus-style = "syntax '#003800'";
            minus-style = "syntax '#3f0001'";
            line-numbers = {
              line-numbers-left-style = "cyan";
              line-numbers-right-style = "cyan";
              line-numbers-minus-style = "124";
              line-numbers-plus-style = "28";
            };
          };
          description = ''
            Options written to git's `[delta]` and `[delta "<name>"]`
            sections via home-manager's `programs.delta.options`.
            See <https://dandavison.github.io/delta/configuration.html>
            for the full set.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        programs.delta = {
          enable = true;
          enableGitIntegration = true;
          options = cfg.options;
        };
      };
    };
}
