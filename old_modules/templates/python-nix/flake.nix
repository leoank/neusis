{
  description = "Pure Nix: Reproducible Python with nixpkgs only";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            (pkgs.python312.withPackages (ps: with ps; [
              # Standard data science (all in nixpkgs)
              numpy
              pandas
              scikit-learn
              matplotlib

              # Common tools (all in nixpkgs)
              typer
              loguru
              snakemake
              duckdb
            ]))
          ];

          shellHook = ''
            echo "Pure Nix Python Environment"
          '';
        };
      });
}
