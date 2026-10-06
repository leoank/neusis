# T1/T2: expose the flake's own packages as `checks.<system>.pkg-<name>`
# so `nix flake check` builds them. The flake-file writers and the test
# runner are plumbing, not products, and are left out.
{ lib, ... }:
{
  perSystem =
    { config, ... }:
    let
      plumbing = [
        "write-flake"
        "write-inputs"
        "write-lock"
        "neusis-test"
      ];
    in
    {
      checks = lib.mapAttrs' (n: p: lib.nameValuePair "pkg-${n}" p) (
        lib.filterAttrs (n: _: !(builtins.elem n plumbing)) config.packages
      );
    };
}
