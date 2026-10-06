{
  outputs,
  inputs,
  ...
}:
{
  imports = [
    outputs.nixosModules.monitoring
    outputs.nixosModules.sunshine
    inputs.nixos-generators.nixosModules.all-formats
  ];

  # Enable monitoring
  neusis.services.monitoring.enable = true;

  # Enable ZFS auto-snapshots (retention policy defined in modules/nixos/zfs.nix)
  neusis.zfs.autoSnapshot.enable = true;

  # Add udev rules and user for IPMI device
  users.groups.ipmiusers = {
    name = "ipmiusers";
  };

  services.udev.extraRules = ''
    KERNEL=="ipmi*", MODE="0660", GROUP="ipmiusers"
  '';

  # NFS server (Oppy-specific, not in modules/nixos/zfs.nix)
  services.nfs.server.enable = true;

  # NFS exports over InfiniBand link to Spirit (192.0.2.2)
  # Shares datasets and tools for distributed computing
  # See: imaging-server-maintenance/INVENTORY.md (Inter-Server Connection)
  #
  # all_squash + anongid=1000: maps all Spirit requests to the imaging group
  # on Oppy (GID 1000). Required because AUTH_SYS sends numeric GIDs and
  # imaging is GID 30001 on Spirit vs 1000 on Oppy. Safe because the export
  # is restricted to Spirit's InfiniBand address.
  services.nfs.server.exports = ''
    /work/datasets  192.0.2.2(rw,sync,no_subtree_check,all_squash,anonuid=65534,anongid=1000)
    /work/tools     192.0.2.2(rw,sync,no_subtree_check,all_squash,anonuid=65534,anongid=1000)
  '';

  # NFSv4 id mapping domain - must match Spirit's /etc/idmapd.conf
  # Without this, UID/GID name mapping fails because Oppy has no DNS domain
  # while Spirit is broadinstitute.org
  services.nfs.idmapd.settings.General.Domain = "broadinstitute.org";

  # Enable NFSv4 name-based id mapping on the server
  # Default is Y (disabled), which sends raw numeric UIDs/GIDs over the wire.
  # With GID mismatch (imaging=1000 on Oppy, imaging=30001 on Spirit),
  # we need name mapping so "imaging" resolves correctly on both sides.
  boot.extraModprobeConfig = ''
    options nfsd nfs4_disable_idmapping=0
  '';

  services.emacs.enable = true;
}
