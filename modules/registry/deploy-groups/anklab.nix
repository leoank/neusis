# Auto-update deploy groups for anklab (docs/auto-update-spec.md §4).
#
# A group's machines follow `deploy/<group>`, which CI fast-forwards to a
# commit on main once the shared gates and the group's own builds pass.
# `stable` only receives commits `canary` has run for `soakHours`.
# rogue, the machine watched most closely, is the canary; the server
# ghost001 only gets what rogue has run for a day.
# Membership here does not enroll a host: the machine also imports the
# auto-update feature, which looks its group up in this registry.
{ self, ... }:
let
  m = self.neusis.machines;
in
{
  flake.neusis.registry.deployGroups.anklab = {
    canary = {
      machines = [ m.rogue ];
    };
    stable = {
      machines = [ m.ghost001 ];
      after = "canary";
      soakHours = 24;
    };
  };
}
