{ ... }:
{
  # Define each user via the typed `flake.users.<name>.neusisOS`
  # schema imported from `inputs.neusis.flakeModules.default`. Fields
  # default sensibly (e.g. `username` defaults to the attribute name),
  # so you only need to set what differs.
  flake.neusis.users.alice.neusisOS = {
    fullName = "Alice Example";
    shell = "zsh";
    sshKeys = [
      # Replace with a real public key path before building.
      ../keys/alice.pub
    ];
    homeModules.myhost = [ ../homes/alice/myhost.nix ];
  };
}
