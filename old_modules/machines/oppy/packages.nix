{
  pkgs,
  ...
}:
{
  # Oppy-specific packages (base packages in common/system.nix)
  environment.systemPackages = with pkgs; [
    ipmitool
  ];
}
