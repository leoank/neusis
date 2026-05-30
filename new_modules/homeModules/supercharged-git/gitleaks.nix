# supercharged-git: gitleaks module.
# Installs `gitleaks` for secret scanning. Wire it into pre-commit's
# repo-local config to actually run on every commit — this module
# only puts the binary on PATH.
{ ... }:
{
  flake.homeModules.supercharged-git-gitleaks =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.supercharged-git.tools.gitleaks;
    in
    {
      options.neusis.supercharged-git.tools.gitleaks = {
        enable = lib.mkEnableOption "gitleaks (secret scanner)";
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ pkgs.gitleaks ];
      };
    };
}
