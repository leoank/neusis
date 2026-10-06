{
  pkgs,
  ...
}:
{

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.autoSuspend = false;
  services.desktopManager.gnome.enable = true;

  # Prevent GNOME from attempting idle suspend on a shared server
  # (nosleep.nix masks the systemd targets, but gsd-power still sends a
  # misleading "The system will suspend now!" broadcast before logind refuses)
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.settings-daemon.plugins.power]
    sleep-inactive-ac-type='nothing'
    sleep-inactive-battery-type='nothing'
  '';

  # ollama needs imaging group to traverse /work (0750 root:imaging)
  users.users.ollama = {
    isSystemUser = true;
    group = "ollama";
    extraGroups = [ "imaging" ];
  };
  users.groups.ollama = {};

  # enable ollama
  services.ollama = {
    enable = true;
    package = pkgs.unstable.ollama;
    acceleration = "cuda";
    models = "/work/tools/ollama";
    host = "0.0.0.0";
    port = 11434;
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "262144";
    };
  };

  nixpkgs.config.sunshine.cudaSupport = true;

  # Karkinos-specific packages (base packages in common/system.nix)
  environment.systemPackages = with pkgs; [
    unstable.ollama
    gnomeExtensions.forge
    gnomeExtensions.blur-my-shell
    gnomeExtensions.burn-my-windows
    gnomeExtensions.appindicator
    gnomeExtensions.unite
  ];

}
