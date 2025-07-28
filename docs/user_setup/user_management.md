# Adding new users

This document outlines the process for system administrators to add new users to the Neusis environment. It describes the end-to-end workflow from user PR submission to account activation, including required configuration changes across machine-specific files. Followzing these instructions will ensure proper user access management, permission configuration, and home directory setup across the system. This guide assumes familiarity with NixOS configuration principles and the Neusis repository structure.

## Workflow Overview

1. Users request access by submitting a PR that creates their home configuration (as described in `getting_started.md`)
2. Administrators review the PR and then add the user to specific machines
3. The system rebuild applies the user's configuration to their home directory on approved machines

## Administrator Actions

As an administrator, you will respond to user PRs by adding their user account to specific machines they should have access to. This requires updating two sections in the machine-specific configuration file.

### Step 1: Add User Account

In the file `machines/<machine_name>/default.nx`, under the `users.users` key, add a user dictionary with the key corresponding to the name of the folder in `homes/` that the user created in their PR.

The easiest way is to copy an existing user, and paste it, changing the name as necessary.

Here is an example:

```
users.users = {

    # ... existing users ...

    <some_user> = {
      shell = pkgs.zsh;
      isNormalUser = true;
      initialPassword = "changeme";
      # passwordFile = config.age.secrets.karkinos_pass.path;
      description = "<name of user>";
      extraGroups = [
        "networkmanager"
        "wheel"
        "libvirtd"
        "qemu-libvirtd"
        "input"
        "podman"
        "docker"
      ];
      openssh.authorizedKeys.keyFiles = [
        ../../homes/<some_user>/id_ed25519.pub
      ];
    };
}
```

The key, `<some_user>`, must match the name of the directory in `homes/` created by the user in their PR.

### Step 2: Link Home Manager Configuration

In the same file, locate the `home-manager.users` section and add an entry for the user that imports their machine-specific configuration:

```
home-manager = {
    users = {

        # ... existing users ...

        <some_user> = {
            imports = [
              inputs.agenix.homeManagerModules.default
              ../../homes/<some_user>/machines/<machine_name>.nix
            ];
        };
    }
}
```

This links to the user's home configuration for this specific machine, which was provided in their PR.

## Important Notes

- Users cannot add themselves to machines - this is strictly an administrator task
- You decide which machines each user should have access to
- The user's home configuration will be applied during the next system rebuild

