# supercharged-shell: nix-your-shell module.
# Wraps `nix-shell` / `nix develop` so they use your *current* shell
# (zsh, here) inside the dev env instead of dropping into bash.
# Stays out of your way until you type `nix-shell …`.
{ ... }:
{
  flake.homeModules.supercharged-shell-nix-your-shell =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.neusis.supercharged-shell.tools.nix-your-shell;
    in
    {
      options.neusis.supercharged-shell.tools.nix-your-shell = {
        enable = lib.mkEnableOption "nix-your-shell (keep current shell inside nix-shell)";
      };

      config = lib.mkIf cfg.enable {
        programs.nix-your-shell = {
          enable = true;
          enableZshIntegration = true;
        };
      };
    };
}
