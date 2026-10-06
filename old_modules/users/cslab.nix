{ ... }:
{
  admins = [
    {
      username = "ank";
      fullName = "Ankur Kumar";
      shell = "zsh";
      sshKeys = [
        ../homes/ank/id_rsa.pub
        ../homes/ank/id_ed25519.pub
        ../homes/ank/id2_ed25519.pub
      ];
      homeModules = {
        oppy = [
          ../homes/ank/machines/oppy.nix
        ];
        karkinos = [
          ../homes/ank/machines/karkinos.nix
        ];
      };
    }
    {
      username = "amunoz";
      fullName = "Alan";
      shell = "fish";
      sshKeys = [
        ../homes/amunoz/id_ed25519.pub
      ];
      homeModules = {
        oppy = [
          ../homes/amunoz/machines/oppy.nix
        ];
      };
    }
    {
      username = "shsingh";
      fullName = "Shantanu";
      shell = "zsh";
      sshKeys = [
        ../homes/shsingh/id_ed25519.pub
      ];
      homeModules = {
        oppy = [
          ../homes/shsingh/machines/oppy.nix
        ];
      };
    }
  ];

  regulars = [
    {
      username = "spathak";
      fullName = "Suraj";
      shell = "zsh";
      sshKeys = [
        ../homes/spathak/id_ed25519.pub
      ];
      homeModules = {
        oppy = [
          ../homes/spathak/machines/oppy.nix
        ];
      };
    }
    {
      username = "jewald";
      fullName = "Jess";
      shell = "zsh";
      sshKeys = [
        ../homes/jewald/id_ed25519.pub
      ];
      homeModules = {
        oppy = [
          ../homes/jewald/machines/oppy.nix
        ];
      };
    }
    {
      username = "rshen";
      fullName = "Runxi";
      shell = "zsh";
      sshKeys = [
        ../homes/rshen/id_ed25519.pub
      ];
      homeModules = {
        oppy = [
          ../homes/rshen/machines/oppy.nix
        ];
      };
    }
    {
      username = "jfredinh";
      fullName = "Johan";
      shell = "zsh";
      sshKeys = [
        ../homes/jfredinh/id_ed25519.pub
      ];
      homeModules = {
        oppy = [
          ../homes/jfredinh/machines/oppy.nix
        ];
      };
    }
    {
      username = "jrietdij";
      fullName = "Jonne Rietdijk";
      shell = "zsh";
      sshKeys = [
        ../homes/jrietdij/id_ed25519.pub
      ];
      homeModules = {
        oppy = [
          ../homes/jrietdij/machines/oppy.nix
        ];
      };
    }
  ];

  # Locked users - accounts exist but cannot login, data preserved
  locked = [
    {
      username = "ngogober";
      fullName = "Nodar";
      shell = "bash"; # Will be overridden to nologin by mkLocked
      sshKeys = [
        ../homes/ngogober/id_ed25519.pub
      ];
      homeModules = {
        oppy = [
          ../homes/ngogober/machines/oppy.nix
        ];
      };
    }
  ];

  guests = [ ];

}
