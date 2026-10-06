{ self, ... }:
{
  flake.neusis.features.darwin.defaults =
    { ... }:
    {
      imports = [
        self.neusis.features.darwin.system-defaults
        self.neusis.features.darwin.nix-homebrew
        self.neusis.features.darwin.theme
        self.neusis.features.agnostic.nix-settings
        self.neusis.features.agnostic.nix-pkgs
        self.neusis.features.agnostic.remote-access
      ];
    };
}
