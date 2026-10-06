{ self, ... }:
{
  flake.neusis.features.darwin.setup-keyboard =
    { ... }:
    {
      imports = [ self.darwinModules.kanata ];
      system = {
        # remap keys : Caps -> Esc
        keyboard.enableKeyMapping = true;
        keyboard.remapCapsLockToEscape = true;
      };
      neusis.services.kanata = {
        enable = true;
      };

    };
}
