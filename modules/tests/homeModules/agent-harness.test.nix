# Tests for flake.homeModules.agent-harness: the shared extras bundle and
# each agent tool's wiring (package, settings, shared AGENTS.md / skills /
# commands / agents directories). On Linux the agent binaries are jailed
# (jail.nix); on Darwin they are the plain llm-agents packages.
{ self, inputs, ... }:
{
  perSystem =
    {
      lib,
      testPkgs,
      system,
      ...
    }:
    let
      t = self.neusis.lib.tests;
      llmPkgs = inputs.llm-agents.packages.${system};

      harness =
        extra:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.agent-harness
            { neusis.agent-harness = extra; }
          ];
        };

      off = harness { };
      base = baseNameOf;
      src = cfg: path: base (toString cfg.home.file.${path}.source);
    in
    {
      tests.hm-agent-harness = {
        test-everything-off-by-default = {
          expr = {
            enable = off.neusis.agent-harness.enable;
            tools = lib.mapAttrs (_: tool: tool.enable) off.neusis.agent-harness.tools;
            claude = off.programs.claude-code.enable;
            opencode = off.programs.opencode.enable;
            gemini = off.programs.antigravity-cli.enable;
            beads = t.hasPkg (lib.getName llmPkgs.beads) off.home.packages;
          };
          expected = {
            enable = false;
            tools = lib.genAttrs [
              "antigravity"
              "claude"
              "gemini"
              "hermes"
              "opencode"
              "pi"
            ] (_: false);
            claude = false;
            opencode = false;
            gemini = false;
            beads = false;
          };
        };

        test-enable-installs-shared-extras-only = {
          expr =
            let
              cfg = harness { enable = true; };
            in
            {
              extras = lib.all (p: t.hasPkg (lib.getName p) cfg.home.packages) (
                with llmPkgs;
                [
                  beads
                  beads-viewer
                  spec-kit
                  skills
                  qmd
                ]
              );
              claude = cfg.programs.claude-code.enable;
              failed = t.failedAssertions cfg;
            };
          expected = {
            extras = true;
            claude = false;
            failed = [ ];
          };
        };

        test-claude-wires-settings-and-shared-dirs = {
          expr =
            let
              cfg = harness { tools.claude.enable = true; };
              cc = cfg.programs.claude-code;
            in
            {
              on = cc.enable;
              mode = cc.settings.permissions.defaultMode;
              coAuthored = cc.settings.includeCoAuthoredBy;
              skills = base (toString cc.skills);
              commands = base (toString cc.commandsDir);
              agents = base (toString cc.agentsDir);
              claudeMd = src cfg ".claude/CLAUDE.md";
              failed = t.failedAssertions cfg;
            };
          expected = {
            on = true;
            mode = "acceptEdits";
            coAuthored = false;
            skills = "skills";
            commands = "commands";
            agents = "agents";
            claudeMd = "AGENTS.md";
            failed = [ ];
          };
        };

        test-opencode-wires-settings-and-xdg-dirs = {
          expr =
            let
              cfg = harness { tools.opencode.enable = true; };
            in
            {
              on = cfg.programs.opencode.enable;
              autoupdate = cfg.programs.opencode.settings.autoupdate;
              # home-manager adds opencode/opencode.json itself; these four are ours
              files = lib.genAttrs [ "opencode/AGENTS.md" "opencode/agents" "opencode/commands" "opencode/skills" ] (
                n: base (toString cfg.xdg.configFile.${n}.source)
              );
              failed = t.failedAssertions cfg;
            };
          expected = {
            on = true;
            autoupdate = false;
            files = {
              "opencode/AGENTS.md" = "AGENTS.md";
              "opencode/agents" = "agents";
              "opencode/commands" = "commands";
              "opencode/skills" = "skills";
            };
            failed = [ ];
          };
        };

        test-gemini-uses-legacy-config-with-shared-dirs = {
          expr =
            let
              cfg = harness { tools.gemini.enable = true; };
              ag = cfg.programs.antigravity-cli;
            in
            {
              on = ag.enable;
              legacy = ag.useLegacyGeminiConfig;
              context = base (toString ag.context.GEMINI);
              vimMode = ag.settings.general.vimMode;
              dirs = map (p: src cfg p) [
                ".gemini/agents"
                ".gemini/commands"
                ".gemini/skills"
              ];
              failed = t.failedAssertions cfg;
            };
          expected = {
            on = true;
            legacy = true;
            context = "AGENTS.md";
            vimMode = true;
            dirs = [
              "agents"
              "commands"
              "skills"
            ];
            failed = [ ];
          };
        };

        test-antigravity-alone-provides-gemini-md = {
          expr =
            let
              cfg = harness { tools.antigravity.enable = true; };
            in
            {
              settings = cfg.home.file.".gemini/antigravity-cli/settings.json".text;
              skills = src cfg ".gemini/config/skills";
              geminiMd = src cfg ".gemini/GEMINI.md";
              geminiOff = cfg.programs.antigravity-cli.enable;
              failed = t.failedAssertions cfg;
            };
          expected = {
            settings = "{}";
            skills = "skills";
            geminiMd = "AGENTS.md";
            geminiOff = false;
            failed = [ ];
          };
        };

        test-antigravity-with-gemini-does-not-double-define-gemini-md = {
          expr =
            let
              cfg = harness {
                tools.antigravity.enable = true;
                tools.antigravity.settings.foo = 1;
                tools.gemini.enable = true;
              };
            in
            {
              settings = builtins.fromJSON cfg.home.file.".gemini/antigravity-cli/settings.json".text;
              geminiMd = cfg.home.file ? ".gemini/GEMINI.md";
              failed = t.failedAssertions cfg;
            };
          expected = {
            settings.foo = 1;
            geminiMd = true;
            failed = [ ];
          };
        };

        test-pi-writes-settings-models-and-shared-dirs = {
          expr =
            let
              cfg = harness { tools.pi.enable = true; };
              settings = builtins.fromJSON cfg.home.file.".pi/agent/settings.json".text;
              models = builtins.fromJSON cfg.home.file.".pi/agent/models.json".text;
            in
            {
              thinking = settings.defaultThinkingLevel;
              packages = settings.packages;
              lmstudio = models.providers.lmstudio.baseUrl;
              dirs = map (p: src cfg p) [
                ".pi/agent/AGENTS.md"
                ".pi/agent/skills"
                ".pi/agent/prompts"
                ".pi/agent/agents"
              ];
              failed = t.failedAssertions cfg;
            };
          expected = {
            thinking = "medium";
            packages = [
              "pi-subagents"
              "pi-mcp-adapter"
            ];
            lmstudio = "http://localhost:1234/v1";
            dirs = [
              "AGENTS.md"
              "skills"
              "commands"
              "agents"
            ];
            failed = [ ];
          };
        };

        test-custom-shared-dirs-flow-to-every-agent = {
          expr =
            let
              cfg = harness {
                tools.claude.enable = true;
                tools.pi.enable = true;
                agentsMd = ../_fixtures/placeholder.age;
                skillsDir = ../_fixtures;
              };
            in
            {
              claudeMd = src cfg ".claude/CLAUDE.md";
              piMd = src cfg ".pi/agent/AGENTS.md";
              claudeSkills = base (toString cfg.programs.claude-code.skills);
              piSkills = src cfg ".pi/agent/skills";
            };
          expected = {
            claudeMd = "placeholder.age";
            piMd = "placeholder.age";
            claudeSkills = "_fixtures";
            piSkills = "_fixtures";
          };
        };

        test-agent-packages-land-in-home = {
          expr =
            let
              cfg = harness {
                tools.claude.enable = true;
                tools.antigravity.enable = true;
                tools.pi.enable = true;
                tools.hermes.enable = true;
              };
              names = t.pkgNames (cfg.home.packages ++ [ cfg.programs.claude-code.package ]);
              # Darwin: plain llm-agents packages; Linux: jail wrappers named after the agent
              expect =
                if testPkgs.stdenv.isDarwin then
                  map lib.getName (
                    with llmPkgs;
                    [
                      claude-code
                      antigravity-cli
                      pi
                      hermes-agent
                    ]
                  )
                else
                  [
                    "claude"
                    "agy"
                    "pi"
                    "hermes"
                  ];
            in
            lib.all (n: builtins.elem n names) expect;
          expected = true;
        };
      };
    };
}
