{
  config,
  lib,
  ...
}:
{

  virtualisation.vmVariantWithDisko = {
    # Create ephemeral tailscale connections with custom vm hostName
    neusis.tailscale = lib.mkForce {
      isPersistent = false;
      hostName = "diskoTest${config.networking.hostName}";
    };

    virtualisation.qemu.options = [
      "-nographic"
      "-virtfs local,path=$TESTVM_SECRETS,mount_tag=hostSecrets,security_model=none"
    ];

    age.identityPaths = [ "/mnt/secrets/etc/ssh/ssh_host_ed25519_key" ];

    boot.initrd.postMountCommands = ''
      echo "[mountVmSecrets] Creating /mnt/secrets/"
      mkdir -p $targetRoot/mnt/secrets
      echo "[mountVmSecrets] Mounting virtio hostSecrets to /mnt/secrets/"
      mount -t 9p -o trans=virtio,access=any,version=9p2000.L hostSecrets $targetRoot/mnt/secrets
    '';

    # For running VM on macos: https://www.tweag.io/blog/2023-02-09-nixos-vm-on-macos/
    # virtualisation.host.pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin;
  };
}
