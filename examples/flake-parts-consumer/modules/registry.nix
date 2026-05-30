{ self, ... }:
{
  # Group users by role under a lab name. Entries reference the
  # typed `flake.neusis.users.<u>.neusisOS` attrsets defined elsewhere, so
  # adding a user is a one-line edit here once they're declared.
  flake.neusis.registry.users.myLab = {
    admins = [
      self.flake.neusis.users.alice.neusisOS
    ];
  };
}
