# Neusis agent-harness home-manager module.
# Ports `homes/ank/configs/agent_harness/` into a single opt-in
# umbrella. Wires up several LLM CLIs (claude-code, opencode,
# gemini-cli, pi, hermes) and a curated bundle of related tooling
# (agent-deck, beads, beads-viewer, spec-kit, skills, qmd).
#
# Layout:
#
#   neusis.agent-harness.enable     → install the always-on extras
#                                      (agent-deck, beads, …) +
#                                      shared AGENTS.md / skills /
#                                      commands / agents dirs.
#   neusis.agent-harness.tools.<x>.enable
#                                    → configure a specific agent.
#
# On Linux every agent CLI is wrapped via `jail-nix` so it can only
# read/write its own config dir + the current working tree. On Darwin
# the unwrapped packages are used (no jail support).
{ ... }:
{
  flake-file.inputs = {
    jail-nix.url = "sourcehut:~alexdavid/jail.nix";
  };

  flake.homeModules.agent-harness =
    {
      config,
      lib,
      pkgs,
      inputs,
      ...
    }:
    let
      cfg = config.neusis.agent-harness;

      # --- per-host helpers (Linux: jail; Darwin: identity) ---

      jail = inputs.jail-nix.lib.init pkgs;
      system = pkgs.stdenv.hostPlatform.system;

      llmPkgs = inputs.llm-agents.packages.${system};

      # Common runtime tools every jailed agent gets access to.
      commonPkgs = with pkgs; [
        bashInteractive
        curl
        wget
        jq
        git
        which
        ripgrep
        gnugrep
        gawkInteractive
        ps
        findutils
        gzip
        unzip
        gnutar
        diffutils
        nh
      ];

      commonJailOptions = with jail.combinators; [
        network
        time-zone
        no-new-session
        mount-cwd
      ];

      # Wrap `agentPkg` in a jail that can read/write the given
      # `stateDirs` (paths under $HOME) and gets `commonPkgs +
      # extraPkgs` available inside. Identity function on Darwin.
      mkJailed =
        name: agentPkg: stateDirs: extraPkgs:
        if pkgs.stdenv.isDarwin then
          agentPkg
        else
          jail name agentPkg (
            with jail.combinators;
            commonJailOptions
            ++ map (d: readwrite (noescape d)) stateDirs
            ++ [
              (add-pkg-deps commonPkgs)
              (add-pkg-deps extraPkgs)
            ]
          );

      # --- per-agent wrapped packages ---

      claudePkg = mkJailed "claude" llmPkgs.claude-code [
        "~/.claude"
        "~/.claude.json"
        "~/.claude.json.backup"
      ] cfg.tools.claude.extraPkgs;

      opencodePkg = mkJailed "opencode" llmPkgs.opencode [
        "~/.config/opencode"
        "~/.local/share/opencode"
        "~/.local/state/opencode"
      ] cfg.tools.opencode.extraPkgs;

      geminiPkg = mkJailed "gemini" llmPkgs.gemini-cli [
        "~/.gemini"
      ] cfg.tools.gemini.extraPkgs;

      piPkg = mkJailed "pi" llmPkgs.pi [
        "~/.pi"
      ] cfg.tools.pi.extraPkgs;

      # NOTE: legacy `cli_agents.nix` passed `pi_pkg` as the source
      # for the hermes jail (likely a typo). We use `hermes-agent`
      # here, matching the variable name.
      hermesPkg = mkJailed "hermes" llmPkgs.hermes-agent [
        "~/.hermes"
      ] cfg.tools.hermes.extraPkgs;
    in
    {
      options.neusis.agent-harness = {
        enable = lib.mkEnableOption ''
          neusis-curated agent-harness extras (agent-deck, beads,
          beads-viewer, spec-kit, skills, qmd) plus the shared
          AGENTS.md / skills / commands / agents directories used by
          every enabled agent. Independent of the per-agent
          `tools.<x>.enable` flags — both layers are opt-in
        '';

        agentsDir = lib.mkOption {
          type = lib.types.path;
          default = ./agents;
          defaultText = lib.literalExpression "./agents";
          description = ''
            Directory of per-task agent definitions, linked into
            each enabled agent's expected location (e.g.
            `~/.gemini/agents`, `xdg.configFile."opencode/agents"`).
          '';
        };

        commandsDir = lib.mkOption {
          type = lib.types.path;
          default = ./commands;
          defaultText = lib.literalExpression "./commands";
          description = ''
            Directory of slash-commands / prompt templates, linked
            into each enabled agent's expected location.
          '';
        };

        skillsDir = lib.mkOption {
          type = lib.types.path;
          default = ./skills;
          defaultText = lib.literalExpression "./skills";
          description = ''
            Directory of skill packages (`skill-creator` ships
            here), linked into each enabled agent's expected
            location.
          '';
        };

        agentsMd = lib.mkOption {
          type = lib.types.path;
          default = ./AGENTS.md;
          defaultText = lib.literalExpression "./AGENTS.md";
          description = ''
            Behavioral guidelines markdown, copied to each agent's
            expected path (CLAUDE.md / GEMINI.md / AGENTS.md).
          '';
        };

        tools = {
          claude = {
            enable = lib.mkEnableOption "Claude Code CLI";
            extraPkgs = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Extra packages added to claude's jail (Linux only).";
            };
            settings = lib.mkOption {
              type = lib.types.attrs;
              default = {
                hooks = {
                  PostToolUse = [ ];
                  PreToolUse = [ ];
                };
                includeCoAuthoredBy = false;
                permissions = {
                  defaultMode = "acceptEdits";
                };
                theme = "dark";
              };
              description = "Contents of `~/.claude/settings.json` (via `programs.claude-code.settings`).";
            };
          };

          opencode = {
            enable = lib.mkEnableOption "Opencode CLI";
            extraPkgs = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Extra packages added to opencode's jail (Linux only).";
            };
            settings = lib.mkOption {
              type = lib.types.attrs;
              default = {
                autoshare = false;
                autoupdate = false;
              };
              description = "Contents of opencode's settings file.";
            };
          };

          gemini = {
            enable = lib.mkEnableOption "Gemini CLI";
            extraPkgs = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Extra packages added to gemini's jail (Linux only).";
            };
            settings = lib.mkOption {
              type = lib.types.attrs;
              default = {
                context.loadMemoryFromIncludeDirectories = true;
                general = {
                  preferredEditor = "nvim";
                  previewFeatures = true;
                  vimMode = true;
                };
                ide.enabled = true;
                privacy.usageStatisticsEnabled = false;
                security.auth.selectedType = "oauth-personal";
              };
              description = "Gemini CLI settings.";
            };
          };

          pi = {
            enable = lib.mkEnableOption "pi agent";
            extraPkgs = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Extra packages added to pi's jail (Linux only).";
            };
            settings = lib.mkOption {
              type = lib.types.attrs;
              default = {
                defaultThinkingLevel = "medium";
                theme = "dark";
                compaction = {
                  enabled = true;
                  reserveTokens = 16384;
                  keepRecentTokens = 20000;
                };
                retry = {
                  enabled = true;
                  maxRetries = 3;
                };
                warnings.anthropicExtraUsage = true;
                packages = [
                  "pi-subagents"
                  "pi-mcp-adapter"
                ];
              };
              description = "Contents of `~/.pi/agent/settings.json`.";
            };
            models = lib.mkOption {
              type = lib.types.attrs;
              default = {
                providers.lmstudio = {
                  baseUrl = "http://localhost:1234/v1";
                  api = "openai-completions";
                  apiKey = "lm-studio";
                  models = [
                    {
                      id = "google/gemma-4-e4b";
                      input = [
                        "text"
                        "image"
                      ];
                    }
                  ];
                };
              };
              description = "Contents of `~/.pi/agent/models.json`.";
            };
          };

          hermes = {
            enable = lib.mkEnableOption "hermes agent";
            extraPkgs = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Extra packages added to hermes's jail (Linux only).";
            };
          };
        };
      };

      config = lib.mkMerge [
        # Umbrella bundle: always-on extras shared by every agent.
        (lib.mkIf cfg.enable {
          home.packages = with llmPkgs; [
            agent-deck
            beads
            beads-viewer
            spec-kit
            skills
            qmd
          ];
        })

        # claude-code.
        (lib.mkIf cfg.tools.claude.enable {
          programs.claude-code = {
            enable = true;
            package = claudePkg;
            skillsDir = cfg.skillsDir;
            commandsDir = cfg.commandsDir;
            agentsDir = cfg.agentsDir;
            inherit (cfg.tools.claude) settings;
          };
          # NOTE: legacy path is `.calude/CLAUDE.md` (typo
          # preserved). `programs.claude-code` already manages
          # `~/.claude/`; this is the only place the umbrella's
          # `agentsMd` is bound for claude.
          home.file.".claude/CLAUDE.md".source = cfg.agentsMd;
        })

        # opencode.
        (lib.mkIf cfg.tools.opencode.enable {
          programs.opencode = {
            enable = true;
            package = opencodePkg;
            inherit (cfg.tools.opencode) settings;
          };
          xdg.configFile = {
            "opencode/commands".source = cfg.commandsDir;
            "opencode/agents".source = cfg.agentsDir;
            "opencode/skills".source = cfg.skillsDir;
            "opencode/AGENTS.md".source = cfg.agentsMd;
          };
        })

        # gemini-cli.
        (lib.mkIf cfg.tools.gemini.enable {
          programs.gemini-cli = {
            enable = true;
            package = geminiPkg;
            context.GEMINI = cfg.agentsMd;
            inherit (cfg.tools.gemini) settings;
          };
          home.file = {
            ".gemini/agents".source = cfg.agentsDir;
            ".gemini/commands".source = cfg.commandsDir;
            ".gemini/skills".source = cfg.skillsDir;
          };
        })

        # pi agent (jailed package + settings.json / models.json).
        (lib.mkIf cfg.tools.pi.enable {
          home.packages = [ piPkg ];
          home.file = {
            ".pi/agent/AGENTS.md".source = cfg.agentsMd;
            ".pi/agent/skills".source = cfg.skillsDir;
            ".pi/agent/prompts".source = cfg.commandsDir;
            ".pi/agent/agents".source = cfg.agentsDir;
            ".pi/agent/settings.json".text = builtins.toJSON cfg.tools.pi.settings;
            ".pi/agent/models.json".text = builtins.toJSON cfg.tools.pi.models;
          };
        })

        # hermes agent (jailed package only; no per-agent config yet).
        (lib.mkIf cfg.tools.hermes.enable {
          home.packages = [ hermesPkg ];
        })
      ];
    };
}
