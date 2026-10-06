# Neusis kanata system module.
#
# Mirrors nixpkgs's `services.kanata` option surface:
#   - `neusis.services.kanata.enable`
#   - `neusis.services.kanata.package`
#   - `neusis.services.kanata.keyboards.<name>.{devices,config,extraDefCfg,
#                                                configFile,extraArgs,port}`
#
# On Linux the keyboards are forwarded verbatim to nixpkgs's
# `services.kanata`. On Darwin each keyboard runs as its own launchd
# daemon, plus the Karabiner-VirtualHIDDevice driver is set up once
# (kernel extension copied into /Applications, driver daemon started,
# kext activation triggered).
#
# Defaults to a single `keyboards.default` whose `configFile` is the
# `custom.kbd` shipped next to this module.
#
# Darwin half adapted from:
#   https://github.com/nix-darwin/nix-darwin/blob/7ebf95a73e3b54e0f9c48f50fde29e96257417ac/modules/services/karabiner-elements/default.nix
{ ... }:
{
  flake.agnosticModules.kanata =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.services.kanata;
      parentAppDir = "/Applications/.Nix-Karabiner";

      mkName = name: "kanata-${name}";

      # Darwin-side config synthesis. Mirrors nixpkgs's `mkConfig` but
      # without `linux-dev` / `linux-continue-if-no-devs-found` — those
      # are Linux-specific defcfg directives. If the user has supplied
      # `configFile`, we pass it through verbatim.
      mkDarwinConfig =
        name: keyboard:
        if keyboard.configFile != null then
          keyboard.configFile
        else
          pkgs.writeText "${mkName name}-config.kdb" ''
            (defcfg
              ${keyboard.extraDefCfg})

            ${keyboard.config}
          '';

      mkDarwinDaemon = name: keyboard: {
        serviceConfig = {
          ProgramArguments = [
            (lib.getExe cfg.package)
            "--cfg"
            (toString (mkDarwinConfig name keyboard))
          ]
          ++ keyboard.extraArgs
          ++ lib.optionals (keyboard.port != null) [
            "--port"
            (toString keyboard.port)
          ];
          ProcessType = "Interactive";
          Label = "org.nixos.${mkName name}";
          KeepAlive = true;
        };
      };

      keyboardType = lib.types.submodule {
        options = {
          devices = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [ "/dev/input/by-id/usb-0000_0000-event-kbd" ];
            description = ''
              Paths to keyboard devices (Linux only). Empty list ⇒
              kanata auto-detects keyboards. Ignored on Darwin —
              Karabiner-VirtualHIDDevice captures input globally.
            '';
          };

          config = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = ''
              Kanata configuration body (everything outside the
              `defcfg` block). Use this together with `extraDefCfg`,
              or set `configFile` instead.
            '';
          };

          extraDefCfg = lib.mkOption {
            type = lib.types.lines;
            default = "";
            example = "danger-enable-cmd yes";
            description = ''
              Extra entries added to the synthesized `defcfg` block.
              On Linux `linux-dev` (from `devices`) and
              `linux-continue-if-no-devs-found yes` are added by
              nixpkgs's module; on Darwin they're omitted. Ignored
              when `configFile` is set.
            '';
          };

          configFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = ''
              Path to a complete kanata `.kbd` file. Takes precedence
              over `config` + `extraDefCfg` synthesis. Use this when
              you have a hand-written kbd to pass through verbatim.
            '';
          };

          extraArgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Extra command-line arguments passed to kanata.";
          };

          port = lib.mkOption {
            type = lib.types.nullOr lib.types.port;
            default = null;
            example = 6666;
            description = ''
              TCP port for kanata's control server. `null` disables
              the server.
            '';
          };
        };
      };
    in
    {
      options.neusis.services.kanata = {
        enable = lib.mkEnableOption "neusis-managed kanata keyboard remapper";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.kanata;
          defaultText = lib.literalExpression "pkgs.kanata";
          description = ''
            The kanata package to run. On Darwin
            `passthru.darwinDriver` is also read off this package to
            stage the Karabiner-VirtualHIDDevice driver app — any
            override needs to keep that passthru intact.
          '';
        };

        keyboards = lib.mkOption {
          type = lib.types.attrsOf keyboardType;
          default = {
            default.configFile = ./custom.kbd;
          };
          description = ''
            Per-keyboard kanata configurations. Mirrors nixpkgs's
            `services.kanata.keyboards`. On Linux this is forwarded
            verbatim to nixpkgs's module. On Darwin each entry spawns
            its own launchd daemon.

            Defaults to a single `default` keyboard whose
            `configFile` is the `custom.kbd` shipped next to this
            module — override or extend per host.
          '';
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          # Both platforms: install the kanata binary.
          {
            environment.systemPackages = [ cfg.package ];
          }

          # Linux: forward to nixpkgs's services.kanata. Skip
          # `configFile` when `null` so nixpkgs's computed default
          # (`mkConfig name keyboard`) takes over.
          # (lib.mkIf pkgs.stdenv.isLinux {
          #   services.kanata = {
          #     enable = true;
          #     package = cfg.package;
          #     keyboards = lib.mapAttrs (
          #       _: kbd:
          #       {
          #         inherit (kbd)
          #           devices
          #           config
          #           extraDefCfg
          #           extraArgs
          #           port
          #           ;
          #       }
          #       // lib.optionalAttrs (kbd.configFile != null) { inherit (kbd) configFile; }
          #     ) cfg.keyboards;
          #   };
          # })

          # Darwin: Karabiner-VirtualHIDDevice driver staging + one
          # launchd daemon per keyboard.
          (lib.mkIf pkgs.stdenv.isDarwin {
            # Kernel extensions must reside in /Applications and can't
            # be symlinks, so stage the driver app there during system
            # activation.
            system.activationScripts.preActivation.text = ''
              rm -rf ${parentAppDir}
              mkdir -p ${parentAppDir}
              cp -r ${pkgs.karabiner-elements.driver}/Applications/.Karabiner-VirtualHIDDevice-Manager.app ${parentAppDir}
            '';

            # Activate the kernel extension on user login.
            launchd.user.agents.activate_karabiner_system_ext = {
              serviceConfig.ProgramArguments = [
                "${parentAppDir}/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
                "activate"
              ];
              serviceConfig.RunAtLoad = true;
            };

            # The Karabiner driver daemon + one kanata daemon per
            # keyboard. NOTE: each kanata binary also needs "Input
            # Monitoring" permission via System Settings → Privacy &
            # Security → Input Monitoring on first launch.
            launchd.daemons = {
              Karabiner-DriverKit-VirtualHIDDevice-Daemon = {
                serviceConfig = {
                  ProgramArguments = [
                    "${cfg.package.passthru.darwinDriver}/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
                  ];
                  ProcessType = "Interactive";
                  Label = "org.pqrs.Karabiner-DriverKit-VirtualHIDDevice-Daemon";
                  KeepAlive = true;
                };
              };
            }
            // lib.mapAttrs' (
              name: kbd: lib.nameValuePair (mkName name) (mkDarwinDaemon name kbd)
            ) cfg.keyboards;
          })
        ]
      );
    };
}
