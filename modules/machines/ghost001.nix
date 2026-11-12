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
      { inputs, config, ... }:
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
          # saarthi hub (the saarthi flake's module) + self-hosted ntfy,
          # reachable over the tailnet.
          inputs.saarthi.nixosModules.saarthi-hub
          self.neusis.features.nixos.saarthi-hub
          # Public hostnames under leoank.me (cloudflare-leoank stack).
          self.nixosModules.cloudflare-tunnel
          # auto-updates: comin follows ghost001's deploy group (stable,
          # a day behind rogue) and testing-ghost001, deploys signed heads
          # only, and emails failures (docs/auto-update-guide.md).
          inputs.comin.nixosModules.comin
          self.nixosModules.auto-update
          self.neusis.features.agnostic.auto-update
        ];

        age.secrets.autoUpdateNotify.rekeyFile = ../secrets/common/auto-update-notify.age;
        neusis.services.auto-update.notify.environmentFile = config.age.secrets.autoUpdateNotify.path;

        programs.zsh.enable = true;

        # saarthi node (ank's saarthi-node-ghost001 bundle): a systemd user service, kept
        # running with nobody logged in. Its hub token is a system secret owned by ank,
        # decrypted with the host key (no personal key on this host).
        users.users.ank.linger = true;
        # The node's spawn root: saarthi refuses to start when a spawn root is missing.
        systemd.tmpfiles.rules = [ "d /home/ank/workspace 0755 ank users -" ];
        age.secrets.saarthiGhost001NodeToken = {
          rekeyFile = ../secrets/ank/saarthiGhost001NodeToken.age;
          owner = "ank";
        };

        # The 150 GB block volume from the `oci-anklab` stack (formatted
        # once by hand: `mkfs.ext4 -L data /dev/sdb`), for application
        # state that must survive reprovisioning. `nofail` so a missing
        # or detached volume never blocks boot.
        fileSystems."/srv" = {
          device = "/dev/disk/by-label/data";
          fsType = "ext4";
          options = [
            "nofail"
            "x-systemd.device-timeout=10s"
          ];
        };

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

        # Connector for the tunnel declared in modules/infra/cloudflare-leoank.nix
        # (remotely-managed ingress, so adding a public service never
        # touches this file). Token: `nix run .#cloudflare-leoank.terraform
        # -- output -raw tunnel_token_ghost001` → `agenix edit` → rekey.
        age.secrets.cfTunnelToken.rekeyFile = ../secrets/ank/cfTunnelGhost001.age;
        neusis.services.cloudflare-tunnel = {
          enable = true;
          tokenFile = config.age.secrets.cfTunnelToken.path;
        };

        # Release this host was created under (its base image is 26.05).
        system.stateVersion = "26.05";
      };
  };
}
