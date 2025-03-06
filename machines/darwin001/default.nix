{
  config,
  pkgs,
  inputs,
  outputs,
  ...
}:
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
    ../common/darwin_home_manager.nix
    (import ../common/nix-homebrew.nix {
      inherit inputs;
      user = "kumarank";
    })
    ../common/nix.nix
    ../common/substituters.nix
  ];

  # Configure nixpkgs
  nixpkgs = {
    # You can add overlays here
    overlays = builtins.attrValues outputs.overlays;
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix.settings = {
    trusted-users = [
      "@admin"
      "kumarank"
    ];
  };

  # Create users
  users.users.kumarank = {
    description = "Ankur Kumar";
    home = "/Users/kumarank";
    createHome = true;
    isHidden = false;
    shell = pkgs.zsh;
    openssh.authorizedKeys.keyFiles = [
      ../../homes/ank/id_rsa.pub
      ../../homes/ank/id_ed25519.pub
    ];
  };

  # This is important! Removing this will break your shell and thus your system
  # This is needed even if you enable zsh in home manager
  programs.zsh.enable = true;

  # Configure homebrew
  homebrew = {
    enable = true;
    brews = [ "pixi" ]; # Example of brew
    taps = map (key: builtins.replaceStrings [ "homebrew-" ] [ "" ] key) (
      builtins.attrNames config.nix-homebrew.taps
    );
    casks = pkgs.callPackage ../common/casks.nix { };
    onActivation = {
      cleanup = "uninstall";
      autoUpdate = true;
      upgrade = true;
    };
  };

  # Configure home manager
  home-manager = {
    useGlobalPkgs = true;
    # Look into why enabling this break shell for starship
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs outputs; };
    users.kumarank = {
      imports = [
        ../../homes/ank/machines/darwin001.nix
      ];
    };
  };

  # sudo with touch id
  security.pam.enableSudoTouchIdAuth = true;
  system = {

    # remap keys : Caps -> Esc
    keyboard.enableKeyMapping = true;
    keyboard.remapCapsLockToEscape = true;

    # Disable press and hold for diacritics.
    # I want to be able to press and hold j and k
    # in vim to move around.
    defaults.NSGlobalDomain.ApplePressAndHoldEnabled = false;

    # Turn off NIX_PATH warnings now that we're using flakes
    checks.verifyNixPath = false;

    stateVersion = 4;

    #   defaults = {
    #     NSGlobalDomain = {
    #       AppleShowAllExtensions = true;
    #       ApplePressAndHoldEnabled = false;
    #
    #       # 120, 90, 60, 30, 12, 6, 2
    #       KeyRepeat = 2;
    #
    #       # 120, 94, 68, 35, 25, 15
    #       InitialKeyRepeat = 15;
    #
    #       "com.apple.mouse.tapBehavior" = 1;
    #       "com.apple.sound.beep.volume" = 0.0;
    #       "com.apple.sound.beep.feedback" = 0;
    #     };
    #
    #     dock = {
    #       autohide = true;
    #       show-recents = false;
    #       launchanim = true;
    #       orientation = "left";
    #       tilesize = 48;
    #     };
    #
    #     finder = {
    #       _FXShowPosixPathInTitle = false;
    #     };
    #
    #     trackpad = {
    #       Clicking = true;
    #       TrackpadThreeFingerDrag = true;
    #     };
    #   };

  };
}
