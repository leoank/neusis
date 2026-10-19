{ self, ... }:
{
  flake.neusis.registry.machines.anklab = {
    darwin = [
      self.neusis.machines.rogue
      self.neusis.machines.darwin001
    ];
    nixos = [
      self.neusis.machines.ghost001
    ];
  };
}
