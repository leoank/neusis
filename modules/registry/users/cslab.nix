{ self, ... }:
{
  flake.neusis.registry.users.cslab = {
    admins = [
      self.neusis.users.ank.neusisOS

    ];

    regulars = [
    ];

    # Locked users - accounts exist but cannot login, data preserved
    locked = [
    ];

    guests = [ ];

  };
}
