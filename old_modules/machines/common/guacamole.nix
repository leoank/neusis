{pkgs, ...}:{

  environment.systemPackages = with pkgs; [gnome.gnome-remote-desktop];
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "gnome-session";
  services.xrdp.openFirewall = true;
  services.gnome.gnome-remote-desktop.enable = true;


  # Guacamole
  services.guacamole-server = {
    enable = true;
    host = "127.0.0.1";
    userMappingXml = ./guacamole-user-mapping.xml;
    package = pkgs.guacamole-server; # Optional, use only when you want to use the unstable channel
  };

  services.guacamole-client = {
    enable = true;
    enableWebserver = true;
    settings = {
      guacd-port = 4822;
      guacd-hostname = "127.0.0.1";
    };
    package = pkgs.guacamole-client; # Optional, use only when you want to use the unstable channel
  };
}
