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
      { inputs, outputs, ... }:
      {
        imports = [
          self.neusis.features.darwin.defaults
          # linux-builder lives here (not in darwin.defaults) so it runs
          # on rogue only, not darwin001.
          self.neusis.features.darwin.virtualization
          self.neusis.features.darwin.homebrew-defaults
          self.neusis.features.darwin.setup-keyboard
          # agenix + neusis secrets (provides the remoteBuildKey the
          # distributed-builds feature consumes).
          inputs.agenix.darwinModules.default
          inputs.agenix-rekey.darwinModules.default
          self.darwinModules.secrets
          self.neusis.features.agnostic.distributed-builds
          ./_homebrew.nix
        ];
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
