{ ... }:
{

  flake.neusis.features.darwin.virtualization =
    { ... }:
    {

      nix.linux-builder = {
        enable = true;
        ephemeral = true;
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        supportedFeatures = [
          "kvm"
          "benchmark"
          "big-parallel"
          "nixos-test"
        ];
        maxJobs = 8;
        config = {
          boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
          nix.settings.sandbox = false;
          virtualisation = {
            darwin-builder = {
              diskSize = 80 * 1024;
              memorySize = 24 * 1024;
            };
            cores = 8;
          };
        };
      };

      launchd.daemons.linux-builder = {
        serviceConfig = {
          StandardOutPath = "/var/log/linux-builder.log";
          StandardErrorPath = "/var/log/linux-builder.log";
        };
      };

      # trusted-users is set (dynamically, from config.system.primaryUser)
      # by the shared `agnostic.nix-settings` default feature — no need to
      # repeat it here.
    };
}
