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
    # If you want to use modules from other flakes (such as nixos-hardware):
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.home-manager.nixosModule

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix

    # Disko configuration
    inputs.disko.nixosModules.disko
    ./disko.nix
    # Path to make boot work with zstore pool
    ./filesystem.nix
    # common zfs configs
    ../common/zfs.nix

    # You can also split up your configuration and import pieces of it here:
    ../common/networking.nix
    ../common/gpu/nvidia_dc.nix
    ../common/substituters.nix
    ../common/virtualization.nix
    ../common/input_device.nix
    ../common/ssh.nix
    ../common/us_eng.nix
    ../common/nosleep.nix
    ../common/nix.nix
    ../common/printing.nix
    ../common/bootloader_systemd.nix

    # oppy networking config
    #./network.nix
  ];

  # FHS
  programs.nix-ld.enable = true;
  # Required for nvidia dc drivers
  services.xserver.enable = false;

  nixpkgs = {
    # You can add overlays here
    overlays = builtins.attrValues outputs.overlays;
    # Configure your nixpkgs instance
    config = {
      sunshine = {
        cudaSupport = true;
      };
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  # This will add each flake input as a registry
  # To make nix3 commands consistent with your flake
  nix.registry = (lib.mapAttrs (_: flake: { inherit flake; })) (
    (lib.filterAttrs (_: lib.isType "flake")) inputs
  );

  # This will additionally add your inputs to the system's legacy channels
  # Making legacy nix commands consistent as well, awesome!
  nix.nixPath = [ "/etc/nix/path" ];
  environment.etc = lib.mapAttrs' (name: value: {
    name = "nix/path/${name}";
    value.source = value.flake;
  }) config.nix.registry;

  # Default system wide packages
  environment.systemPackages = with pkgs; [
    vim
    dive
    podman-tui
  ];
  environment.shells = [ pkgs.zsh ];
  programs.zsh.enable = true;
  programs.fish.enable = true;

  # Networking
  networking.hostName = "oppy";

  networking.hostId = "2e39dfae"; # The primary use case is to ensure when using ZFS that a pool isn’t imported accidentally on a wrong machine.
  # networking.bridges.br0.interfaces = [ "enp2s0" "wlp131s0" ];
  services.tailscale.enable = true;
  users.users = {

    # Define a user account. Don't forget to set a password with ‘passwd’.
    ank = {
      shell = pkgs.zsh;
      isNormalUser = true;
      initialPassword = "changeme";
      # passwordFile = config.age.secrets.karkinos_pass.path;
      description = "Ankur Kumar";
      extraGroups = [
        "networkmanager"
        "wheel"
        "libvirtd"
        "qemu-libvirtd"
        "input"
        "podman"
        "docker"
      ];
      openssh.authorizedKeys.keyFiles = [
        ../../homes/ank/id_rsa.pub
        ../../homes/ank/id_ed25519.pub
        ../../homes/ank/id2_ed25519.pub
      ];
    };

    amunoz = {
      shell = pkgs.fish;
      isNormalUser = true;
      initialPassword = "changeme";
      # passwordFile = config.age.secrets.karkinos_pass.path;
      description = "Alan";
      extraGroups = [
        "networkmanager"
        "wheel"
        "libvirtd"
        "qemu-libvirtd"
        "input"
        "podman"
        "docker"
      ];
      openssh.authorizedKeys.keyFiles = [
        ../../homes/amunoz/id_ed25519.pub
      ];
    };

    ngogober = {
      shell = pkgs.zsh;
      isNormalUser = true;
      initialPassword = "changeme";
      # passwordFile = config.age.secrets.karkinos_pass.path;
      description = "Nodar";
      extraGroups = [
        "networkmanager"
        "wheel"
        "libvirtd"
        "qemu-libvirtd"
        "input"
        "podman"
        "docker"
      ];
      openssh.authorizedKeys.keyFiles = [
        ../../homes/ngogober/id_ed25519.pub
      ];
    };

    jarevalo = {
      shell = pkgs.bash;
      isNormalUser = true;
      initialPassword = "changeme";
      # passwordFile = config.age.secrets.karkinos_pass.path;
      description = "John";
      extraGroups = [
        "networkmanager"
        "wheel"
        "libvirtd"
        "qemu-libvirtd"
        "input"
        "podman"
        "docker"
      ];
      openssh.authorizedKeys.keyFiles = [
        ../../homes/jarevalo/id_ed25519.pub
      ];
    };

    shsingh = {
      shell = pkgs.bash;
      isNormalUser = true;
      initialPassword = "changeme";
      # passwordFile = config.age.secrets.karkinos_pass.path;
      description = "Shantanu";
      extraGroups = [
        "networkmanager"
        "wheel"
        "libvirtd"
        "qemu-libvirtd"
        "input"
        "podman"
        "docker"
      ];
      openssh.authorizedKeys.keyFiles = [
        ../../homes/shsingh/id_ed25519.pub
      ];
    };

    jewald = {
      shell = pkgs.bash;
      isNormalUser = true;
      initialPassword = "changeme";
      # passwordFile = config.age.secrets.karkinos_pass.path;
      description = "Jess";
      extraGroups = [
        "networkmanager"
        "wheel"
        "libvirtd"
        "qemu-libvirtd"
        "input"
        "podman"
        "docker"
      ];
      openssh.authorizedKeys.keyFiles = [
        ../../homes/jewald/id_ed25519.pub
      ];
    };

    rshen = {
      shell = pkgs.bash;
      isNormalUser = true;
      initialPassword = "changeme";
      # passwordFile = config.age.secrets.karkinos_pass.path;
      description = "Runxi";
      extraGroups = [
        "networkmanager"
        "wheel"
        "libvirtd"
        "qemu-libvirtd"
        "input"
        "podman"
        "docker"
      ];
      openssh.authorizedKeys.keyFiles = [
        ../../homes/rshen/id_ed25519.pub
      ];
    };

    jfredinh = {
      shell = pkgs.bash;
      isNormalUser = true;
      initialPassword = "changeme";
      # passwordFile = config.age.secrets.karkinos_pass.path;
      description = "Johan";
      extraGroups = [
        "networkmanager"
        "wheel"
        "libvirtd"
        "qemu-libvirtd"
        "input"
        "podman"
        "docker"
      ];
      openssh.authorizedKeys.keyFiles = [
        ../../homes/jfredinh/id_ed25519.pub
      ];
    };

    akalinin = {
      shell = pkgs.bash;
      isNormalUser = true;
      initialPassword = "changeme";
      # passwordFile = config.age.secrets.karkinos_pass.path;
      description = "Alex";
      extraGroups = [
        "networkmanager"
        "wheel"
        "libvirtd"
        "qemu-libvirtd"
        "input"
        "podman"
        "docker"
      ];
      openssh.authorizedKeys.keyFiles = [
        ../../homes/akalinin/id_ed25519.pub
      ];
    };

  };

  home-manager = {

    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
    extraSpecialArgs = { inherit inputs outputs; };

    # Enable home-manager for users
    users = {
      ank = {
        imports = [
          inputs.agenix.homeManagerModules.default
          ../../homes/ank/machines/oppy.nix
        ];
      };
      amunoz = {
        imports = [
          inputs.agenix.homeManagerModules.default
          ../../homes/amunoz/machines/oppy.nix
        ];
      };
      ngogober = {
        imports = [
          inputs.agenix.homeManagerModules.default
          ../../homes/ngogober/machines/oppy.nix
        ];
      };
      jarevalo = {
        imports = [
          inputs.agenix.homeManagerModules.default
          ../../homes/jarevalo/machines/oppy.nix
        ];
      };

      shsingh = {
        imports = [
          inputs.agenix.homeManagerModules.default
          ../../homes/shsingh/machines/oppy.nix
        ];
      };

      jewald = {
        imports = [
          inputs.agenix.homeManagerModules.default
          ../../homes/jewald/machines/oppy.nix
        ];
      };

      rshen = {
        imports = [
          inputs.agenix.homeManagerModules.default
          ../../homes/rshen/machines/oppy.nix
        ];
      };

      jfredinh = {
        imports = [
          inputs.agenix.homeManagerModules.default
          ../../homes/jfredinh/machines/oppy.nix
        ];
      };

      akalinin = {
        imports = [
          inputs.agenix.homeManagerModules.default
          ../../homes/akalinin/machines/oppy.nix
        ];
      };
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.11";
}
