{
  self,
  ...
}:
{

  flake.neusis.machines.rogue = {
    system = "aarch64-darwin";
    hostname = "rogue";
    computerName = "rogue";
    primaryUser = "ank";
    hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBtQhksag38KPkx/EIXH2d5L6yoMrLfsmpMJHtjOXjw0";
    modulesSpecialArgs = { inherit (self) inputs outputs; };
    userRegistries = [ self.neusis.registry.users.anklab ];
    module =
      { config, inputs, outputs, ... }:
      {
        imports = [
          self.neusis.features.darwin.defaults
          self.neusis.features.darwin.setup-keyboard
          # agenix + neusis secrets (provides the remoteBuildKey the
          # distributed-builds feature consumes).
          inputs.agenix.darwinModules.default
          inputs.agenix-rekey.darwinModules.default
          self.darwinModules.secrets
          self.neusis.features.agnostic.distributed-builds
          # tailscale mesh: the agnostic tailscale module (daemon +
          # autoconnect) + the two mesh config features (ank = leoank default,
          # cslab switchable).
          self.darwinModules.tailscale
          # self.neusis.features.agnostic.ank_mesh
          # self.neusis.features.agnostic.cslab_mesh
          ./_homebrew.nix
          # auto-updates: comin follows rogue's deploy group (canary),
          # deploys signed heads only, and emails failures
          # (docs/auto-update-spec.md).
          inputs.comin.darwinModules.comin
          self.darwinModules.auto-update
          self.neusis.features.agnostic.auto-update
        ];
        age.secrets.autoUpdateNotify.rekeyFile = ../secrets/common/auto-update-notify.age;
        neusis.services.auto-update.notify.environmentFile = config.age.secrets.autoUpdateNotify.path;
        programs.zsh.enable = true;
        neusis.services.secrets = {
          enable = true;
          hostPubkey = self.neusis.machines.rogue.hostPubkey;
          masterIdentities = [
            {
              # STRING path → read at `agenix rekey` time, never copied
              # into the nix store.
              identity = "/Users/ank/.ssh/id_ed25519";
              pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH40XzfXPtcTwJ8FHxHXCaEteylFOwtuw5TaY5CZ5NS ank@leoank.me";
            }
          ];
        };
      };
  };
}
