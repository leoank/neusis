# Tests for kalam-zero (modules/packages/kalam/_flavors/zero, ADR-0016).
#
# T0: the flavour's config differs from base where it must.
# Checks (T1 evaluates, T2 builds): `kalam-zero-headless` and
# `kalam-zero-headless-no-rg` install `kalam-zero-init`'s init.lua the way
# a user would (NVIM_APPNAME=kalam) and run `_kalam-zero/headless.lua`
# against it in a scratch git repo: startup is silent, every shortcut is
# mapped, and each fallback runs. The second variant has no ripgrep on
# PATH, so grep and :find use their fallbacks.
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
        withRg:
        pkgs.runCommand "kalam-zero-headless${lib.optionalString (!withRg) "-no-rg"}"
          {
            nativeBuildInputs = [
              pkgs.neovim-unwrapped
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
            if ! nvim --headless -c "luafile ${./_kalam-zero/headless.lua}" > $TMPDIR/out 2>&1; then
              cat $TMPDIR/out >&2
              exit 1
            fi
            cat $TMPDIR/out
            cp $TMPDIR/out $out
          '';
    in
    {
      checks = {
        kalam-zero-headless = headless true;
        kalam-zero-headless-no-rg = headless false;
      };

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

        test-no-plugins-and-no-providers = {
          expr = {
            # nixvim's own `nvim-config` carries the config; nothing else
            plugins = lib.filter (n: n != "nvim-config") (
              map (p: p.name or p.plugin.name) zero.config.build.plugins
            );
            python = zero.config.withPython3;
            ruby = zero.config.withRuby;
            fallbacks = lib.hasInfix "_G.KalamZero" zero.config.extraConfigLua;
          };
          expected = {
            plugins = [ ];
            python = false;
            ruby = false;
            fallbacks = true;
          };
        };
      };
    };
}
