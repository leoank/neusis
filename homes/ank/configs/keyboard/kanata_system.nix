# adapted from https://github.com/nix-darwin/nix-darwin/blob/7ebf95a73e3b54e0f9c48f50fde29e96257417ac/modules/services/karabiner-elements/default.nix
{ lib, pkgs, ... }:
let
  parentAppDir = "/Applications/.Nix-Karabiner";
in
{
  environment.systemPackages = [ pkgs.kanata ];

  system.activationScripts.preActivation.text = ''
    rm -rf ${parentAppDir}
    mkdir -p ${parentAppDir}
    # Kernel extensions must reside inside of /Applications, they cannot be symlinks
    cp -r ${pkgs.karabiner-elements.driver}/Applications/.Karabiner-VirtualHIDDevice-Manager.app ${parentAppDir}
  '';

  # activate extension
  launchd.user.agents.activate_karabiner_system_ext = {
    serviceConfig.ProgramArguments = [
      "${parentAppDir}/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
      "activate"
    ];
    serviceConfig.RunAtLoad = true;
  };

  launchd.daemons.Karabiner-DriverKit-VirtualHIDDevice-Daemon = {
    command = "\"${pkgs.kanata.passthru.darwinDriver}/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon\"";
    serviceConfig.ProcessType = "Interactive";
    serviceConfig.Label = "org.pqrs.Karabiner-DriverKit-VirtualHIDDevice-Daemon";
    serviceConfig.KeepAlive = true;
  };

  launchd.daemons.kanata = {
    # also need to add kanata binary to System Settings -> Privacy & Security -> Input Monitoring
    command = "${lib.getExe pkgs.kanata} --cfg ${toString ./custom.kbd}";
    serviceConfig.ProcessType = "Interactive";
    serviceConfig.Label = "org.nixos.kanata";
    serviceConfig.KeepAlive = true;
  };
}
