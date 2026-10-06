# `flake.neusis.lib.kalam` — helpers for building kalam (nixvim)
# distributions.
#
# Two layers:
#
#   1. Plain helper functions intended to be used inside individual
#      nixvim modules: icon tables, plugin-from-source builders,
#      which-key entry shorthands, keymap shorthands.
#   2. `mkKalam` / `mkKalamVariants` — given a flavor directory (or a
#      root directory containing flavor subdirectories) and a `pkgs`,
#      build the corresponding nixvim derivation(s). Subdir name
#      `base` maps to package `kalam`; anything else maps to
#      `kalam-<dirname>`.
#
# Architecture vs the legacy `pkgs/kalam{,py,v2}/default.nix`:
#
#   - The legacy code did `import inputs.nixpkgs { … cudaSupport = true;
#     overlays = [ outputs.overlays.git-worktree ]; }` *inside* every
#     kalam derivation, forcing a full nixpkgs rebuild per flavor and
#     baking in CUDA. Here `pkgs` is passed in verbatim; if a flavor
#     needs an overlay (e.g. `git-worktree-custom`), the perSystem
#     driver applies it via `pkgs.extend` once before calling.
#   - Each legacy flavor shipped an identical `lib/{default,icons}.nix`.
#     Those helpers now live here. Per-flavor `lib/` is still honoured
#     when present (merged into `extraSpecialArgs` after the shared
#     helpers) so flavor-specific overrides keep working.
{ lib, ... }:
{
  flake.neusis.lib.kalam = rec {
    # Static icon table (nerd-font glyphs). Used by lualine, neotree,
    # which-key, etc.
    icons = import ./_kalam/icons.nix;

    # Build a vim plugin from a name + source attribute. Use for
    # plugins that don't ship in nixpkgs.
    #
    #   kalamLib.mkPlugin pkgs "my-plugin" inputs.my-plugin-src
    mkPlugin = pkgs: name: src: pkgs.vimUtils.buildVimPlugin { inherit name src; };

    # which-key icon-spec generator. Takes a positional list
    # `[ binding icon ?group ?hidden ]` and returns the corresponding
    # attrset (matching `require("which-key").add()`'s shape).
    # Empty-string entries are dropped.
    whichkeySpec =
      list:
      let
        len = builtins.length list;
        at = builtins.elemAt list;
        first = lib.optionalAttrs (at 0 != "") { __unkeyed = at 0; };
        second = lib.optionalAttrs (at 1 != "") { icon = at 1; };
        third = lib.optionalAttrs (len > 2 && at 2 != "") { group = at 2; };
        fourth = lib.optionalAttrs (len > 3 && at 3 != "") { hidden = at 3; };
      in
      first // second // third // fourth;

    # Short-form for a single nixvim `keymaps = [ … ]` entry.
    # All flags after `action` are optional; null-valued options are
    # filtered out before being passed to nixvim.
    #
    #   kalamLib.mkKeymap { key = "<leader>ff"; action = "<cmd>Telescope find_files<cr>";
    #                       desc = "find files"; }
    mkKeymap =
      {
        key,
        action,
        mode ? "n",
        desc ? null,
        silent ? true,
        noremap ? true,
        expr ? false,
      }:
      {
        inherit key action mode;
        options = lib.filterAttrs (_: v: v != null) {
          inherit
            desc
            silent
            noremap
            expr
            ;
        };
      };

    # Build a single kalam variant from a flavor directory.
    #
    #   flavorDir/
    #   ├── config/            — the nixvim module (entry point)
    #   └── lib/ (optional)    — extra helpers merged into extraSpecialArgs
    #
    # `pkgs` is used verbatim. Apply overlays via `pkgs.extend` at the
    # call site if a flavor needs them.
    mkKalam =
      {
        pkgs,
        inputs,
        outputs,
        flavorDir,
      }:
      let
        nixvim = inputs.nixvim.legacyPackages.${pkgs.stdenv.hostPlatform.system};

        flavorLibPath = flavorDir + "/lib";
        flavorLib = lib.optionalAttrs (builtins.pathExists flavorLibPath) (
          import flavorLibPath { inherit lib pkgs; }
        );

        # Helpers exposed to flavor config modules via extraSpecialArgs.
        # `kalamLib` is the canonical namespace; the top-level aliases
        # below preserve the legacy `icons` / `mkPkgs` / `specObj`
        # names so unported flavor modules keep working unchanged.
        kalamLib = {
          inherit icons mkKeymap whichkeySpec;
          mkPlugin = mkPlugin pkgs;
        };

        legacyAliases = {
          inherit icons;
          mkPkgs = mkPlugin pkgs;
          specObj = whichkeySpec;
        };
      in
      nixvim.makeNixvimWithModule {
        inherit pkgs;
        module = import (flavorDir + "/config");
        extraSpecialArgs = {
          inherit inputs outputs kalamLib;
        }
        // legacyAliases
        // flavorLib;
      };

    # Build every kalam variant under `root`. Each subdirectory is one
    # flavor. Subdir `base` is packaged as `kalam`; any other
    # `<name>` is packaged as `kalam-<name>`.
    #
    # Returns an attrset suitable for assignment to `perSystem.packages`.
    mkKalamVariants =
      {
        pkgs,
        inputs,
        outputs,
        root,
      }:
      let
        entries = builtins.readDir root;
        flavors = lib.filterAttrs (_: t: t == "directory") entries;
        toPkgName = n: if n == "base" then "kalam" else "kalam-${n}";
      in
      lib.mapAttrs' (
        n: _:
        lib.nameValuePair (toPkgName n) (mkKalam {
          inherit pkgs inputs outputs;
          flavorDir = root + "/${n}";
        })
      ) flavors;
  };
}
