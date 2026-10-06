# Shared test fixtures. Imported by path from ../harness.nix (import-tree
# skips `_`-prefixed directories, so nothing here is a flake-parts module).
{
  self,
  lib,
  inputs,
}:
rec {
  # ---- Base modules: the minimum each evaluator needs to pass its own
  # assertions, mirroring what the real builders inject.

  hmBase =
    { pkgs, ... }:
    {
      home.username = "alice";
      home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/alice" else "/home/alice";
      home.stateVersion = "25.11";
    };

  # No hostName here: the system builders set it with mkDefault and a
  # plain value in the base would shadow them.
  darwinBase = {
    system.stateVersion = 5;
    system.primaryUser = "alice";
  };

  nixosBase = {
    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };
    boot.loader.grub.enable = false;
    system.stateVersion = "25.11";
  };

  # What a real NixOS host with login users carries: agenix (for the
  # initial-password secret), openssh (agenix's identity paths) and the
  # zsh program (users with a zsh login shell).
  nixosLogin = {
    imports = [
      nixosBase
      inputs.agenix.nixosModules.default
    ];
    services.openssh.enable = true;
    programs.zsh.enable = true;
  };

  # ---- A fake user and registry in the shape of flake.neusis.users.* /
  # flake.neusis.registry.users.*.

  alice = {
    username = "alice";
    fullName = "Alice Fixture";
    shell = "zsh";
    sshKeys = [ ];
    machineToBundlesMap = {
      fixture = [ aliceBundle ];
      fixture-darwin = [ aliceBundle ];
    };
  };

  aliceBundle =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.hello ];
    };

  bob = {
    username = "bob";
    fullName = "Bob Fixture";
    shell = "bash";
    sshKeys = [ ];
    machineToBundlesMap = { };
  };

  lab = {
    admins = [ alice ];
    regulars = [ bob ];
    guests = [ ];
    locked = [ ];
  };

  # Minimal enabled supercharged-git umbrella (home-manager). Tool tests
  # add `neusis.supercharged-git.tools.<x>.enable = true` on top.
  gitIdentity = {
    neusis.supercharged-git = {
      enable = true;
      userName = "Alice Fixture";
      userEmail = "alice@example.com";
    };
  };

  # Fake host key, used for `hostPubkey` fields.
  hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA fixture";

  # ---- Machines in the shape of flake.neusis.machines.* — every field
  # the option type would default is spelled out, because
  # `mkNeusisFlake` reads them all off the attrset directly.

  machines = {
    fixture = {
      hostname = "fixture";
      computerName = null;
      system = "x86_64-linux";
      nixpkgs = null;
      primaryUser = null;
      modulesSpecialArgs = { };
      inherit hostPubkey;
      userRegistries = [ lab ];
      initialHashedPassword = ./placeholder.age;
      module = nixosLogin;
    };

    fixture-darwin = {
      hostname = "fixture-darwin";
      computerName = "Fixture Mac";
      system = "aarch64-darwin";
      nixpkgs = null;
      primaryUser = "alice";
      modulesSpecialArgs = { };
      inherit hostPubkey;
      userRegistries = [ lab ];
      initialHashedPassword = null;
      module = {
        system.stateVersion = 5;
      };
    };
  };

  # ---- Remote builders in the shape of flake.neusis.registry.builders.*.

  builders = [
    {
      hostName = "fixture";
      sshUser = "nixremote";
      systems = [ "x86_64-linux" ];
      maxJobs = 4;
      speedFactor = 1;
      supportedFeatures = [ "big-parallel" ];
      mandatoryFeatures = [ ];
      inherit hostPubkey;
    }
    {
      hostName = "other-builder";
      sshUser = "nixremote";
      systems = [ "aarch64-linux" ];
      maxJobs = 8;
      speedFactor = 2;
      supportedFeatures = [ "kvm" ];
      mandatoryFeatures = [ ];
      inherit hostPubkey;
    }
  ];
}
