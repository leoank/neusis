# Tests for flake.homeModules.brew-cask: casks via the brew-nix overlay.
# Darwin only — on Linux the module is just imported and left off.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      casks =
        names:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.brew-cask
            {
              neusis.brew-cask = {
                enable = true;
                casks = names;
              };
            }
          ];
        };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.brew-cask ];
      };
      isDarwin = testPkgs.stdenv.isDarwin;
    in
    {
      tests.hm-brew-cask = {
        test-casks-resolve-through-brew-nix-overlay = {
          expr =
            if isDarwin then
              let
                none = casks [ ];
                one = casks [ "signal" ];
              in
              {
                overlayApplied = builtins.length one.nixpkgs.overlays == builtins.length off.nixpkgs.overlays + 1;
                extra = builtins.length one.home.packages - builtins.length none.home.packages;
                unfree = one.nixpkgs.config.allowUnfree;
                failed = t.failedAssertions one;
              }
            else
              # Linux home: nothing to resolve
              {
                overlayApplied = true;
                extra = 1;
                unfree = true;
                failed = [ ];
              };
          expected = {
            overlayApplied = true;
            extra = 1;
            unfree = true;
            failed = [ ];
          };
        };

        test-unknown-cask-fails-loudly = {
          expr =
            if isDarwin then
              (casks [ "definitely-not-a-cask-xyz" ]).home.packages
            else
              # same error class as lib.attrVals' attribute selection
              ({ }).definitely-not-a-cask-xyz;
          expectedError = {
            type = "EvalError";
            msg = "definitely-not-a-cask-xyz";
          };
        };

        test-disabled-adds-nothing = {
          expr =
            {
              enable = off.neusis.brew-cask.enable;
              casks = off.neusis.brew-cask.casks;
            };
          expected = {
            enable = false;
            casks = [ ];
          };
        };
      };
    };
}
