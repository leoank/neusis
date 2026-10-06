# Overview

The flake uses `dendritic` pattern for organization.
Every file inside the `modules` directory is a `flake-parts` top level module.
These modules are automatically imported into the flake using the `import-tree` package.

No file based imports are used in this flake. Every output of the flake can be accessed through the `self` property.
Every `flake-parts` module gets a perconfigured `pkgs` based on the configuration here: `modules/system-pkgs.nix`

> Note: after adding a new flake-file.input, run `nix run .#write-flake` before using the flake input in code. Otherwise this command will fail eventually.

# Modules inside the modules folder

Directories and names of the files are inconsequential. The only thing that matters is the flake module declarations inside each file. We have standard flake outputs and some non-standard flake outputs. For each non-standard flake output we define a `<non-standard-output>-options.nix` file. This helps to have that output scattered across multiple files, and still be mergeable by flake-parts.

- standard outputs: nixosModules, packages, shells, nixosConfigurations
- non-standard: users, registry, lib
- outputs defined from input flakes: homeModules, darwinConfigurations
