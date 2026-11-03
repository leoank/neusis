# Tests for kalam-zero (modules/packages/kalam/_flavors/zero, ADR-0016).
#
# T0: the flavour's config differs from base where it must.
# Checks (T1 evaluates, T2 builds): `kalam-zero-headless` and
# `kalam-zero-headless-no-rg` install `kalam-zero-init`'s init.lua the way
# a user would (NVIM_APPNAME=kalam) and run `_kalam-zero/headless.lua`
# against it in a scratch git repo: startup is silent, every shortcut is
# mapped, oil (inlined) works, and each fallback runs. The second variant
# has no ripgrep on PATH, so grep and :find use their fallbacks. On
# x86_64-linux, `kalam-zero-headless-nvim-0_{8,9,10,11}` run the same test
# on the official release builds (`_kalam-zero/neovim-releases.nix`), the
# versions nixpkgs doesn't carry.
{ self, ... }:
{
  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    let
      zero = self.packages.${system}.kalam-zero;
      init = self.packages.${system}.kalam-zero-init;

      headless =
        {
          name,
          nvim ? pkgs.neovim-unwrapped,
          withRg ? true,
          # NVIM_APPNAME arrived in 0.9; on 0.8 the file is passed with -u,
          # as the install instructions say (ADR-0016)
          appname ? true,
        }:
        pkgs.runCommand name
          {
            nativeBuildInputs = [
              nvim
              pkgs.git
            ]
            ++ lib.optional withRg pkgs.ripgrep;
          }
          ''
            export HOME=$TMPDIR/home NVIM_APPNAME=kalam
            export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/.local/state XDG_DATA_HOME=$HOME/.local/share
            install -Dm644 ${init}/init.lua $XDG_CONFIG_HOME/kalam/init.lua

            mkdir -p $TMPDIR/repo/src && cd $TMPDIR/repo
            echo "a needle in here" > needle.txt
            echo "return 1" > src/other.lua
            git init -q && git add . && git -c user.name=t -c user.email=t@t commit -qm init

            export KALAM_ZERO_EXPECT_RG=${if withRg then "1" else "0"}
            if ! nvim ${lib.optionalString (!appname) "-u $XDG_CONFIG_HOME/kalam/init.lua"} --headless -c "luafile ${./_kalam-zero/headless.lua}" > $TMPDIR/out 2>&1; then
              cat $TMPDIR/out >&2
              exit 1
            fi
            cat $TMPDIR/out
            cp $TMPDIR/out $out
          '';

      releases = import ./_kalam-zero/neovim-releases.nix pkgs;
    in
    {
      checks = {
        kalam-zero-headless = headless { name = "kalam-zero-headless"; };
        kalam-zero-headless-no-rg = headless {
          name = "kalam-zero-headless-no-rg";
          withRg = false;
        };
      }
      // lib.optionalAttrs (system == "x86_64-linux") (
        lib.mapAttrs' (
          v: nvim:
          let
            name = "kalam-zero-headless-nvim-${lib.replaceStrings [ "." ] [ "_" ] v}";
          in
          lib.nameValuePair name (
            headless {
              inherit name nvim;
              appname = v != "0.8";
            }
          )
        ) releases
      );

      tests.pkg-kalam-zero = {
        test-overrides-base-where-it-must = {
          expr = {
            inherit (zero.config.opts)
              foldmethod
              exrc
              termguicolors
              timeoutlen
              ;
            # base's options and keymaps come through unchanged
            leader = zero.config.globals.mapleader;
            save = lib.any (k: k.key == "<leader><space>") zero.config.keymaps;
          };
          expected = {
            foldmethod = "indent";
            exrc = false;
            termguicolors = false;
            timeoutlen = 800;
            leader = " ";
            save = true;
          };
        };

        test-only-oil-and-mini-and-no-providers = {
          expr = {
            # nixvim's own `nvim-config` carries the config; besides it,
            # oil and mini (inlined in kalam-zero-init, ADR-0017/0018)
            plugins = lib.sort lib.lessThan (
              map (n: if lib.hasInfix "oil.nvim" n then "oil" else if lib.hasInfix "mini.nvim" n then "mini" else n) (
                lib.filter (n: n != "nvim-config") (map (p: p.name or p.plugin.name) zero.config.build.plugins)
              )
            );
            python = zero.config.withPython3;
            ruby = zero.config.withRuby;
            fallbacks = lib.hasInfix "_G.KalamZero" zero.config.extraConfigLua;
          };
          expected = {
            plugins = [
              "mini"
              "oil"
            ];
            python = false;
            ruby = false;
            fallbacks = true;
          };
        };
      };
    };
}
