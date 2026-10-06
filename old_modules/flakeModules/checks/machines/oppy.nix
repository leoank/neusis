{
  self,
  lib,
  pkgs,
  ...
}:
{
  perSystem =
    {
      config,
      pkgs,
      inputs',
      self',
      ...
    }:
    {
      checks = {
        # FIXME: This passes but find a way to add creds for tailscale to work
        oppy_test = pkgs.testers.runNixOSTest {
          name = "oppy-test";
          nodes.oppy.imports = self.nixosConfigurations.oppy._module.args.modules;
          node.specialArgs = { inherit (self) inputs outputs; };
          node.pkgsReadOnly = false;

          testScript = builtins.readFile ./oppy_test.py;
        };
      };
    };
}
