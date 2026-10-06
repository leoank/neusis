# Tests for flake.agnosticModules.kanata. Darwin gets the Karabiner
# driver daemon plus one launchd daemon per keyboard; Linux currently
# only installs the package (the forwarding to nixpkgs's
# `services.kanata` is commented out in the module — the Linux test pins
# that behaviour and must be updated when it is re-enabled).
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;

      darwinWith =
        extra:
        t.evalDarwin {
          modules = [
            self.darwinModules.kanata
            { neusis.services.kanata = { enable = true; } // extra; }
          ];
        };

      darwin = darwinWith { };

      twoBoards = darwinWith {
        keyboards = {
          laptop.config = "(defsrc caps) (deflayer base esc)";
          laptop.extraDefCfg = "danger-enable-cmd yes";
          external = {
            configFile = ../_fixtures/placeholder.age;
            extraArgs = [ "--debug" ];
            port = 6666;
          };
        };
      };

      nixos = t.evalNixos {
        modules = [
          self.nixosModules.kanata
          { neusis.services.kanata.enable = true; }
        ];
      };

      daemonArgs = cfg: name: cfg.launchd.daemons.${name}.serviceConfig.ProgramArguments;

      # nix-darwin always defines activate-system / nix-daemon; keep ours.
      ourDaemons =
        cfg:
        lib.filter (n: lib.hasPrefix "kanata-" n || lib.hasPrefix "Karabiner" n) (
          builtins.attrNames cfg.launchd.daemons
        );
    in
    {
      tests.agnostic-kanata = {
        test-darwin-default-keyboard-runs-shipped-kbd = {
          expr = {
            pkg = t.hasPkg "kanata" darwin.environment.systemPackages;
            daemons = ourDaemons darwin;
            label = darwin.launchd.daemons.kanata-default.serviceConfig.Label;
            cfgFile = lib.last (daemonArgs darwin "kanata-default");
            binary = builtins.head (daemonArgs darwin "kanata-default");
            activator = darwin.launchd.user.agents ? activate_karabiner_system_ext;
            stagesDriver = lib.hasInfix "/Applications/.Nix-Karabiner" darwin.system.activationScripts.preActivation.text;
            failed = t.failedAssertions darwin;
          };
          expected = {
            pkg = true;
            daemons = [
              "Karabiner-DriverKit-VirtualHIDDevice-Daemon"
              "kanata-default"
            ];
            label = "org.nixos.kanata-default";
            cfgFile = toString ../../agnosticModules/kanata/custom.kbd;
            binary = "/run/current-system/sw/bin/kanata";
            activator = true;
            stagesDriver = true;
            failed = [ ];
          };
        };

        test-darwin-one-daemon-per-keyboard = {
          expr = {
            daemons = ourDaemons twoBoards;
            # synthesized config is a store file; verbatim configFile passes through
            laptopCfgIsStoreFile = lib.hasPrefix builtins.storeDir (lib.last (daemonArgs twoBoards "kanata-laptop"));
            externalArgs = lib.drop 3 (daemonArgs twoBoards "kanata-external");
            externalCfg = lib.elemAt (daemonArgs twoBoards "kanata-external") 2;
          };
          expected = {
            daemons = [
              "Karabiner-DriverKit-VirtualHIDDevice-Daemon"
              "kanata-external"
              "kanata-laptop"
            ];
            laptopCfgIsStoreFile = true;
            externalArgs = [
              "--debug"
              "--port"
              "6666"
            ];
            externalCfg = toString ../_fixtures/placeholder.age;
          };
        };

        test-darwin-synthesized-config-contains-defcfg-and-body = {
          expr =
            let
              file = lib.last (daemonArgs twoBoards "kanata-laptop");
              text = builtins.readFile file;
            in
            {
              hasDefcfg = lib.hasInfix "danger-enable-cmd yes" text;
              hasBody = lib.hasInfix "(defsrc caps)" text;
            };
          expected = {
            hasDefcfg = true;
            hasBody = true;
          };
        };

        # KNOWN BUG, pinned: the module does not evaluate on NixOS. Its
        # Darwin block is gated with `lib.mkIf pkgs.stdenv.isDarwin`, which
        # still registers the `launchd` / `system.activationScripts.preActivation`
        # option paths on Linux ("option does not exist"), and while NixOS
        # formats that error it hits `pkgs.kanata.passthru.darwinDriver`,
        # which is null on Linux. Fix: dispatch on `options ? launchd` like
        # tailscale.nix does. Replace this test with real Linux expectations
        # once fixed.
        test-nixos-does-not-evaluate-yet = {
          expr = t.hasPkg "kanata" nixos.environment.systemPackages;
          expectedError = {
            type = "TypeError";
            msg = "cannot coerce null to a string";
          };
        };

        test-disabled-defines-nothing = {
          expr =
            let
              cfg = t.evalDarwin { modules = [ self.darwinModules.kanata ]; };
            in
            {
              pkg = t.hasPkg "kanata" cfg.environment.systemPackages;
              daemons = ourDaemons cfg;
            };
          expected = {
            pkg = false;
            daemons = [ ];
          };
        };
      };
    };
}
