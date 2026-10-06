# Tests for flake.agnosticModules.kanata on both platforms. Darwin gets
# the Karabiner driver daemon plus one launchd daemon per keyboard; Linux
# forwards to nixpkgs's `services.kanata`.
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
          # The config is a writeText derivation; its `text` attribute is the
          # content, available without building (readFile would build an
          # aarch64-darwin derivation, impossible on a Linux CI runner).
          expr =
            let
              cfgPath = lib.last (daemonArgs twoBoards "kanata-laptop");
              text = twoBoards.neusis.services.kanata.keyboards.laptop.config;
              defcfg = twoBoards.neusis.services.kanata.keyboards.laptop.extraDefCfg;
            in
            {
              name = lib.hasSuffix "kanata-laptop-config.kdb" cfgPath;
              hasDefcfg = lib.hasInfix "danger-enable-cmd yes" defcfg;
              hasBody = lib.hasInfix "(defsrc caps)" text;
            };
          expected = {
            name = true;
            hasDefcfg = true;
            hasBody = true;
          };
        };

        test-nixos-forwards-to-services-kanata = {
          expr = {
            pkg = t.hasPkg "kanata" nixos.environment.systemPackages;
            forwarded = nixos.services.kanata.enable;
            keyboards = builtins.attrNames nixos.services.kanata.keyboards;
            cfgFile = toString nixos.services.kanata.keyboards.default.configFile;
            noLaunchd = !(nixos ? launchd);
            failed = t.failedAssertions nixos;
          };
          expected = {
            pkg = true;
            forwarded = true;
            keyboards = [ "default" ];
            cfgFile = toString ../../agnosticModules/kanata/custom.kbd;
            noLaunchd = true;
            failed = [ ];
          };
        };

        test-nixos-null-config-file-lets-nixpkgs-synthesize = {
          expr =
            let
              cfg = t.evalNixos {
                modules = [
                  self.nixosModules.kanata
                  {
                    neusis.services.kanata = {
                      enable = true;
                      keyboards.laptop = {
                        config = "(defsrc caps) (deflayer base esc)";
                        devices = [ "/dev/input/by-id/kbd" ];
                        port = 6666;
                      };
                    };
                  }
                ];
              };
              kbd = cfg.services.kanata.keyboards.laptop;
            in
            {
              synthesized = lib.hasPrefix builtins.storeDir (toString kbd.configFile);
              devices = kbd.devices;
              port = kbd.port;
            };
          expected = {
            synthesized = true;
            devices = [ "/dev/input/by-id/kbd" ];
            port = 6666;
          };
        };

        test-nixos-disabled-forwards-nothing = {
          expr =
            let
              cfg = t.evalNixos { modules = [ self.nixosModules.kanata ]; };
            in
            {
              forwarded = cfg.services.kanata.enable;
              pkg = t.hasPkg "kanata" cfg.environment.systemPackages;
            };
          expected = {
            forwarded = false;
            pkg = false;
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
