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
#
# `darwin.signing` (ADR-0022): the daemons run a copy of kanata signed with a fixed
# identity, so macOS keeps its Input Monitoring grant across kanata rebuilds.
{ self, ... }:
{
  flake.agnosticModules.kanata =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.services.kanata;

      # Platform discriminators read from the OPTIONS set (not `pkgs`), so
      # they can gate top-level option keys that only exist on one platform
      # (`launchd`, `services.kanata`) without forcing nixpkgs or
      # registering a non-existent option path. See tailscale.nix.
      isDarwin = options ? launchd;
      isLinux = options ? systemd;
      parentAppDir = "/Applications/.Nix-Karabiner";

      # The driver daemon runs from a copy outside the store. macOS's App Management
      # protects a signed app bundle once it has run, so a store copy could never be
      # deleted again and stopped every nix-collect-garbage at it (rogue, 2026-11-22).
      # A folder per driver build: an old, protected copy never has to be overwritten.
      driver = cfg.package.passthru.darwinDriver;
      daemonAppRoot = "/Library/Application Support/Nix-Karabiner";
      daemonAppDir = "${daemonAppRoot}/${baseNameOf driver}";
      daemonApp = "${daemonAppDir}/Karabiner-VirtualHIDDevice-Daemon.app";

      mkName = name: "kanata-${name}";

      # The signed copy the daemons run with `darwin.signing` (ADR-0022): a fixed path, since
      # macOS keys a command-line program's grant on its path and its requirement.
      signing = cfg.darwin.signing;
      logMaxKiB = 10240;
      signedDir = "/Library/Application Support/neusis/signed/${signing.identifier}";
      kanataBin =
        if signing.enable then "${signedDir}/kanata" else "/run/current-system/sw/bin/kanata";

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
            kanataBin
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
          StandardOutPath = "/Library/Logs/${mkName name}.out.log";
          StandardErrorPath = "/Library/Logs/${mkName name}.err.log";
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

        darwin.signing = {
          enable = lib.mkEnableOption ''
            running kanata from a copy signed with a fixed identity (Darwin only,
            ADR-0022), so its Input Monitoring grant survives rebuilds. A launchd job
            signs the copy with rcodesign whenever the package changes, and restarts the
            daemons'';

          keyFile = lib.mkOption {
            type = lib.types.str;
            example = "/run/agenix/neusisCodesignSystem";
            description = ''
              Runtime path to the PEM private key of the signing identity, readable by
              root only (an agenix system secret). Never a store path.
            '';
          };

          certFile = lib.mkOption {
            type = lib.types.path;
            description = "The identity's PEM certificate (public; may live in the repo).";
          };

          identifier = lib.mkOption {
            type = lib.types.str;
            default = "dev.leoank.kanata";
            description = ''
              The code-signing identifier. Part of the requirement macOS keys the grant
              on: changing it costs a re-grant.
            '';
          };
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

      config = lib.mkMerge [
        # Both platforms: install the kanata binary.
        (lib.mkIf cfg.enable {
          environment.systemPackages = [ cfg.package ];
        })

        # Linux: forward to nixpkgs's services.kanata. Skip `configFile`
        # when `null` so nixpkgs's computed default (`mkConfig name
        # keyboard`) takes over. `optionalAttrs isLinux` omits the
        # `services.kanata` key entirely on Darwin.
        (lib.optionalAttrs isLinux {
          # nixpkgs's units have no restart policy, and at boot kanata can
          # start before udev has applied the `uinput` group to /dev/uinput
          # ("Failed to open the output uinput device", seen on fast KVM
          # hosts). Retry instead of staying failed.
          systemd.services = lib.mkIf cfg.enable (
            lib.mapAttrs' (
              name: _:
              lib.nameValuePair (mkName name) {
                serviceConfig = {
                  Restart = lib.mkDefault "on-failure";
                  RestartSec = lib.mkDefault 2;
                };
                unitConfig.StartLimitIntervalSec = lib.mkDefault 0;
              }
            ) cfg.keyboards
          );

          services.kanata = lib.mkIf cfg.enable {
            enable = true;
            package = cfg.package;
            keyboards = lib.mapAttrs (
              _: kbd:
              {
                inherit (kbd)
                  devices
                  config
                  extraDefCfg
                  extraArgs
                  port
                  ;
              }
              // lib.optionalAttrs (kbd.configFile != null) { inherit (kbd) configFile; }
            ) cfg.keyboards;
          };
        })

        # Darwin: Karabiner-VirtualHIDDevice driver staging + one launchd
        # daemon per keyboard. `optionalAttrs isDarwin` omits the launchd /
        # activation keys entirely on NixOS.
        (lib.optionalAttrs isDarwin {
          # Kernel extensions must reside in /Applications and can't be
          # symlinks, so stage the driver app there during system
          # activation.
          system.activationScripts.preActivation.text = lib.mkIf cfg.enable ''
            rm -rf ${parentAppDir}
            mkdir -p ${parentAppDir}
            cp -Rf ${cfg.package.passthru.darwinDriver}/Applications/.Karabiner-VirtualHIDDevice-Manager.app ${parentAppDir}

            if [ ! -d "${daemonApp}" ]; then
              mkdir -p "${daemonAppDir}"
              cp -R "${driver}/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app" "${daemonAppDir}/"
            fi
            for d in "${daemonAppRoot}"/*; do
              [ "$d" = "${daemonAppDir}" ] && continue
              rm -rf "$d" 2>/dev/null \
                || echo "kanata: could not remove $d (macOS App Management); delete it from a terminal allowed to modify apps" >&2
            done
          '';

          # Activate the kernel extension on user login.
          launchd.user.agents.activate_karabiner_system_ext = lib.mkIf cfg.enable {
            serviceConfig.ProgramArguments = [
              "${parentAppDir}/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
              "activate"
            ];
            serviceConfig.RunAtLoad = true;
          };

          # The Karabiner driver daemon + one kanata daemon per keyboard.
          # NOTE: /run/current-system/sw/bin/kanata needs "Input Monitoring"
          # permission via System Settings → Privacy & Security → Input
          # Monitoring on first launch.
          launchd.daemons = lib.mkIf cfg.enable (
            {
              Karabiner-DriverKit-VirtualHIDDevice-Daemon = {
                serviceConfig = {
                  ProgramArguments = [
                    "${daemonApp}/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
                  ];
                  ProcessType = "Interactive";
                  Label = "org.pqrs.Karabiner-DriverKit-VirtualHIDDevice-Daemon";
                  KeepAlive = true;
                  StandardOutPath = "/Library/Logs/Karabiner-DriverKit-VirtualHIDDevice-Daemon.out.log";
                  StandardErrorPath = "/Library/Logs/Karabiner-DriverKit-VirtualHIDDevice-Daemon.err.log";
                };
              };
            }
            // lib.mapAttrs' (name: kbd: lib.nameValuePair (mkName name) (mkDarwinDaemon name kbd)) cfg.keyboards
            # Keeps each kanata log under logMaxKiB, keeping one previous copy (`.0`).
            # Not newsyslog: it rotates by renaming and can only signal a pid file,
            # which kanata has none of, so kanata would keep writing to the renamed file.
            # launchd opens the logs O_APPEND, so copying aside and truncating in place
            # is safe while kanata runs.
            // {
              kanata-logtrim = {
                script = lib.concatMapStrings (
                  name:
                  lib.concatMapStrings (
                    stream:
                    let
                      log = "/Library/Logs/${mkName name}.${stream}.log";
                    in
                    ''
                      if [ -f ${log} ] && [ "$(${pkgs.coreutils}/bin/stat -c %s ${log})" -gt $((${toString logMaxKiB} * 1024)) ]; then
                        ${pkgs.coreutils}/bin/cp -f ${log} ${log}.0 && : > ${log}
                      fi
                    ''
                  ) [ "out" "err" ]
                ) (builtins.attrNames cfg.keyboards);
                serviceConfig = {
                  Label = "org.neusis.kanata-logtrim";
                  RunAtLoad = true;
                  StartCalendarInterval = [ { Hour = 4; Minute = 0; } ];
                };
              };
            }
            # A job of its own rather than an activation step: agenix decrypts the key in
            # its own launchd daemon, beside activation and at boot. Its plist names the
            # package, so a kanata rebuild reloads (and so reruns) it.
            // lib.optionalAttrs signing.enable {
              kanata-sign = {
                script = self.neusis.lib.darwinSigning.mkSignScript {
                  inherit pkgs;
                  inherit (signing) identifier keyFile certFile;
                  name = "kanata";
                  program = lib.getExe cfg.package;
                  dir = signedDir;
                  # Reload, not `kickstart -k`: on the first switch the daemon is loaded
                  # before the copy exists, launchd parks it waiting for the executable
                  # and never notices it appear, and a kickstart then hangs (2026-11-27).
                  # Bounded by timeouts, so the job always exits.
                  onChange = lib.concatMapStrings (
                    name:
                    let
                      label = "org.nixos.${mkName name}";
                    in
                    ''
                      ${pkgs.coreutils}/bin/timeout 20 /bin/launchctl bootout system/${label} || true
                      ${pkgs.coreutils}/bin/timeout 20 /bin/launchctl bootstrap system /Library/LaunchDaemons/${label}.plist \
                        || warn "could not reload ${label}"
                    ''
                  ) (builtins.attrNames cfg.keyboards);
                };
                serviceConfig = {
                  Label = "org.neusis.kanata-sign";
                  RunAtLoad = true;
                  StandardErrorPath = "/Library/Logs/kanata-sign.log";
                };
              };
            }
          );
        })
      ];
    };
}
