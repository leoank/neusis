{ self, ... }:
{
  flake.neusis.registry.users.anklab = {
    admins = [
      self.neusis.users.ank.neusisOS
    ];

    regulars = [ ];
    guests = [ ];
  };
}
