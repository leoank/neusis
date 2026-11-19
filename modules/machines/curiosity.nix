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
# ank's own key (the master identity) stays off this machine. curiosity has a user key of its
# own instead (curiosityUserKey, ank's ~/.ssh/id_ed25519 here): a system secret owned by ank,
# decrypted with the host key, that decrypts ank's home-manager secrets (users/ank:
# secrets-curiosity) and logs in to his other machines (it is in his registry sshKeys).
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
  # bootvine: a live tree of the systemd jobs on the boot console, in place of scrolling logs.
  flake-file.inputs.bootvine = {
    url = "git+https://codeberg.org/wvhulle/bootvine";
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
          self.neusis.features.agnostic.anklab_mesh
          inputs.comin.nixosModules.comin
          self.nixosModules.auto-update
          self.neusis.features.agnostic.auto-update
          inputs.bootvine.nixosModules.default
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
        # `quiet` keeps kernel messages off the console under bootvine (below).
        boot.kernelParams = [
          ''acpi_osi="!Windows 2022"''
          "quiet"
        ];
        # NVIDIA's kernel config lacks some modules the NixOS initrd lists (as in anvesana).
        nixpkgs.overlays = [
          (final: prev: {
            makeModulesClosure = args: prev.makeModulesClosure (args // { allowMissing = true; });
          })
        ];
        boot.supportedFilesystems = [ "exfat" ];
        boot.initrd.supportedFilesystems = [ "exfat" ];
        # supportedFilesystems.exfat only adds exfatprogs; the driver itself must be in the initrd
        # and loaded for the host-key script's mount (without it, no key and no secrets).
        boot.initrd.kernelModules = [ "exfat" ];

        # Boot screen: bootvine (systemd initrd, so it starts there) instead of kernel messages.
        services.bootvine.enable = true;

        # The host key from SPARKDATA, before switch-root: agenix installs secrets in early boot
        # (activation or sysinit), before stage 2 could mount the drive. USB storage enumerates
        # late on N1X (after power_wrap), so wait for it; without the drive the boot goes on with
        # a fresh key and no secrets.
        # Without the key the boot stops in the initrd's emergency shell, with the reason on the
        # console: a boot with a fresh key decrypts no secret, so ank has no password (sudo
        # fails), no home secrets and a new SSH identity, which is worse than not booting.
        # Plug SPARKDATA in and reboot, or boot anyway by adding `curiosity.nohostkey` to the
        # kernel command line (e in the boot menu).
        # (Same shape as anvesana's initrd diagnostics: a script in the initrd's /etc run by its
        # /bin/sh; seq, install and mount come from the default coreutils and util-linux-minimal.)
        boot.initrd.systemd.contents."/etc/curiosity-host-key.sh".text = ''
          fail() {
            echo "curiosity: $1. No host key, so no secrets: no password, no home secrets."
            echo "curiosity: plug in SPARKDATA and reboot, or boot with curiosity.nohostkey."
            for p in $(cat /proc/cmdline); do
              if [ "$p" = curiosity.nohostkey ]; then echo "curiosity.nohostkey: booting anyway"; exit 0; fi
            done
            exit 1
          }
          for _ in $(seq 60); do [ -e ${sparkdata} ] && break; sleep 0.5; done
          [ -e ${sparkdata} ] || fail "SPARKDATA not found"
          mkdir -p /run/sparkdata
          mount -t exfat -o ro,fmask=0077,dmask=0077 ${sparkdata} /run/sparkdata || fail "SPARKDATA did not mount"
          k=/run/sparkdata/config/curiosity/ssh_host_ed25519_key
          if [ -f "$k" ]; then
            mkdir -p /sysroot/etc/ssh
            install -m 0600 "$k" /sysroot/etc/ssh/ssh_host_ed25519_key
            install -m 0644 "$k.pub" /sysroot/etc/ssh/ssh_host_ed25519_key.pub
            echo "host key copied"
            umount /run/sparkdata
          else
            umount /run/sparkdata
            fail "no $k on SPARKDATA"
          fi
        '';
        boot.initrd.systemd.services.curiosity-host-key = {
          description = "Copy curiosity's SSH host key from SPARKDATA";
          # Required by and ordered before initrd.target, so its failure fails that target, whose
          # OnFailure is the emergency shell.
          requiredBy = [ "initrd.target" ];
          after = [ "sysroot.mount" ];
          before = [
            "initrd.target"
            "initrd-switch-root.target"
            "initrd-nixos-activation.service"
          ];
          unitConfig.DefaultDependencies = false;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "/bin/sh /etc/curiosity-host-key.sh";
            StandardOutput = "journal+console";
          };
        };
        # Keys only: ank comes in with `ssh -A` over the tailnet, and port 22 is open on whatever
        # network the laptop joins.
        services.openssh = {
          enable = true;
          hostKeys = [ { path = "/etc/ssh/ssh_host_ed25519_key"; type = "ed25519"; } ];
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
          };
        };

        # The data drive itself, for results and the files above; automount because N1X USB
        # enumerates late. Root only (0077): the drive holds the host key, which decrypts every
        # secret of this host, so no other user or service may read it.
        fileSystems."/mnt/sparkdata" = {
          device = sparkdata;
          fsType = "exfat";
          options = [ "nofail" "x-systemd.automount" "uid=0" "gid=0" "fmask=0077" "dmask=0077" ];
        };
        # ank's user key here, the one system secret his home needs: ~/.ssh/id_ed25519 links to it
        # (users/ank: secrets-curiosity), so it decrypts his home-manager secrets (GitHub, atuin and
        # saarthi tokens, the signing and GitHub keys) and logs him in to his other machines.
        age.secrets.curiosityUserKey = {
          rekeyFile = ../secrets/ank/curiosityUserKey.age;
          owner = "ank";
          generator.script = self.neusis.lib.agenixGenerators.sshKey "ank@curiosity";
        };
        # GitHub's published host key, so the first `git@github.com` connection does not prompt.
        programs.ssh.knownHosts."github.com".publicKey =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        # A builder for the others (registry/builders/anklab.nix), but its own builds stay here:
        # Nix sends a derivation to any remote with a free slot before building locally, and its
        # only aarch64-linux peer is ghost001's two slow slots.
        neusis.services.build-client.enable = lib.mkForce false;

        # The kernel's -dev output (headers and build tree) on the image: an out-of-tree
        # module (nvidia-open, spi-hid, n1x-lps0) needs it to build, and no cache holds
        # this kernel, so without it a driver bump on a fresh live boot recompiled the
        # whole kernel to get -dev back (2026-11-19, nvidia-open 615 -> 620).
        system.extraDependencies = [ config.boot.kernelPackages.kernel.dev ];

        # A live disk joins tailscale as a new device on every boot: the previous one, now
        # offline, is deleted rather than kept as curiosity-old-<timestamp>.
        neusis.services.tailscale.profiles.runxi.deleteOfflineConflicts = true;
        neusis.services.tailscale.profiles.shntnu.deleteOfflineConflicts = true;

        # ---------------------------------------------------------------- desktop
        services.desktopManager.gnome.enable = true;
        services.displayManager.gdm.enable = true;
        services.displayManager.autoLogin = {
          enable = true;
          user = "ank";
        };
        # rogue's wallpaper (ank's theming bundle; stylix's gnome target is off, so set it here).
        services.desktopManager.gnome.extraGSettingsOverrides =
          let
            wallpaper = "file://${../users/ank/_assets/wallpaper.jpg}";
          in
          ''
            [org.gnome.desktop.background]
            picture-uri='${wallpaper}'
            picture-uri-dark='${wallpaper}'

            [org.gnome.desktop.screensaver]
            picture-uri='${wallpaper}'
          '';
        networking.networkmanager.enable = true;
        programs.zsh.enable = true;
        # Accounts and passwords come from the config at every activation: with mutable users, a
        # password that failed to decrypt at boot (an ISO older than its secrets) stays locked even
        # after a deploy that decrypts it. Nothing here outlives a reboot anyway; revisit for the
        # full install.
        users.mutableUsers = false;

        # ---------------------------------------------------------------- neusis services
        age.secrets.autoUpdateNotify.rekeyFile = ../secrets/common/auto-update-notify.age;
        neusis.services.auto-update.notify.environmentFile = config.age.secrets.autoUpdateNotify.path;
        # comin here also deploys heads signed on curiosity (pushed to testing-curiosity); added to
        # the registry signers, which are all every other host trusts. CI promotes only heads the
        # registry signers signed, so deploy/live never moves to a commit signed here.
        neusis.services.auto-update.signers = [
          {
            principal = "ank@leoank.me";
            key = lib.concatStringsSep " " (
              lib.take 2 (lib.splitString " " (lib.fileContents ../secrets/ank/curiositySigningKey.pub))
            );
          }
        ];
        neusis.services.secrets = {
          enable = true;
          hostPubkey = self.neusis.machines.curiosity.hostPubkey;
          storageBaseDir = ../secrets/rekeyed;
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
      # legacyPackages, not packages: every package is a `pkg-*` check, and CI must not build
      # the ISO (its deploy group has `ci = false`). `nix build .#curiosity-live` finds it here.
      legacyPackages = lib.optionalAttrs (system == "aarch64-linux") {
        curiosity-live = self.nixosConfigurations.curiosity.config.system.build.isoImage;
      };
    };
}
