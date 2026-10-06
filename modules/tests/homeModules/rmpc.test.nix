# Tests for flake.homeModules.rmpc: programs.rmpc with the neusis RON
# config, parameterised by address / volumeStep / maxFps.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      rmpc =
        extra:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.rmpc
            { neusis.rmpc = { enable = true; } // extra; }
          ];
        };
      home = rmpc { };
    in
    {
      tests.hm-rmpc = {
        test-enable-writes-default-ron-config = {
          expr = {
            on = home.programs.rmpc.enable;
            address = lib.hasInfix ''address: "127.0.0.1:6600"'' home.programs.rmpc.config;
            volume = lib.hasInfix "volume_step: 5," home.programs.rmpc.config;
            fps = lib.hasInfix "max_fps: 30," home.programs.rmpc.config;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            address = true;
            volume = true;
            fps = true;
            failed = [ ];
          };
        };

        test-structured-options-substitute-into-config = {
          expr =
            let
              c =
                (rmpc {
                  address = "10.0.0.2:6600";
                  volumeStep = 10;
                  maxFps = 60;
                }).programs.rmpc.config;
            in
            lib.hasInfix ''address: "10.0.0.2:6600"'' c && lib.hasInfix "volume_step: 10," c && lib.hasInfix "max_fps: 60," c;
          expected = true;
        };

        test-full-config-override-bypasses-structured-options = {
          expr = (rmpc { config = "(address: \"x\")"; }).programs.rmpc.config;
          expected = "(address: \"x\")";
        };

        test-volume-step-is-bounded = {
          expr = (rmpc { volumeStep = 101; }).programs.rmpc.config;
          expectedError = {
            type = "ThrownError";
            msg = "volumeStep";
          };
        };

        test-disabled-leaves-rmpc-off = {
          expr =
            (t.evalHm {
              pkgs = testPkgs;
              modules = [ self.homeModules.rmpc ];
            }).programs.rmpc.enable;
          expected = false;
        };
      };
    };
}
