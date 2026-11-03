# Publishes every kalam flavor under `./_flavors/<name>` as a perSystem
# package via `flake.neusis.lib.kalam.mkKalamVariants`. Subdir `base`
# becomes `kalam`; any other `<name>` becomes `kalam-<name>`.
#
# `git-worktree` overlay is applied via `pkgs.extend` because some
# flavor config modules reference `pkgs.git-worktree-custom` (see
# `_flavors/*/config/plugins/git/git-worktree.nix`). All other build
# inputs come from the perSystem `pkgs` configured in
# `modules/system-pkgs.nix` — no per-package nixpkgs rebuild.
{ self, ... }:
{
  flake-file.inputs.nixvim = {
    url = "github:nix-community/nixvim/nixos-26.05";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  perSystem =
    { pkgs, ... }:
    let
      variants = self.neusis.lib.kalam.mkKalamVariants {
        pkgs = pkgs.extend self.outputs.overlays.git-worktree;
        inherit (self) inputs outputs;
        root = ./_flavors;
      };

      # kalam-zero as a standalone init.lua for machines without Nix
      # (ADR-0016): the same config with nixvim's wrapper assumptions
      # removed. RUN-20261103-g9nmnp found these options sufficient; the
      # build fails if the file still names the Nix store.
      zeroInit =
        (variants.kalam-zero.extend {
          wrapRc = false;
          impureRtp = true;
          luaLoader.enable = null;
        }).config.build.initFile;

      # Pure-Lua plugins inlined into the file (ADR-0017): each module
      # becomes a `package.preload` entry ahead of the config, so
      # `require` finds it with nothing installed. Syntax files can't go
      # through `vim.cmd` (`:finish`), so they're written into a
      # per-process temp dir on 'runtimepath'. Same packages as base's.
      # `files` (paths under lua/) picks modules out of a collection like
      # mini.nvim (ADR-0018); null takes the plugin's whole `<name>/` tree.
      inlinePlugin =
        {
          name,
          plugin,
          files ? null,
        }:
        ''
        {
          echo "-- ${name} (${plugin.version}), inlined by kalam-zero (ADR-0017). Its license:"
          sed 's/^/-- /' ${plugin.src}/LICENSE
          (cd ${plugin}/lua && ${
            if files == null then "find ${name} -name '*.lua' | sort" else "printf '%s\n' ${toString files}"
          }) | while read -r f; do
            mod=''${f%.lua}; mod=''${mod%/init}; mod=''${mod//\//.}
            printf 'package.preload["%s"] = function(...)\n' "$mod"
            cat "${plugin}/lua/$f"
            printf '\nend\n'
          done
          if [ -d ${plugin}/syntax ]; then
            echo 'do'
            echo '  local dir = vim.fn.tempname() .. "-kalam-zero"'
            echo '  vim.fn.mkdir(dir .. "/syntax", "p")'
            for s in ${plugin}/syntax/*.vim; do
              if grep -q ']==]' "$s"; then echo "kalam-zero-init: $s contains ]==]" >&2; exit 1; fi
              printf '  vim.fn.writefile(vim.split([==[%s]==], "\\n"), dir .. "/syntax/%s")\n' "$(cat "$s")" "$(basename "$s")"
            done
            echo '  vim.opt.runtimepath:append(dir)'
            echo 'end'
          fi
        } >> init.lua
      '';
    in
    {
      packages = variants // {
        kalam-zero-init = pkgs.runCommand "kalam-zero-init" { } ''
          : > init.lua
          ${inlinePlugin {
            name = "oil";
            plugin = variants.kalam.config.plugins.oil.package;
          }}
          ${inlinePlugin {
            name = "mini.nvim";
            plugin = variants.kalam.config.plugins.mini.package;
            files = map (m: "mini/${m}.lua") [
              "surround"
              "pairs"
              "move"
              "bracketed"
              "splitjoin"
              "pick"
              "clue"
            ];
          }}
          cat ${zeroInit} >> init.lua
          if grep -n /nix/store init.lua; then
            echo "kalam-zero-init: init.lua references the Nix store" >&2
            exit 1
          fi
          install -Dm644 init.lua $out/init.lua
        '';
      };
    };
}
