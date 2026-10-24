# ghost001 — first cloud host: an Oracle Cloud Ampere A1 (aarch64-linux)
# NixOS machine for self-hosted apps, also a low-priority aarch64 builder.
# Provisioned by the `oci-anklab` terranix stack (modules/infra/) from the
# shared base image, then switched to this config by `neusis cloud
# bootstrap ghost001` — see docs/cloud-terranix-spec.md §5.
#
# The host key was generated ahead of time: the private half lives
# encrypted to the master identity under modules/secrets/bootstrap/ghost001/
# (pushed at bootstrap), the public half is `hostPubkey` here, so
# `agenix rekey` can prepare this host's secrets before it exists.
{ self, ... }:
{
  flake.neusis.machines.ghost001 = {
    system = "aarch64-linux";
    hostname = "ghost001";
    primaryUser = "ank";
    hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMzyOInpVSdaUDBuBYYo1xATP3MshY+cl7qa1mIhq8mM";
    modulesSpecialArgs = { inherit (self) inputs outputs; };
    userRegistries = [ self.neusis.registry.users.anklab ];
    initialHashedPassword = ../secrets/common/hashedInitialPassword.age;
    module =
      { inputs, ... }:
      {
        imports = [
          # OCI hardware profile — the same one the base image boots with.
          self.neusis.features.nixos.oci-guest
          self.neusis.features.agnostic.nix-settings
          self.neusis.features.agnostic.nix-pkgs
          # agenix + neusis secrets (remoteBuildKey for distributed
          # builds, the tailscale credentials via cslab_mesh).
          inputs.agenix.nixosModules.default
          inputs.agenix-rekey.nixosModules.default
          self.nixosModules.secrets
          self.neusis.features.agnostic.distributed-builds
          # cslab tailnet (the one ank's machines currently use).
          self.nixosModules.tailscale
          self.neusis.features.agnostic.cslab_mesh
        ];

        programs.zsh.enable = true;

        neusis.services.secrets = {
          enable = true;
          hostPubkey = self.neusis.machines.ghost001.hostPubkey;
          masterIdentities = [
            {
              # STRING path → read at `agenix rekey` time, never copied
              # into the nix store.
              identity = "/Users/ank/.ssh/id_ed25519";
              pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH40XzfXPtcTwJ8FHxHXCaEteylFOwtuw5TaY5CZ5NS ank@leoank.me";
            }
          ];
        };

        # Release this host was created under (its base image is 26.05).
        system.stateVersion = "26.05";
      };
  };
}
