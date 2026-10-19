# terranix: infrastructure as code in Nix (cloud machines).
#
# Declares the `terranix` input, imports its flake-parts module
# (`perSystem.terranix.terranixConfigurations.<stack>` → `packages.<sys>.
# <stack>` with `.init/.plan/.apply/.destroy/.terraform` passthrus and a
# devShell per stack) and applies the neusis defaults from
# `_terranix-defaults.nix` to every stack. Design: docs/cloud-terranix-spec.md.
{ inputs, ... }:
{
  flake-file.inputs.terranix = {
    url = "github:terranix/terranix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  imports = [
    inputs.terranix.flakeModule
    ./_terranix-defaults.nix
  ];
}
