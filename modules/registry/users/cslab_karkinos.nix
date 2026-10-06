{ self, ... }:
{

  flake.neusis.registry.users.cslab_karkinos = {
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
