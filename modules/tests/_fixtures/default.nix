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

  darwinBase = {
    system.stateVersion = 5;
    system.primaryUser = "alice";
    networking.hostName = "fixture-darwin";
  };

  nixosBase = {
    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };
    boot.loader.grub.enable = false;
    system.stateVersion = "25.11";
    networking.hostName = "fixture";
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

  # Fake host key, used for `hostPubkey` fields.
  hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA fixture";

  # ---- Machines in the shape of flake.neusis.machines.*.

  machines = {
    fixture = {
      hostname = "fixture";
      system = "x86_64-linux";
      inherit hostPubkey;
      userRegistries = [ lab ];
      initialHashedPassword = ./placeholder.age;
      module = {
        imports = [
          nixosBase
          inputs.agenix.nixosModules.default
        ];
      };
    };

    fixture-darwin = {
      hostname = "fixture-darwin";
      computerName = "Fixture Mac";
      system = "aarch64-darwin";
      primaryUser = "alice";
      inherit hostPubkey;
      userRegistries = [ lab ];
      module = darwinBase;
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
