# Neusis rc2s2-node home-manager module.
#
# Runs the rc2s2 node daemon (`rc2s2 node serve`) for the logged-in user:
# it observes every Claude Code session on this machine through the hook
# endpoint, the transcript and Claude Code's session registry, holds one
# gRPC stream to the hub, and gates permission dialogs. Cross-platform: a
# launchd user agent on Darwin, a systemd user service on Linux. The daemon
# runs as the user because it reads that user's `~/.claude`.
#
# This module only runs the daemon. It does NOT edit `~/.claude/settings.json`:
# the hook block that points Claude Code at the daemon must live in the user's
# own settings file (SessionStart only fires from there, not from a
# `--settings` file), so adding it is a deliberate manual step —
# `rc2s2 node hooks` prints the block to merge.
#
# Configure via `neusis.services.rc2s2-node.*`.
{ ... }:
{
  flake.homeModules.rc2s2-node =
    {
      config,
      pkgs,
      inputs,
      lib,
      ...
    }:
    let
      cfg = config.neusis.services.rc2s2-node;
      args =
        [
          (lib.getExe cfg.package)
          "node"
          "serve"
          "--hub"
          cfg.hub
          "--token-file"
          cfg.tokenFile
          "--hook-addr"
          cfg.hookAddr
        ]
        ++ lib.optionals (cfg.name != null) [
          "--name"
          cfg.name
        ]
        ++ lib.concatMap (g: [
          "--ignore-cwd"
          g
        ]) cfg.ignoreCwd
        ++ cfg.extraArgs;
      cmdline = lib.escapeShellArgs args;
    in
    {
      options.neusis.services.rc2s2-node = {
        enable = lib.mkEnableOption "the rc2s2 node daemon";

        package = lib.mkOption {
          type = lib.types.package;
          default = inputs.rc2s2.packages.${pkgs.stdenv.hostPlatform.system}.rc2s2;
          defaultText = lib.literalExpression "inputs.rc2s2.packages.\${system}.rc2s2";
          description = "The rc2s2 (node) package providing the `rc2s2` binary.";
        };

        hub = lib.mkOption {
          type = lib.types.str;
          example = "http://ghost001:7700";
          description = "The hub's node service, `http://host:port`.";
        };

        tokenFile = lib.mkOption {
          type = lib.types.str;
          example = "/run/agenix/rc2s2NodeToken";
          description = "File holding this node's pre-shared hub token.";
        };

        name = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Name this node registers under. Defaults to the hostname.";
        };

        hookAddr = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1:7777";
          description = "Address the hook endpoint listens on (must match the hooks block in settings.json).";
        };

        ignoreCwd = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "*/target/live-work-*" ];
          description = ''
            Globs over working directories whose Claude Code sessions the daemon does
            not track at all: not listed, not tailed, their dialogs not held. Keeps
            throwaway test sessions out of the live hub (rc2s2 ADR-0028).
          '';
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "--hold-secs"
            "60"
          ];
          description = "Extra arguments appended to `rc2s2 node serve`.";
        };

        logDir = lib.mkOption {
          type = lib.types.str;
          default = "/tmp";
          description = ''
            Directory for stdout/stderr logs on Darwin (launchd writes
            `<logDir>/rc2s2-node.{out,err}.log`). Linux output goes to the
            user journal — `journalctl --user -u rc2s2-node`.
          '';
        };
      };

      config = lib.mkIf cfg.enable (lib.mkMerge [
        # Darwin: user launchd agent, kept alive.
        (lib.mkIf pkgs.stdenv.isDarwin {
          launchd.agents.rc2s2-node = {
            enable = true;
            config = {
              ProgramArguments = [
                "${pkgs.bash}/bin/bash"
                "-c"
                cmdline
              ];
              KeepAlive = true;
              RunAtLoad = true;
              StandardErrorPath = "${cfg.logDir}/rc2s2-node.err.log";
              StandardOutPath = "${cfg.logDir}/rc2s2-node.out.log";
            };
          };
        })

        # Linux: systemd user service, restarted on failure.
        (lib.mkIf pkgs.stdenv.isLinux {
          systemd.user.services.rc2s2-node = {
            Unit.Description = "rc2s2 node daemon";
            Service = {
              ExecStart = "${pkgs.bash}/bin/bash -c ${lib.escapeShellArg cmdline}";
              Restart = "on-failure";
              RestartSec = 5;
            };
            Install.WantedBy = [ "default.target" ];
          };
        })
      ]);
    };
}
