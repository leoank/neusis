# The flake vm-auto-update commits to its local "remote". No nixpkgs:
# `nixosConfigurations.machine` is just enough of a config for comin, a
# fake toplevel whose switch-to-configuration writes `marker` to
# /run/neusis-marker (or fails when `switch = false`). Each commit
# changes only ./state.nix. The builder is a static busybox, a `path:`
# input (substituted for @busybox@ by the test), so the build runs in
# the normal sandbox with no other store paths.
{
  inputs.busybox = {
    url = "path:@busybox@";
    flake = false;
  };

  outputs =
    { self, busybox }:
    let
      state = import ./state.nix;
      script = if state.switch then "echo ${state.marker} > /run/neusis-marker" else "exit 1";
      bb = "${busybox}/bin/busybox";
    in
    {
      nixosConfigurations.machine.config = {
        services.comin.machineId = null;
        system.build.toplevel = derivation {
          name = "fake-system-${state.marker}";
          system = "@system@";
          builder = bb;
          args = [
            "sh"
            "-c"
            ''
              ${bb} mkdir -p $out/bin
              ${bb} printf '#!/bin/sh\n%s\n' '${script}' > $out/bin/switch-to-configuration
              ${bb} chmod +x $out/bin/switch-to-configuration
            ''
          ];
        };
      };
    };
}
