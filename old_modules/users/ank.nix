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
        chiral = [
          ../homes/ank/machines/chiral.nix
        ];
        rogue = [
          ../homes/ank/machines/rogue.nix
        ];
        darwin001 = [
          ../homes/ank/machines/darwin001.nix
        ];
      };
    }
  ];

  regulars = [ ];
  guests = [ ];
}
