{
  self,
  ...
}:
{
  perSystem =
    {
      system,
      ...
    }:
    let
      npkgs = import self.inputs.nixpkgs {
        inherit system;
        overlays = builtins.attrValues self.outputs.overlays;
        config.allowUnfree = true;
      };
    in
    {

      # This sets `pkgs` to a nixpkgs with allowUnfree option set.
      packages = import ../pkgs {
        inherit (self) inputs outputs;
        pkgs = npkgs;
      };

    };
}
