# Tests for the pure helpers in flake.neusis.lib.kalam (modules/lib/kalam.nix).
# mkKalam itself is exercised by the package checks (it builds nixvim).
{ self, inputs, ... }:
{
  perSystem =
    { testPkgs, ... }:
    let
      k = self.neusis.lib.kalam;
    in
    {
      tests.lib-kalam = {
        test-icons-table-sections = {
          expr = builtins.attrNames k.icons;
          expected = [
            "diagnostics"
            "git"
            "ui"
          ];
        };

        test-whichkey-spec-full = {
          expr = k.whichkeySpec [
            "<leader>f"
            ""
            "find"
            true
          ];
          expected = {
            __unkeyed = "<leader>f";
            group = "find";
            hidden = true;
          };
        };

        test-whichkey-spec-drops-empty-and-missing = {
          expr = {
            two = k.whichkeySpec [
              "<leader>g"
              "G"
            ];
            empties = k.whichkeySpec [
              ""
              ""
              ""
            ];
          };
          expected = {
            two = {
              __unkeyed = "<leader>g";
              icon = "G";
            };
            empties = { };
          };
        };

        test-mk-keymap-defaults = {
          expr = k.mkKeymap {
            key = "<leader>ff";
            action = "<cmd>Telescope find_files<cr>";
          };
          expected = {
            key = "<leader>ff";
            action = "<cmd>Telescope find_files<cr>";
            mode = "n";
            # desc is null and therefore filtered out
            options = {
              silent = true;
              noremap = true;
              expr = false;
            };
          };
        };

        test-mk-keymap-overrides = {
          expr = k.mkKeymap {
            key = "jk";
            action = "<esc>";
            mode = "i";
            desc = "escape";
            silent = false;
          };
          expected = {
            key = "jk";
            action = "<esc>";
            mode = "i";
            options = {
              desc = "escape";
              silent = false;
              noremap = true;
              expr = false;
            };
          };
        };

        test-mk-plugin-builds-vim-plugin = {
          expr =
            let
              p = k.mkPlugin testPkgs "fixture-plugin" ../_fixtures;
            in
            {
              name = p.name;
              isDrv = testPkgs.lib.isDerivation p;
            };
          expected = {
            # buildVimPlugin prefixes the derivation name
            name = "vimplugin-fixture-plugin";
            isDrv = true;
          };
        };

        # Flavor directories map to package names: `base` → kalam,
        # anything else → kalam-<dir>. Lazy: nothing is built.
        test-mk-kalam-variants-names-flavors = {
          expr = builtins.attrNames (
            k.mkKalamVariants {
              pkgs = testPkgs;
              inherit inputs;
              outputs = self;
              root = ../../packages/kalam/_flavors;
            }
          );
          expected = [
            "kalam"
            "kalam-full"
          ];
        };
      };
    };
}
