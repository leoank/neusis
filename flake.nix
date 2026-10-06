{
  description = "neusis documentation website";

  inputs = {
    # The library being documented. CI bumps this to the tip of main
    # before every build; locally, preview uncommitted work with
    #   nix build --override-input neusis path:../main
    neusis.url = "github:leoank/neusis";
    nixpkgs.follows = "neusis/nixpkgs";
  };

  outputs =
    { self, nixpkgs, neusis }:
    let
      # Wherever neusis builds its CLI (needed for the CLI reference).
      systems = builtins.attrNames neusis.packages;
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAll (pkgs: rec {
        site = pkgs.callPackage ./gen/site.nix { inherit neusis; };
        default = site;
        # Intermediate artifacts, handy when hacking on render.py.
        inherit (site.passthru) optionsJson metaJson cliJson generated;
      });

      apps = forAll (pkgs: {
        # Live-reloading preview: `nix run .#serve`
        serve = {
          type = "app";
          program = toString (
            pkgs.writeShellScript "serve" ''
              set -euo pipefail
              ${self.packages.${pkgs.stdenv.hostPlatform.system}.site.passthru.prepare}/bin/prepare-site
              exec ${pkgs.mdbook}/bin/mdbook serve --open "$@"
            ''
          );
        };
      });

      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.mdbook
            pkgs.python3
          ];
        };
      });
    };
}
