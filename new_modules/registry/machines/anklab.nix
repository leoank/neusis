{ self, ... }:
{
  flake.neusis.registry.machines.anklab = {
    darwin = [
      self.neusis.machines.rogue
      self.neusis.machines.darwin001
    ];
  };
}
