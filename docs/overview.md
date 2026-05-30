# Overview

The flake uses `dendritic` pattern for organization.
Every file inside the `modules` directory is a `flake-parts` top level module.
These modules are automatically imported into the flake using the `import-tree` package.

No file based imports are used in this flake. Every output of the flake can be accessed through the `self` property.
Every `flake-parts` module gets a perconfigured `pkgs` based on the configuration here: `modules/default.nix`

# Bootstrapping the flake.nix
Don't follow the instruction in the official docs of `flake-file`. Manually create a flake.nix with following contents:
```
{
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
    };
    import-tree.url = "github:vic/import-tree";
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    nixpkgs-lib.follows = "nixpkgs";
  };
}
```
and then run `nix run .#write-flake`

> Note: Make sure the `modules` path in the output string matches with you modules folder path. Also that folder should be added to git staging area if you are doing this is inside a git repo.

> Note: after adding a new flake-file.input, run `nix run .#write-flake` before using the flake input in code. Otherwise this command will fail eventually.

# Modules inside the new-modules folder

Directories and names of the files are inconsequential. The only thing that matters is the flake module declarations inside each file. We have standard flake outputs and some non-standard flake outputs. For each non-standard flake output we define a <non-standard-ouput>-options.nix file. This helps to have that output scattered across multiple files, and still be mergeable by flake-parts.

- standard outputs: nixosModules, packages, shells, nixosConfigurations
- non-standard: users, registry, lib
- outputs defined from input flakes: homeModules, darwinConfigurations
