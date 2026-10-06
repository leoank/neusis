# supercharged-git: gh (GitHub CLI) module.
# Enables `programs.gh` with the gh-dash extension pre-installed.
# Override `extensions` to swap or extend. (gh-copilot was dropped:
# archived upstream, removed from nixpkgs 26.05.)
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
          ];
          defaultText = lib.literalExpression "with pkgs; [ gh-dash ]";
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
