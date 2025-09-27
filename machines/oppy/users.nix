# deprecated in favour of neusisLib features
{
  pkgs,
  inputs,
  outputs,
  ...
}:
{
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

    spathak = {
      shell = pkgs.zsh;
      isNormalUser = true;
      initialPassword = "changeme";
      # passwordFile = config.age.secrets.karkinos_pass.path;
      description = "Suraj";
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
        ../../homes/spathak/id_ed25519.pub
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

      spathak = {
        imports = [
          inputs.agenix.homeManagerModules.default
          ../../homes/spathak/machines/oppy.nix
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

    };
  };
}
