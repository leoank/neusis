{ ... }:
{
  # Define each user via the typed `flake.neusis.users.<name>.neusisOS`
  # schema imported from `inputs.neusis.flakeModules.default`. Fields default
  # sensibly (e.g. `username` defaults to the attribute name), so you
  # only need to set what differs.
  flake.neusis.users.alice.neusisOS = {
    fullName = "Alice Example";
    shell = "zsh";
    sshKeys = [
      # Replace with a real public key path before building.
      ../keys/alice.pub
    ];
    # Which home-manager modules this user gets on which host.
    machineToBundlesMap.myhost = [ ../homes/alice/myhost.nix ];
  };
}
