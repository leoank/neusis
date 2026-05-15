{ pkgs, inputs, ... }:
let
  jail = inputs.jail-nix.lib.init pkgs;
  claude_pkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
  opencode_pkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  gemini_pkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.gemini-cli;
  pi_pkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
  hermes_pkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.hermes-agent;

  # Common packages available to all agents
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
  # Common sandbox options shared by both agents
  commonJailOptions = with jail.combinators; [
    network
    time-zone
    no-new-session
    mount-cwd
  ];
  # Claude
  makeJailedclaude =
    {
      extraPkgs ? [ ],
    }:
    jail "claude" claude_pkg (
      with jail.combinators;
      (
        commonJailOptions
        ++ [
          # Give it a safe spot for its own config and cache.
          # This also lets it remember things between sessions.
          (readwrite (noescape "~/.claude"))
          (readwrite (noescape "~/.claude.json"))
          (readwrite (noescape "~/.claude.json.backup"))

          (add-pkg-deps commonPkgs)
          (add-pkg-deps extraPkgs)
        ]
      )
    );
  jailed_claude = makeJailedclaude { };
  custom_claude_pkg = if pkgs.stdenv.isLinux then jailed_claude else claude_pkg;

  # Opencode
  makeJailedOpencode =
    {
      extraPkgs ? [ ],
    }:
    jail "opencode" opencode_pkg (
      with jail.combinators;
      (
        commonJailOptions
        ++ [
          # Give it a safe spot for its own config and cache.
          # This also lets it remember things between sessions.
          (readwrite (noescape "~/.config/opencode"))
          (readwrite (noescape "~/.local/share/opencode"))
          (readwrite (noescape "~/.local/state/opencode"))

          (add-pkg-deps commonPkgs)
          (add-pkg-deps extraPkgs)
        ]
      )
    );
  jailed_opencode = makeJailedOpencode { };
  custom_opencode_pkg = if pkgs.stdenv.isLinux then jailed_opencode else opencode_pkg;

  # gemini
  makeJailedGemini =
    {
      extraPkgs ? [ ],
    }:
    jail "gemini" gemini_pkg (
      with jail.combinators;
      (
        commonJailOptions
        ++ [
          # Give it a safe spot for its own config and cache.
          # This also lets it remember things between sessions.
          (readwrite (noescape "~/.gemini"))

          (add-pkg-deps commonPkgs)
          (add-pkg-deps extraPkgs)
        ]
      )
    );
  jailed_gemini = makeJailedGemini { };
  custom_gemini_pkg = if pkgs.stdenv.isLinux then jailed_gemini else gemini_pkg;

  # pi
  makeJailedPi =
    {
      extraPkgs ? [ ],
    }:
    jail "pi" pi_pkg (
      with jail.combinators;
      (
        commonJailOptions
        ++ [
          # Give it a safe spot for its own config and cache.
          # This also lets it remember things between sessions.
          (readwrite (noescape "~/.pi"))

          (add-pkg-deps commonPkgs)
          (add-pkg-deps extraPkgs)
        ]
      )
    );
  jailed_pi = makeJailedPi { };
  custom_pi_pkg = if pkgs.stdenv.isLinux then jailed_pi else pi_pkg;

  # hermes
  makeJailedHermes =
    {
      extraPkgs ? [ ],
    }:
    jail "hermes" pi_pkg (
      with jail.combinators;
      (
        commonJailOptions
        ++ [
          # Give it a safe spot for its own config and cache.
          # This also lets it remember things between sessions.
          (readwrite (noescape "~/.hermes"))

          (add-pkg-deps commonPkgs)
          (add-pkg-deps extraPkgs)
        ]
      )
    );
  jailed_hermes = makeJailedHermes { };
  custom_hermes_pkg = if pkgs.stdenv.isLinux then jailed_hermes else hermes_pkg;
in
{
  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-deck
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.beads
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.beads-viewer
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.spec-kit
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.skills
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.qmd

    custom_pi_pkg
    custom_hermes_pkg
  ];

  programs.mcp = {
    enable = true;
    servers = {
      exa = {
        url = "https://mcp.exa.ai/mcp";
      };
      everything = {
        command = "npx";
        args = [
          "-y"
          "@modelcontextprotocol/server-everything"
        ];
      };
    };
  };
  programs.claude-code = {
    enable = true;
    package = custom_claude_pkg;
    #enableMcpIntegration = true;
    skillsDir = ./skills;
    commandsDir = ./commands;
    agentsDir = ./agents;
    settings = import ./claude_settings.nix;
  };
  programs.opencode = {
    enable = true;
    package = custom_opencode_pkg;
    enableMcpIntegration = true;
    #context = ./AGENTS.md;
    #skills = ./skills;
    #commmands = ./commands;
    #agents = ./agents;
    #extraPackages = with pkgs; [ uv ];
    settings = import ./opencode_settings.nix;
  };
  programs.gemini-cli = {
    enable = true;
    package = custom_gemini_pkg;
    #enableMcpIntegration = true;
    context = {
      GEMINI = ./AGENTS.md;
    };
    #skills = ./skills;
    #commmands = ./commands;
    settings = import ./gemini_settings.nix;
  };

  # Configure claude
  home.file.".calude/CLAUDE.md".source = ./AGENTS.md;

  # Configure gemini agents
  home.file.".gemini/agents".source = ./agents;
  home.file.".gemini/commands".source = ./commands;
  home.file.".gemini/skills".source = ./skills;

  # Configure opencode
  xdg.configFile."opencode/commands".source = ./commands;
  xdg.configFile."opencode/agents".source = ./agents;
  xdg.configFile."opencode/skills".source = ./skills;
  xdg.configFile."opencode/AGENTS.md".source = ./AGENTS.md;

  # Configure pi
  home.file.".pi/agent/AGENTS.md".source = ./AGENTS.md;
  home.file.".pi/agent/skills".source = ./skills;
  home.file.".pi/agent/prompts".source = ./commands;
  home.file.".pi/agent/agents".source = ./agents;
  home.file.".pi/agent/settings.json".text = builtins.toJSON (import ./pi_settings.nix);
  home.file.".pi/agent/models.json".text = builtins.toJSON (import ./pi_models.nix);
}
