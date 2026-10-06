# Persistent `claude --remote-control` tmux session, managed by
# home-manager's launchd integration on Darwin. The Claude iOS app
# pairs to the tmux session so you can steer it remotely from your
# phone — handy for triaging from the couch.
#
# Why tmux: claude-rc needs a long-running process that survives
# logout/login. tmux gives us a detached pty container with no GUI.
#
# Prereq — `claude` itself is installed *imperatively* (not via
# nixpkgs):
#
#   nix profile install github:sadjow/claude-code-nix
#
# That lands the binary at `~/.nix-profile/bin/claude`. Override
# `claudeBin` if you keep it somewhere else.
#
# Darwin-only — the config block is gated on `pkgs.stdenv.isDarwin`
# so importing this on Linux is a no-op.
{ ... }:
{
  flake.homeModules.claude-remote =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.claude-remote;
      home = config.home.homeDirectory;
      agentName = "claude-rc-${cfg.profile}";
      sessionName = "${cfg.profile}-rc";
    in
    {
      options.neusis.claude-remote = {
        enable = lib.mkEnableOption ''
          a Darwin launchd agent that keeps a `claude --remote-control`
          tmux session alive for iOS-app pairing
        '';

        profile = lib.mkOption {
          type = lib.types.str;
          default = "admin";
          description = ''
            Profile name passed to `claude --remote-control <profile>`.
            Also derives the launchd agent name
            (`claude-rc-<profile>`) and tmux session name
            (`<profile>-rc`).
          '';
        };

        projectDir = lib.mkOption {
          type = lib.types.str;
          default = "${home}/Documents/Claude/Projects/${cfg.profile}";
          defaultText = lib.literalExpression ''
            "''${config.home.homeDirectory}/Documents/Claude/Projects/''${cfg.profile}"
          '';
          description = "Directory tmux opens the claude session in.";
        };

        claudeBin = lib.mkOption {
          type = lib.types.str;
          default = "${home}/.nix-profile/bin/claude";
          defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/.nix-profile/bin/claude"'';
          description = ''
            Absolute path to the `claude` binary. The default
            assumes claude-code-nix was installed via
            `nix profile install`.
          '';
        };

        logDir = lib.mkOption {
          type = lib.types.str;
          default = "/tmp";
          description = "Where launchd writes stdout / stderr.";
        };
      };

      config = lib.mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
        launchd.agents.${agentName} = {
          enable = true;
          config = {
            ProgramArguments = [
              "/bin/sh"
              "-c"
              # `has-session || new-session` is the right guard for
              # launchd. We deliberately avoid `tmux new-session -A`
              # because its attach codepath wants a TTY when the
              # target session already exists, and launchd agents
              # don't have one — you get "open terminal failed:
              # not a terminal" in the err log.
              "${pkgs.tmux}/bin/tmux has-session -t ${sessionName} 2>/dev/null || ${pkgs.tmux}/bin/tmux new-session -d -s ${sessionName} -c ${cfg.projectDir} '${cfg.claudeBin} --remote-control ${cfg.profile}'"
            ];
            EnvironmentVariables = {
              PATH = "${home}/.nix-profile/bin:/usr/bin:/bin";
              HOME = home;
            };
            RunAtLoad = true;
            KeepAlive = false;
            StandardErrorPath = "${cfg.logDir}/${agentName}.err.log";
            StandardOutPath = "${cfg.logDir}/${agentName}.out.log";
          };
        };
      };
    };
}
