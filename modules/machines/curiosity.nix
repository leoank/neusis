# curiosity — bbaum-pc-7, an MSI Prestige N16 Flip AI+ (NVIDIA RTX Spark N1X, aarch64-linux),
# booted as a live disk: a GNOME ISO written to a USB stick, with ank's homes, secrets,
# tailscale and auto-updates, for working on the machine (and on neusis) from Linux.
#
# Hardware support comes from anvesana (github:leoank/anvesana): `nixosModules.n1x` (kernel,
# NVIDIA, sensor hub, audio) and `nixosModules.n1x-desktop` (refresh rate, power profiles,
# suspend, pen). What works and what does not: anvesana docs/n1x-linux.md.
#
# Live disk, so nothing on the stick survives a reboot except what comes from the SPARKDATA
# drive (the USB data drive labelled SPARKDATA, ADR-0020):
#   config/curiosity/ssh_host_ed25519_key   the host key. Copied into /etc/ssh in the initrd,
#                                           so agenix can decrypt this host's secrets at boot and
#                                           sshd/tailscale keep one identity. The public half is
#                                           `hostPubkey`; an age copy for the master identity is
#                                           in secrets/bootstrap/curiosity/.
# ank's own key stays on his machines: he connects over the tailnet with `ssh -A`, and the
# secrets ank needs here (GitHub token, rc2s2 node token) are system secrets owned by ank,
# decrypted with the host key.
# Build: nix build .#curiosity-live (aarch64-linux); write the ISO to a stick directly (not
# Ventoy). After changing secrets or this host's key: `agenix rekey` on a machine with the
# master identity.
{ self, ... }:
let
  sparkdata = "/dev/disk/by-label/SPARKDATA";
in
{
  flake-file.inputs.anvesana = {
    url = "github:leoank/anvesana";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.neusis.machines.curiosity = {
    system = "aarch64-linux";
    hostname = "curiosity";
    primaryUser = "ank";
    hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOfYdFYTNtLtHDh6fmPghuofCp3+YlzVFasqu4ydU9lT";
    modulesSpecialArgs = { inherit (self) inputs outputs; };
    userRegistries = [ self.neusis.registry.users.anklab ];
    initialHashedPassword = ../secrets/common/hashedInitialPassword.age;
    module =
      {
        inputs,
        config,
        lib,
        pkgs,
        modulesPath,
        ...
      }:
      {
        imports = [
          "${modulesPath}/installer/cd-dvd/iso-image.nix"
          inputs.anvesana.nixosModules.n1x
          inputs.anvesana.nixosModules.n1x-desktop
          self.neusis.features.agnostic.nix-settings
          self.neusis.features.agnostic.nix-pkgs
          inputs.agenix.nixosModules.default
          inputs.agenix-rekey.nixosModules.default
          self.nixosModules.secrets
          self.neusis.features.agnostic.distributed-builds
          self.nixosModules.tailscale
          self.neusis.features.agnostic.cslab_mesh
          inputs.comin.nixosModules.comin
          self.nixosModules.auto-update
          self.neusis.features.agnostic.auto-update
        ];

        # ---------------------------------------------------------------- live disk
        isoImage = {
          volumeID = "CURIOSITY";
          edition = "curiosity";
          makeEfiBootable = true;
          makeUsbBootable = true;
          appendToMenuLabel = " - curiosity";
        };
        # The firmware hides SSPM (NVDA8400) from _OSI("Windows 2022"); without it the USB and I2C
        # controllers do not probe. acpi_osi brings it back with no vendor tables involved.
        boot.kernelParams = [ ''acpi_osi="!Windows 2022"'' ];
        # NVIDIA's kernel config lacks some modules the NixOS initrd lists (as in anvesana).
        nixpkgs.overlays = [
          (final: prev: {
            makeModulesClosure = args: prev.makeModulesClosure (args // { allowMissing = true; });
          })
        ];
        boot.supportedFilesystems = [ "exfat" ];
        boot.initrd.supportedFilesystems = [ "exfat" ];

        # The host key from SPARKDATA, before switch-root: agenix installs secrets in early boot
        # (activation or sysinit), before stage 2 could mount the drive. USB storage enumerates
        # late on N1X (after power_wrap), so wait for it; without the drive the boot goes on with
        # a fresh key and no secrets.
        # (Same shape as anvesana's initrd diagnostics: a script in the initrd's /etc run by its
        # /bin/sh, with the tools it needs in initrdBin.)
        boot.initrd.systemd.contents."/etc/curiosity-host-key.sh".text = ''
          for _ in $(seq 60); do [ -e ${sparkdata} ] && break; sleep 0.5; done
          if [ ! -e ${sparkdata} ]; then echo "SPARKDATA not found; no host key"; exit 0; fi
          mkdir -p /run/sparkdata
          mount -t exfat -o ro,fmask=0077,dmask=0077 ${sparkdata} /run/sparkdata || exit 0
          k=/run/sparkdata/config/curiosity/ssh_host_ed25519_key
          if [ -f "$k" ]; then
            mkdir -p /sysroot/etc/ssh
            install -m 0600 "$k" /sysroot/etc/ssh/ssh_host_ed25519_key
            install -m 0644 "$k.pub" /sysroot/etc/ssh/ssh_host_ed25519_key.pub
            echo "host key copied"
          else
            echo "no $k"
          fi
          umount /run/sparkdata
        '';
        boot.initrd.systemd.initrdBin = [ pkgs.coreutils pkgs.util-linux ];
        boot.initrd.systemd.services.curiosity-host-key = {
          description = "Copy curiosity's SSH host key from SPARKDATA";
          wantedBy = [ "initrd.target" ];
          after = [ "sysroot.mount" ];
          before = [ "initrd-switch-root.target" "initrd-nixos-activation.service" ];
          unitConfig.DefaultDependencies = false;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "/bin/sh /etc/curiosity-host-key.sh";
          };
        };
        services.openssh = {
          enable = true;
          hostKeys = [ { path = "/etc/ssh/ssh_host_ed25519_key"; type = "ed25519"; } ];
        };

        # The data drive itself, for results and the files above; automount because N1X USB
        # enumerates late.
        fileSystems."/mnt/sparkdata" = {
          device = sparkdata;
          fsType = "exfat";
          options = [ "nofail" "x-systemd.automount" "uid=0" "gid=0" "fmask=0022" "dmask=0022" ];
        };
        # ank's secrets on curiosity are system secrets owned by ank, decrypted with the host key
        # (ank's own key never comes to this machine: he works here over ssh with agent
        # forwarding). Same rekeyFiles as ank's home bundles; `agenix rekey` encrypts them for
        # curiosity's host key.
        age.secrets.ghauthToken = {
          rekeyFile = ../secrets/ank/ghauthToken.age;
          owner = "ank";
        };
        age.secrets.rc2s2CuriosityNodeToken = {
          rekeyFile = ../secrets/ank/rc2s2CuriosityNodeToken.age;
          owner = "ank";
        };
        # neusis checked out at ~/workspace/repos/leoank/neusis (ank's bootstrap-repos list,
        # `gclb-sync`), for changing curiosity from a session on it. Cloned over https with the
        # GitHub token: git@github.com: URLs are rewritten for this run only (GIT_CONFIG_*), so
        # the remotes stay ssh and pushing works through a forwarded agent. Retries until the
        # network is up.
        systemd.user.services.neusis-checkout = {
          description = "Clone ank's repos (gclb-sync)";
          wantedBy = [ "default.target" ];
          after = [ "network-online.target" ];
          unitConfig.ConditionUser = "ank";
          serviceConfig = {
            Type = "oneshot";
            Restart = "on-failure";
            RestartSec = 120;
          };
          script = ''
            token=$(cat ${config.age.secrets.ghauthToken.path})
            export GIT_CONFIG_COUNT=1
            export GIT_CONFIG_KEY_0="url.https://x-access-token:$token@github.com/.insteadOf"
            export GIT_CONFIG_VALUE_0="git@github.com:"
            exec /etc/profiles/per-user/ank/bin/gclb-sync
          '';
        };

        # ---------------------------------------------------------------- desktop
        services.desktopManager.gnome.enable = true;
        services.displayManager.gdm.enable = true;
        services.displayManager.autoLogin = {
          enable = true;
          user = "ank";
        };
        networking.networkmanager.enable = true;
        programs.zsh.enable = true;

        # ---------------------------------------------------------------- neusis services
        age.secrets.autoUpdateNotify.rekeyFile = ../secrets/common/auto-update-notify.age;
        neusis.services.auto-update.notify.environmentFile = config.age.secrets.autoUpdateNotify.path;
        neusis.services.secrets = {
          enable = true;
          hostPubkey = self.neusis.machines.curiosity.hostPubkey;
          masterIdentities = [
            {
              # STRING path → read at `agenix rekey` time, never copied into the nix store.
              identity = "/Users/ank/.ssh/id_ed25519";
              pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH40XzfXPtcTwJ8FHxHXCaEteylFOwtuw5TaY5CZ5NS ank@leoank.me";
            }
          ];
        };

        system.stateVersion = "26.05";
      };
  };

  perSystem =
    { system, lib, ... }:
    {
      packages = lib.optionalAttrs (system == "aarch64-linux") {
        curiosity-live = self.nixosConfigurations.curiosity.config.system.build.isoImage;
      };
    };
}
