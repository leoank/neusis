# Every flake.agnosticModules.<name> must be reachable as both
# self.nixosModules.<name> and self.darwinModules.<name>.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      agnostic = builtins.attrNames self.agnosticModules;
    in
    {
      tests.agnostic-re-export-all = {
        test-agnostic-module-set = {
          expr = agnostic;
          expected = [
            "build-client"
            "build-server"
            "hm-system-init"
            "kanata"
            "secrets"
            "tailscale"
          ];
        };

        test-re-exported-to-nixos-and-darwin = {
          expr = {
            nixos = lib.all (n: self.nixosModules ? ${n}) agnostic;
            darwin = lib.all (n: self.darwinModules ? ${n}) agnostic;
          };
          expected = {
            nixos = true;
            darwin = true;
          };
        };
      };
    };
}
