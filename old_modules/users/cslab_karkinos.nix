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
        karkinos = [
          ../homes/amunoz/machines/karkinos.nix
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
        karkinos = [
          ../homes/shsingh/machines/karkinos.nix
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
        karkinos = [
          ../homes/jfredinh/machines/karkinos.nix
        ];
      };
    }
  ];

  regulars = [
    {
      username = "yektefai";
      fullName = "Yasha Ektefaie";
      shell = "zsh";
      sshKeys = [
        ../homes/yektefai/id_ed25519.pub
      ];
      homeModules = {
        karkinos = [
          ../homes/yektefai/machines/karkinos.nix
        ];
      };
    }
    {
      username = "zhaochuj";
      fullName = "Julia Zhao";
      shell = "zsh";
      sshKeys = [
        ../homes/zhaochuj/id_ed25519.pub
      ];
      homeModules = {
        karkinos = [
          ../homes/zhaochuj/machines/karkinos.nix
        ];
      };
    }
    {
      username = "arao";
      fullName = "Arya Rao";
      shell = "zsh";
      sshKeys = [
        ../homes/arao/id_ed25519.pub
      ];
      homeModules = {
        karkinos = [
          ../homes/arao/machines/karkinos.nix
        ];
      };
    }
    {
      username = "limeliss";
      fullName = "Melissa Li";
      shell = "zsh";
      sshKeys = [
        ../homes/limeliss/id_ed25519.pub
      ];
      homeModules = {
        karkinos = [
          ../homes/limeliss/machines/karkinos.nix
        ];
      };
    }
  ];

  # Locked users - accounts exist but cannot login, data preserved
  locked = [
  ];

  guests = [ ];

}
