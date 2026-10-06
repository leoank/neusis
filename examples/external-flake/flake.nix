{
  description = "Example consumer flake using neusis for system & user management.";

  # This example uses a plain (non-flake-parts) consumer. The user and
  # registry values are untyped attrsets in the shape neusis expects — no
  # schema validation, no per-attribute merging. If you want the typed
  # `flake.neusis.users.<u>.neusisOS` / `flake.neusis.registry` schema and
  # merging across files, see the sibling `examples/flake-parts-consumer/`
  # which imports `inputs.neusis.flakeModules.default`.

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    # Pin neusis. In a real consumer this would be:
    #   neusis.url = "github:leoank/neusis";
    # Here we point at the local checkout so the example tracks the
    # current state of the repo.
    neusis.url = "path:../..";

    # neusis already pulls home-manager and flake-parts, but it's
    # idiomatic to follow them so versions stay consistent.
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      neusis,
      home-manager,
      ...
    }:
    let
      inherit (neusis.neusis.lib.neusisOS) mkNeusisOS;

      # A user, in the shape of `flake.neusis.users.<name>.neusisOS`:
      # `username`, `fullName`, `shell`, `sshKeys`, and the
      # `machineToBundlesMap` that picks this user's home-manager modules
      # per host.
      alice = {
        username = "alice";
        fullName = "Alice Example";
        shell = "zsh";
        sshKeys = [
          # Replace with a real public key before building.
          ./keys/alice.pub
        ];
        machineToBundlesMap.myhost = [ ./homes/alice/myhost.nix ];
      };

      # A per-lab user registry — same shape as
      # `flake.neusis.registry.users.<lab>`: users grouped by role.
      myLab = {
        admins = [ alice ];
        regulars = [ ];
        locked = [ ];
        guests = [ ];
      };
    in
    {
      # Smoke test for the neusis lib import path. Verify with:
      #   nix eval .#hello
      hello = neusis.neusis.lib.utils.helloWorld "alice";

      nixosConfigurations.myhost = mkNeusisOS {
        machineName = "myhost";

        # The machine module: hardware-configuration, platform, boot,
        # networking, etc. Anything you'd normally pass to nixosSystem.
        # neusis seeds every login account's password from an agenix
        # secret, so the host needs the agenix module.
        userModule = {
          imports = [
            ./machine.nix
            neusis.inputs.agenix.nixosModules.default
          ];
        };

        # Passed through to the machine modules and to home-manager's
        # `extraSpecialArgs` (on top of `inputs` / `outputs`).
        specialArgs = { inherit self nixpkgs home-manager; };

        # Creates the system accounts for every user in these registries
        # and wires up home-manager for them automatically.
        userRegistries = [ myLab ];

        # Required whenever a host has login (non-locked) users. Point it
        # at your own agenix secret — neusis deliberately has no default.
        initialHashedPassword = ./secrets/hashedInitialPassword.age;
      };
    };
}
