{ self, ... }:
{
  # Creating home manager feature bundles
  # hmBundles can be named anything and need not match one to one with a machine
  flake.neusis.users.ank.hmBundles.agent-harness =
    { ... }:
    {
      imports = [
        self.homeModules.msgvault-sync
        self.homeModules.qmd-reindex
      ];

    };

  # Configuring user for neusisOS
  flake.neusis.users.ank.neusisOS = {
    username = "ank";
    fullName = "Ankur Kumar";
    shell = "zsh";
    # These keys will be used for configuring - git, ssh, secrets ...
    sshKeys = [
      ./id_rsa.pub
      ./id_ed25519.pub
      ./id2_ed25519.pub
    ];
    # Mapping hm feature bundles to machines
    machineToBundlesMap = {
      rogue = [
        self.neusis.features.agnostic.nix-pkgs
        self.neusis.users.ank.hmBundles.agent-harness
        ./_packages.nix
        # enable home manager program
        # add terminals
        # add kalam
        # add themes
        # add browsers
        # add editors
        # add tmux config
        # add agent harness
        # add zsh
        # add git module
        # add mpd module
        # add rmpc
        # add hammerspoon

      ];
    };
  };
}
