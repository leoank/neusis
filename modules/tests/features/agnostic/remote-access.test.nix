# Tests for flake.neusis.features.agnostic.remote-access: ssh + eternal
# terminal daemons on both platforms.
{ self, ... }:
{
  perSystem =
    { ... }:
    let
      t = self.neusis.lib.tests;
      feature = self.neusis.features.agnostic.remote-access;
      summary = cfg: {
        ssh = cfg.services.openssh.enable;
        et = cfg.services.eternal-terminal.enable;
        failed = t.failedAssertions cfg;
      };
      expected = {
        ssh = true;
        et = true;
        failed = [ ];
      };
    in
    {
      tests.feature-remote-access = {
        test-darwin = {
          expr = summary (t.evalDarwin { modules = [ feature ]; });
          inherit expected;
        };
        test-nixos = {
          expr = summary (t.evalNixos { modules = [ feature ]; });
          inherit expected;
        };
      };
    };
}
