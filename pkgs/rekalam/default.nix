{
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}:
let
  nixvim = inputs.nixvim.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  nixvimModule = {
    module = import ./config; # import the module directly
    # You can use `extraSpecialArgs` to pass additional arguments to your module files
    extraSpecialArgs = {
      inherit
        inputs
        outputs
        ;
    }
    // import ./lib {
      inherit pkgs lib;
    };
  };
in
nixvim.makeNixvimWithModule nixvimModule
