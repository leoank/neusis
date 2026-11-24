# The home-manager generation for one variant of agenix's darwin job, from neusis's locked
# nixpkgs, home-manager and agenix: one throwaway secret, decrypted into a scratch directory,
# under a test label so ank's real agent is never touched. The plist is
# $out/LaunchAgents/<label>.plist, exactly what home-manager would install.
{
  repo,
  work,
  secret,
  label,
  variant, # upstream | keepalive | wrapped
}:
let
  f = builtins.getFlake repo;
  pkgs = f.inputs.nixpkgs.legacyPackages.aarch64-darwin;
  lib = pkgs.lib;
  candidates = {
    upstream = [ ];
    keepalive = [ ./keepalive.nix ];
    wrapped = [
      ./keepalive.nix
      ./wrapper.nix
    ];
  };
  hm = f.inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      f.inputs.agenix.homeManagerModules.default
      {
        home.username = "ank";
        home.homeDirectory = "/Users/ank";
        home.stateVersion = "25.05";
        manual.manpages.enable = false;
        news.display = "silent";
        age.identityPaths = [ "${work}/id.txt" ];
        age.secretsDir = "${work}/agenix";
        age.secretsMountPoint = "${work}/agenix.d";
        age.secrets.t.file = /. + secret;
        launchd.agents.activate-agenix.config = {
          Label = lib.mkForce label;
          StandardOutPath = lib.mkForce "${work}/stdout";
          StandardErrorPath = lib.mkForce "${work}/stderr";
        };
      }
    ]
    ++ candidates.${variant};
  };
in
hm.activationPackage
