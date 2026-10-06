{
  description = "Example consumer flake using neusis for system & user management.";

  # This example uses a plain (non-flake-parts) consumer. The user config
  # is an untyped attrset — no schema validation, no per-attribute merging.
  # If you want the typed `flake.users.<u>.neusisOS` / `flake.registry`
  # schema and per-attribute merging across files, see the sibling
  # `examples/flake-parts-consumer/` which imports
  # `inputs.neusis.flakeModules.default`.

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Pin neusis. In a real consumer this would be:
    #   neusis.url = "github:leoank/neusis";
    # Here we point at the local checkout so the example tracks the
    # current state of the repo.
    neusis.url = "path:../..";

    # neusis already pulls home-manager and flake-parts, but it's
    # idiomatic to follow them so versions stay consistent.
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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

      # Per-lab user config — same shape as `flake.registry.users.<lab>`
      # from neusis. Each user matches the `userConfigType` schema:
      # `username`, `fullName`, `shell`, `sshKeys`, `homeModules.<host>`.
      myLab = {
        admins = [
          {
            username = "alice";
            fullName = "Alice Example";
            shell = "zsh";
            sshKeys = [
              # Replace with a real public key path before building.
              ./keys/alice.pub
            ];
            homeModules.myhost = [ ./homes/alice/myhost.nix ];
          }
        ];
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
        userModule = ./machine.nix;

        # Passed through to home-manager's `extraSpecialArgs`, and also
        # available to the machine module if it wants `inputs` etc.
        specialArgs = { inherit self nixpkgs home-manager; };

        userConfig = myLab;
        homeManager = true;

        # The lib's default points at a path inside the neusis repo
        # that a consumer can't decrypt. Always override with your own
        # agenix secret.
        initialHashedPassword = ./secrets/hashedInitialPassword.age;
      };
    };
}
