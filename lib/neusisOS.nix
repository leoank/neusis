# NixOS user management utilities for the Neusis system
#
# This module provides functions for creating and managing different types of users
# (admins, regular users, guests) and integrating them with Home Manager.
{
  lib,
  inputs,
  ...
}@args:
rec {

  # Expose the top-level arguments for debugging purposes
  showTopArgs = args;

  # Concatenate all user types into a single list
  concatAllUsers = userConfig: with userConfig; admins ++ regulars ++ guests;

  # Merge all top level user configs into a single user config
  mergeUserConfigs =
    userConfigList:
    builtins.foldl'
      (acc: userConfig: {
        admins = acc.admins ++ userConfig.admins;
        regulars = acc.regulars ++ userConfig.regulars;
        guests = acc.guests ++ userConfig.guests;
      })
      {
        admins = [ ];
        regulars = [ ];
        guests = [ ];
      }
      userConfigList;

  # Create a Home Manager user configuration
  mkHomeManagerUser = machineName: userConfig: {
    home-manager.users.${userConfig.username}.imports =
      if (builtins.hasAttr machineName userConfig.homeModules) then
        userConfig.homeModules.${machineName}
      else
        [ ];
  };

  # Create an admin user with elevated privileges
  mkAdmin =
    adminConfig:
    (
      { config, ... }:
      {
        users.users.${adminConfig.username} = {
          isNormalUser = true;
          shell = adminConfig.shell;
          hashedPasswordFile = config.age.secrets.commonInitialHashedPassword.path;
          description = adminConfig.fullName;
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
          openssh.authorizedKeys.keyFiles = adminConfig.sshKeys;
        };

      }
    );

  # Create a regular user with standard privileges
  mkRegular =
    regularConfig:
    (
      { config, ... }:
      {
        users.users.${regularConfig.username} = {
          isNormalUser = true;
          shell = regularConfig.shell;
          hashedPasswordFile = config.age.secrets.commonInitialHashedPassword.path;
          description = regularConfig.fullName;
          extraGroups = [
            "libvirtd"
            "qemu-libvirtd"
            "input"
            "podman"
            "docker"
          ];
          openssh.authorizedKeys.keyFiles = regularConfig.sshKeys;
        };

      }
    );

  # Create a guest user with minimal privileges
  mkGuest =
    guestConfig:
    (
      { config, ... }:
      {
        users.users.${guestConfig.username} = {
          isNormalUser = true;
          shell = guestConfig.shell;
          hashedPasswordFile = config.age.secrets.commonInitialHashedPassword.path;
          description = guestConfig.fullName;
          extraGroups = [
            "input"
            "podman"
            "docker"
          ];
          openssh.authorizedKeys.keyFiles = guestConfig.sshKeys;
        };

      }
    );

  # Dynamically create all user types based on configuration
  mkDynamicUsers =
    {
      machineName,
      userConfig,
      homeManager ? false,
    }:
    let
      # Create admin accounts
      admins = builtins.map mkAdmin userConfig.admins;
      # Create regular user accounts
      regulars = builtins.map mkRegular userConfig.regulars;
      # Create guest accounts
      guests = builtins.map mkGuest userConfig.guests;

      # Create Home Manager user configurations if enabled
      homeManagerUsers = lib.optionals homeManager (
        builtins.map (user: mkHomeManagerUser machineName user) (concatAllUsers userConfig)
      );
    in
    admins ++ regulars ++ guests ++ homeManagerUsers;

  # Main function to create a NixOS system configuration with user management
  mkNeusisOS =
    {
      machineName,
      userModule,
      specialArgs ? { },
      userConfig ? null,
      homeManager ? false,
      initialHashedPassword ? ../secrets/common/hashedInitialPassword.age,
    }:
    let
      ageConfig = {
        age.secrets.commonInitialHashedPassword.file = initialHashedPassword;
      };
      userConfigModules = lib.optionals (userConfig != null) (mkDynamicUsers {
        inherit
          machineName
          userConfig
          homeManager
          ;
      });
      homeManagerModules = lib.optionals homeManager [
        {
          home-manager = {
            backupFileExtension = "bak";
            extraSpecialArgs = specialArgs;
          };
        }
      ];
    in
    lib.nixosSystem {
      modules = [
        userModule
        ageConfig
      ]
      ++ userConfigModules
      ++ homeManagerModules;
      inherit specialArgs;
    };

  # Main function to create a Darwin NixOS system configuration with user management
  mkNeusisDarwinOS =
    {
      machineName,
      userModule,
      specialArgs ? { },
      userConfig ? null,
      homeManager ? false,
      system ? "aarch64-darwin",
    }:
    let
      userConfigModules = lib.optionals (userConfig != null) (mkDynamicUsers {
        inherit machineName userConfig homeManager;
      });
      homeManagerModules = lib.optionals homeManager [
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "bak";
            extraSpecialArgs = specialArgs;
          };
        }
      ];
    in
    inputs.darwin.lib.darwinSystem {
      inherit system;
      modules = [ userModule ] ++ userConfigModules ++ homeManagerModules;
      inherit specialArgs;
    };

  # Create flake homeManagerConfigurations for all the given users and machines combinations
  mkHomeConfigurations =
    {
      machinesRegistry,
      userConfig,
      specialArgs ? { },
    }:
    let
      # userList
      allUsers = (concatAllUsers userConfig);

      #
      userAndMachineSet' =
        user:
        builtins.map (machine: {
          name = user.username + "@" + machine;
          value = user.homeModules.${machine};
        }) (builtins.attrNames user.homeModules);

      # {user@machine = moduleList;}
      userAndMachineSet = builtins.listToAttrs (
        lib.lists.flatten ((builtins.map (user: userAndMachineSet' user) allUsers))
      );
    in
    builtins.mapAttrs (name: value: 
      inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = machinesRegistry.${lib.last (lib.strings.splitString "@" name)};
        extraSpecialArgs = specialArgs;
        modules = value;
      }
    ) userAndMachineSet;
}
