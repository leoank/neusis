{ ... }:
{
  flake.neusis.features.agnostic.remote-access =
    { outputs, ... }:
    {

      # Enable various ssh servers
      services.openssh.enable = true;
      services.eternal-terminal.enable = true;

    };
}
