# Adding new users

In the file `machines/<machine_name>/default.nx`, under the `users.users` key, add a user dictionary with the key corresponding to the name of a folder in `homes/`, where `<machine_name>` is e.g. `spirit`, `oppy`, etc.

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
```

The key, `<some_user>`, would need to be replaced with the name of a directory in `homes/`, and `<name of user>` is the human name of the user.

Then in `home-manager.users`, create a user dictionary with the key again maching the name of a directory in `homes/`. The dictionary should be customized for the user preferences, per machine (e.g. `oppy`, `spirit`, etc.).

Here is an example:

```
home-manager = {
    users = {

        # ... existing users ...

        <some_user> = {
            imports = [
              inputs.agenix.homeManagerModules.default
              ../../homes/ngogober/machines/oppy.nix
            ];
        };
    }
}

