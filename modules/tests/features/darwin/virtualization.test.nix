# Tests for flake.neusis.features.darwin.virtualization: the ephemeral
# linux-builder VM (rogue only) and its log file.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      cfg = t.evalDarwin { modules = [ self.neusis.features.darwin.virtualization ]; };
      lb = cfg.nix.linux-builder;
    in
    {
      tests.feature-darwin-virtualization = {
        test-linux-builder-vm = {
          expr = {
            on = lb.enable;
            ephemeral = lb.ephemeral;
            systems = lb.systems;
            features = lb.supportedFeatures;
            maxJobs = lb.maxJobs;
            log = cfg.launchd.daemons.linux-builder.serviceConfig.StandardOutPath;
            failed = t.failedAssertions cfg;
          };
          expected = {
            on = true;
            ephemeral = true;
            systems = [
              "x86_64-linux"
              "aarch64-linux"
            ];
            features = [
              "kvm"
              "benchmark"
              "big-parallel"
              "nixos-test"
            ];
            maxJobs = 8;
            log = "/var/log/linux-builder.log";
            failed = [ ];
          };
        };

        test-vm-config-emulates-x86-and-is-sized = {
          expr =
            let
              # `lb.config` is a deferred module; the evaluated VM config is
              # exposed by the builder package.
              vm = lb.package.nixosConfig;
            in
            {
              binfmt = vm.boot.binfmt.emulatedSystems;
              sandbox = vm.nix.settings.sandbox;
              cores = vm.virtualisation.cores;
              disk = vm.virtualisation.darwin-builder.diskSize;
              memory = vm.virtualisation.darwin-builder.memorySize;
            };
          expected = {
            binfmt = [ "x86_64-linux" ];
            sandbox = false;
            cores = 8;
            disk = 80 * 1024;
            memory = 24 * 1024;
          };
        };
      };
    };
}
