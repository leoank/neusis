{
  self,
  lib,
  inputs,
  ...
}:
let
  # ---- Private helpers (not exposed in flake.neusis.lib.neusisOS) ----

  # Role catalogue. Each entry's `extraGroups` is the Linux-only group
  # set the role grants; `locked = true` marks the role as a no-login
  # account. Darwin ignores both — see `mkUser`.
  roleSpecs = {
    admin = {
      extraGroups = [
        "networkmanager"
        "wheel"
        "libvirtd"
        "qemu-libvirtd"
        "input"
        "podman"
        "docker"
        "ipmiusers"
      ];
    };
    regular = {
      extraGroups = [
        "libvirtd"
        "qemu-libvirtd"
        "input"
        "podman"
        "docker"
      ];
    };
    guest = {
      extraGroups = [
        "input"
        "podman"
        "docker"
      ];
    };
    locked = {
      extraGroups = [ "input" ];
      locked = true;
    };
  };

  # Stable role iteration order. The plural form ("admins", "regulars",
  # …) is the key under which a registry stores users of that role.
  roleOrder = [
    "admin"
    "regular"
    "guest"
    "locked"
  ];
  pluralOf = role: role + "s";

  # Pick the nixpkgs source for a machine. `null` ⇒ flake-wide default.
  chooseNixpkgs = nixpkgs: if nixpkgs != null then nixpkgs else inputs.nixpkgs;

  # Build one `users.users.<name>` module for a (role, user) pair.
  # Cross-platform fields stay unconditional; Linux-only fields are
  # gated on `pkgs.stdenv.isDarwin`.
  mkUser =
    role: userConfig:
    let
      spec = roleSpecs.${role};
      isLocked = spec.locked or false;
    in
    { config, pkgs, ... }:
    {
      users.users.${userConfig.username} = {
        description = userConfig.fullName;
        openssh.authorizedKeys.keyFiles = userConfig.sshKeys;
        shell =
          if isLocked then
            (if pkgs.stdenv.isDarwin then "/usr/bin/false" else "${pkgs.shadow}/bin/nologin")
          else
            pkgs.${userConfig.shell};
      }
      # nix-darwin doesn't default `users.users.<name>.home`, so
      # home-manager's `home.homeDirectory` ends up `null`. Seed it
      # to `/Users/<name>` on Darwin (NixOS already defaults to
      # `/home/<name>`).
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        home = "/Users/${userConfig.username}";
      }
      // lib.optionalAttrs (!pkgs.stdenv.isDarwin) (
        {
          isNormalUser = true;
          extraGroups = spec.extraGroups;
        }
        // (
          if isLocked then
            { hashedPassword = "!"; } # locked: cannot authenticate
          else
            { hashedPasswordFile = config.age.secrets.commonInitialHashedPassword.path; }
        )
      );
    };

  # Build the NixOS user account modules for every (role, user) pair
  # across the given registries, in `roleOrder`.
  mkUserAccountModules =
    userRegistries:
    lib.concatMap (
      role: map (mkUser role) (lib.concatMap (r: r.${pluralOf role} or [ ]) userRegistries)
    ) roleOrder;

  # The home-manager wiring modules for one system. Returns the
  # platform-correct home-manager flake module, the agnostic
  # `hm-system-init` re-export, and its enable+config. Empty list when
  # there are no user registries (nothing to wire).
  mkHmInitModules =
    {
      platform,
      userRegistries,
    }:
    let
      isDarwin = platform == "darwin";
    in
    lib.optionals (userRegistries != [ ]) [
      (
        if isDarwin then
          inputs.home-manager.darwinModules.home-manager
        else
          inputs.home-manager.nixosModules.home-manager
      )
      (if isDarwin then self.darwinModules.hm-system-init else self.nixosModules.hm-system-init)
      {
        neusis.services.hm-system-init = {
          enable = true;
          inherit userRegistries;
        };
        home-manager = {
          backupFileExtension = "bak";
        }
        // lib.optionalAttrs isDarwin { useUserPackages = true; };
      }
    ];

  # The specialArgs every system module sees. `inputs`/`outputs` are
  # always provided; the caller's `specialArgs` overrides on conflict.
  mkSpecialArgs =
    specialArgs:
    {
      inherit inputs;
      outputs = self;
    }
    // specialArgs;

  # `pkgs` for a host's standalone home-manager build. Honours the
  # machine's `nixpkgs` override when set, falling back to the
  # flake-wide `inputs.nixpkgs` otherwise.
  pkgsFor =
    machine:
    import (chooseNixpkgs machine.nixpkgs) {
      inherit (machine) system;
      config.allowUnfree = true;
    };
in
{
  flake.neusis.lib.neusisOS = rec {

    # ---- Registry helpers ----

    # Flatten one registry's role lists into a single user list.
    concatAllUsers = registry: lib.concatMap (role: registry.${pluralOf role} or [ ]) roleOrder;

    # Merge a list of registries into one by concatenating each role's
    # list across them. Output keys are the same as the input registry
    # keys (`admins`, `regulars`, …).
    mergeUserConfigs =
      registries:
      lib.genAttrs (map pluralOf roleOrder) (key: lib.concatMap (r: r.${key} or [ ]) registries);

    # ---- Per-role user builders ----
    # Thin aliases over `mkUser` for callers that want a role-named
    # entry point. Equivalent to `mkUser "admin"` etc.
    mkAdmin = mkUser "admin";
    mkRegular = mkUser "regular";
    mkGuest = mkUser "guest";
    mkLocked = mkUser "locked";

    # Build all user account modules from a list of registries.
    mkDynamicUsers = mkUserAccountModules;

    # ---- System builders ----

    # NixOS system with neusis-managed users. home-manager wiring is
    # pulled in automatically whenever `userRegistries` is non-empty.
    mkNeusisOS =
      {
        machineName,
        computerName ? null,
        userModule,
        specialArgs ? { },
        userRegistries ? [ ],
        system ? "x86_64-linux",
        # Optional per-machine nixpkgs override. `null` falls back to
        # the flake-wide `inputs.nixpkgs`.
        nixpkgs ? null,
        # Accepted for signature parity with `mkNeusisDarwinOS` so
        # `mkNeusisFlake` can forward `machine.primaryUser` uniformly.
        # Currently a no-op on NixOS (no canonical "primary user"
        # option); declare it freely on machines and read it back via
        # `machine.primaryUser` if you wire it yourself.
        primaryUser ? null,
        initialHashedPassword ? ../secrets/common/hashedInitialPassword.age,
      }:
      (chooseNixpkgs nixpkgs).lib.nixosSystem {
        specialArgs = mkSpecialArgs specialArgs;
        modules = [
          userModule
          { age.secrets.commonInitialHashedPassword.file = initialHashedPassword; }
          {
            nixpkgs.hostPlatform = lib.mkDefault system;
            networking.hostName = lib.mkDefault machineName;
          }
        ]
        ++ mkUserAccountModules userRegistries
        ++ mkHmInitModules {
          platform = "nixos";
          inherit userRegistries;
        };
      };

    # nix-darwin system with neusis-managed users. home-manager wiring
    # is pulled in automatically whenever `userRegistries` is non-empty.
    mkNeusisDarwinOS =
      {
        machineName,
        computerName ? null,
        userModule,
        specialArgs ? { },
        userRegistries ? [ ],
        system ? "aarch64-darwin",
        # Accepted for signature parity with `mkNeusisOS` so
        # `mkNeusisFlake` can forward `machine.nixpkgs` uniformly.
        # Must be `null` on Darwin — nix-darwin's nixpkgs is wired via
        # the `darwin` input's `nixpkgs.follows`.
        nixpkgs ? null,
        # Per-machine primary user. When set, wires through to
        # nix-darwin's `system.primaryUser`. Read it from any module
        # downstream via `config.system.primaryUser`.
        primaryUser ? null,
      }:
      assert lib.assertMsg (nixpkgs == null) ''
        mkNeusisDarwinOS: per-machine `nixpkgs` overrides aren't supported on Darwin.
        Machine "${machineName}" set `nixpkgs` to a non-null value. nix-darwin's
        nixpkgs is determined by the `darwin` flake input's `nixpkgs.follows`.
        Declare a second `darwin` input (e.g. `darwin-unstable`) and route the
        machine there.'';
      inputs.darwin.lib.darwinSystem {
        inherit system;
        specialArgs = mkSpecialArgs specialArgs;
        modules = [
          userModule
          (
            {
              networking.hostName = lib.mkDefault machineName;
              networking.computerName = lib.mkDefault computerName;
            }
            // lib.optionalAttrs (primaryUser != null) {
              system.primaryUser = lib.mkDefault primaryUser;
            }
          )
        ]
        ++ mkUserAccountModules userRegistries
        ++ mkHmInitModules {
          platform = "darwin";
          inherit userRegistries;
        };
      };

    # ---- Top-level flake outputs builder ----

    # Build `{ nixosConfigurations, darwinConfigurations,
    # homeConfigurations }` from a registry of machines.
    # `homeConfigurations` are keyed `<username>@<hostname>` and
    # produced for every (user, host) pair where the user has a
    # `machineToBundlesMap.<hostname>` entry.
    mkNeusisFlake =
      {
        machineRegistries,
      }:
      let
        machinesIn = key: lib.concatMap (r: r.${key}) (lib.attrValues machineRegistries);
        nixosMachines = machinesIn "nixos";
        darwinMachines = machinesIn "darwin";

        mkSystemPair =
          builder: machine:
          lib.nameValuePair machine.hostname (builder {
            machineName = machine.hostname;
            userModule = machine.module;
            inherit (machine)
              userRegistries
              system
              nixpkgs
              primaryUser
              computerName
              ;
            specialArgs = machine.modulesSpecialArgs;
          });

        nixosConfigurations = builtins.listToAttrs (map (mkSystemPair mkNeusisOS) nixosMachines);
        darwinConfigurations = builtins.listToAttrs (map (mkSystemPair mkNeusisDarwinOS) darwinMachines);

        # `<user>@<host> = <hmConfig>` for every user with a
        # `machineToBundlesMap` entry on this host.
        hmPairsFor =
          machine:
          lib.concatMap (
            user:
            lib.optional (user.machineToBundlesMap ? ${machine.hostname}) (
              lib.nameValuePair "${user.username}@${machine.hostname}" (
                inputs.home-manager.lib.homeManagerConfiguration {
                  pkgs = pkgsFor machine;
                  modules = user.machineToBundlesMap.${machine.hostname};
                  extraSpecialArgs = mkSpecialArgs { };
                }
              )
            )
          ) (lib.concatMap concatAllUsers machine.userRegistries);

        homeConfigurations = builtins.listToAttrs (
          lib.concatMap hmPairsFor (nixosMachines ++ darwinMachines)
        );
      in
      {
        inherit nixosConfigurations darwinConfigurations homeConfigurations;
      };
  };
}
