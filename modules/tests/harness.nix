# Test harness for neusis (see docs/testing.md).
#
# Provides three things:
#
#   * `perSystem.tests` — an attrset of nix-unit test cases, transposed
#     to `flake.tests.<system>` so `nix-unit --flake .#tests.<system>`
#     finds it. Test files under modules/tests/ write into it.
#   * `flake.neusis.lib.tests` — eval helpers (`evalHm`, `evalDarwin`,
#     `evalNixos`, …) and the shared fixtures under ./_fixtures.
#   * `packages.neusis-test` — `nix run .#neusis-test [args]` runs
#     nix-unit against the current system's tests.
#
# Tests receive `testPkgs`: the perSystem `pkgs` with neusis's overlays
# applied once per system, so `pkgs.unstable` / `pkgs.inputs.*` resolve
# the way they do on real hosts.
{
  self,
  inputs,
  lib,
  flake-parts-lib,
  ...
}:
let
  specialArgs = {
    inherit inputs;
    outputs = self;
  };

  fixtures = import ./_fixtures { inherit self lib inputs; };
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption {
    options.tests = lib.mkOption {
      type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.raw);
      default = { };
      description = ''
        nix-unit test cases for this system, grouped one attrset per test
        file: `tests.<group>.test-<what> = { expr; expected; }` or
        `{ expr; expectedError = { type; msg; }; }`. nix-unit only runs
        attributes whose name starts with `test` and silently ignores the
        rest, so a misnamed test throws here instead of vanishing.
        Published as `flake.tests.<system>`.
      '';
      apply = lib.mapAttrs (
        group:
        lib.mapAttrs (
          name: test:
          if lib.hasPrefix "test" name then
            test
          else
            throw "tests.${group}.${name}: nix-unit test names must start with `test`"
        )
      );
    };
  };

  config = {
    transposition.tests = { };

    flake.neusis.lib.tests = {
      inherit specialArgs fixtures;

      # home-manager config for the `alice` fixture with the given
      # modules. `pkgs` should be `testPkgs`.
      evalHm =
        { pkgs, modules }:
        (inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ fixtures.hmBase ] ++ modules;
          extraSpecialArgs = specialArgs;
        }).config;

      # nix-darwin config with the minimal fixture base.
      evalDarwin =
        {
          modules,
          system ? "aarch64-darwin",
        }:
        (inputs.darwin.lib.darwinSystem {
          inherit system specialArgs;
          modules = [ fixtures.darwinBase ] ++ modules;
        }).config;

      # NixOS config with the minimal fixture base. Pure eval, so this
      # works from a Darwin host too.
      evalNixos =
        {
          modules,
          system ? "x86_64-linux",
        }:
        (inputs.nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          modules = [
            fixtures.nixosBase
            { nixpkgs.hostPlatform = system; }
          ]
          ++ modules;
        }).config;

      # Messages of every failing `assertions` entry; `[ ]` when all hold.
      failedAssertions = cfg: map (a: a.message) (lib.filter (a: !a.assertion) cfg.assertions);

      # Sorted unique package names of a package list.
      pkgNames = pkgs: lib.sort lib.lessThan (lib.unique (map lib.getName pkgs));

      hasPkg = name: pkgs: lib.any (p: lib.getName p == name) pkgs;
    };

    perSystem =
      { pkgs, system, ... }:
      {
        _module.args.testPkgs = pkgs.appendOverlays (builtins.attrValues self.overlays);

        packages.neusis-test = pkgs.writeShellApplication {
          name = "neusis-test";
          runtimeInputs = [ pkgs.nix-unit ];
          text = ''
            # Run neusis's nix-unit suite for this system — or for
            # $NEUSIS_TEST_SYSTEM, which lets a Linux CI runner evaluate the
            # Darwin test set (pure eval, nothing is built). Extra args go
            # to nix-unit.
            #
            # nix-unit evaluates on a thread with the default stack and
            # segfaults on deep derivations (texliveFull); raise the
            # stack to the hard limit like `nix` itself does.
            ulimit -s "$(ulimit -Hs)" 2>/dev/null || true

            # nix-unit wants somewhere to park GC roots; give it a scratch dir.
            roots=$(mktemp -d)
            trap 'rm -rf "$roots"' EXIT

            # nix-unit links the evaluator only, so it does not know the
            # daemon-side settings nix-darwin writes to /etc/nix/nix.conf
            # (allowed-users, trusted-users) and warns about each. Those
            # warnings are noise for a pure-eval run; drop just them.
            status=0
            nix-unit --gc-roots-dir "$roots" --flake ".#tests.''${NEUSIS_TEST_SYSTEM:-${system}}" "$@" \
              2> >(grep -v --line-buffered -e "warning: unknown setting 'allowed-users'" \
                                           -e "warning: unknown setting 'trusted-users'" >&2) \
              || status=$?
            wait
            exit "$status"
          '';
        };
      };
  };
}
