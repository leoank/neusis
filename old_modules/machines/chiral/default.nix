# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  # You can import other NixOS modules here
  imports = [
    # include NixOS-WSL modules
    inputs.nixos-wsl.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.agenix.nixosModules.default
    {
      age.identityPaths = [ "/home/ank/.ssh/id_ed25519" ];
    }

    # You can also split up your configuration and import pieces of it here:
    ../common/substituters.nix
    ../common/input_device.nix
    ../common/ssh.nix
    ../common/us_eng.nix
    ../common/nix.nix
  ];

  # Hardware config
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # WSL Config
  wsl = {
    enable = true;
    defaultUser = "ank";
    useWindowsDriver = true;
    docker-desktop = {
      enable = true;
    };
  };

  # FHS
  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld;
  };

  # NVidia and cuda support

  hardware = {
    # nvidia prop drivers
    nvidia.open = false;
    # Enable graphics (formerly OpenGL)
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        libva-vdpau-driver
      ];
    };

    # Enable nvidia container
    nvidia-container-toolkit.enable = true;
  };

  # Nvidia and Cuda support
  services.xserver.videoDrivers = [ "nvidia" ];

  nixpkgs = {
    # You can add overlays here
    overlays = builtins.attrValues outputs.overlays;
    # Configure your nixpkgs instance
    config = {
      cudaSupport = true;
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  # disable nix channel
  nix.channel.enable = false;
  nix.settings = {
    # Enable flakes and new 'nix' command
    experimental-features = "nix-command flakes";
    # Deduplicate and optimize nix store
    auto-optimise-store = true;
  };

  # Default system wide packages
  environment.systemPackages = with pkgs; [
    vim
    dive
    podman-tui
    inputs.agenix.packages.x86_64-linux.default
    home-manager
  ];

  environment.shells = [ pkgs.zsh ];
  programs.zsh.enable = true;

  # Networking
  networking.hostName = "chiral";
  # networking.bridges.br0.interfaces = [ "enp2s0" "wlp131s0" ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
