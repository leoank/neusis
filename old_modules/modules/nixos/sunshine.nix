{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.neusis.services.sunshine;
in
{
  options.neusis.services.sunshine = {
    enable = mkEnableOption "Enable Sunshine for game streaming";
  };

  config = mkIf cfg.enable {
    warnings = [
      ''
        You have enabled sunshine which needs to disable the firewall and add a
        wrapper to run sunshine as root. This is a security risk and you should
        only enable this if you know what you are doing.
      ''
    ];

    boot = {
      kernelModules = [ "uinput" ];
    };
    services = {
      udev.extraRules = ''
        KERNEL=="uinput", GROUP="input", MODE="0660" OPTIONS+="static_node=uinput"
      '';
    };

    security.wrappers.sunshine = {
      owner = "root";
      group = "root";
      capabilities = "cap_sys_admin+p";
      source = "${pkgs.sunshine}/bin/sunshine";
    };

    systemd.user.services.sunshine = {
      description = "sunshine";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${config.security.wrapperDir}/sunshine";
      };
    };

    ######################### Avahi #########################
    # services.avahi = {
    #   enable = true;
    #   reflector = true;
    #   nssmdns = true;
    #   publish = {
    #     enable = true;
    #     addresses = true;
    #     userServices = true;
    #     workstation = true;
    #   };
    # };

    ######################### Firewall #########################
    # networking.firewall = { enable = false; };
  };
}
