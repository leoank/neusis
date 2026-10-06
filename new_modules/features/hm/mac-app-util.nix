{ inputs, ... }:
{
  flake-file.inputs = {
    mac-app-util = {
      url = "github:hraban/mac-app-util";
    };
  };
  flake.neusis.features.hm.mac-app-util =
    { ... }:
    {
      imports = [
        inputs.mac-app-util.homeManagerModules.default
      ];
    };
}
