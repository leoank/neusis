# supercharged-git: gh (GitHub CLI) module.
# Enables `programs.gh` with gh-dash and gh-copilot extensions
# pre-installed. Override `extensions` to swap or extend.
{ ... }:
{
  flake.homeModules.supercharged-git-gh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.supercharged-git.tools.gh;
    in
    {
      options.neusis.supercharged-git.tools.gh = {
        enable = lib.mkEnableOption "GitHub CLI (`gh`)";

        extensions = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = with pkgs; [
            gh-dash
            gh-copilot
          ];
          defaultText = lib.literalExpression "with pkgs; [ gh-dash gh-copilot ]";
          description = "gh extensions to install alongside the CLI.";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.gh = {
          enable = true;
          extensions = cfg.extensions;
          gitCredentialHelper.enable = true;
        };
      };
    };
}
