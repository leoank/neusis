# Registry for darwin001 — single admin user `kumarank` (the same
# person as `ank` on other hosts, just with a different system
# username forced by macOS's existing account). Separate from
# `anklab` so `ank` doesn't get created on darwin001 and
# `kumarank` doesn't get created on rogue.
{ self, ... }:
{
  flake.neusis.registry.users.kumaranklab = {
    admins = [
      self.neusis.users.kumarank.neusisOS
    ];

    regulars = [ ];
    guests = [ ];
  };
}
