# agent-harness — tutorial

A walkthrough of the `neusis.agent-harness` umbrella: a curated
home-manager bundle for the LLM-CLI ecosystem from
[`llm-agents.nix`](https://github.com/numtide/llm-agents.nix).

Wires up five CLI agents (Claude Code, Opencode, Gemini CLI, pi,
hermes) and a set of always-on extras (agent-deck, beads,
beads-viewer, spec-kit, skills, qmd). On Linux every agent CLI is
**jailed** via
[`jail-nix`](https://sr.ht/~alexdavid/jail.nix) so it can only
read/write its own config dir plus the current working tree. On
Darwin the unwrapped packages are used (no jail support).

Sister module to `supercharged-git` / `supercharged-shell` /
`terminal-velocity`. No tool overlap — all four umbrellas can be
enabled together.

Import:

```nix
imports = [ self.homeModules.agent-harness ];
```

---

## 0. Umbrella extras

```nix
neusis.agent-harness.enable = true;
```

Installs the always-on bundle into `home.packages`, regardless of
which agents you enable:

- **`agent-deck`** — TUI launcher / multiplexer for agent sessions.
- **`beads` + `beads-viewer`** — issue tracker designed for
  agent-assisted workflows (used by this very project, see
  `AGENTS.md`).
- **`spec-kit`** — spec-first agent tooling.
- **`skills`** — runtime support library used by skill-creator.
- **`qmd`** — markdown indexer (paired with `qmd-reindex`
  home-manager service).

Independent of `tools.<x>.enable` — turning the umbrella on without
any individual agent is fine if you only want the extras.

---

## 1. Shared directories

These four options control the data shared across every enabled
agent. Defaults point at the bundled assets next to the module
(`./agents`, `./commands`, `./skills`, `./AGENTS.md`).

```nix
neusis.agent-harness = {
  enable = true;
  # Override any of these to swap in your own scaffold:
  # agentsDir   = ./my-agents;
  # commandsDir = ./my-commands;
  # skillsDir   = ./my-skills;
  # agentsMd    = ./MY-AGENTS.md;
};
```

| Option | Linked into |
|---|---|
| `agentsDir`   | `~/.gemini/agents`, `~/.pi/agent/agents`, `xdg.configFile."opencode/agents"`, and Claude Code's `agentsDir` |
| `commandsDir` | same set as above (substitute `commands`; pi calls it `prompts`) |
| `skillsDir`   | same set as above |
| `agentsMd`    | `~/.calude/CLAUDE.md`*, `~/.pi/agent/AGENTS.md`, `xdg.configFile."opencode/AGENTS.md"`, Gemini's `context.GEMINI` |

\* Yes, the path has a typo (`.calude` instead of `.claude`).
Preserved verbatim from the legacy config; fix in your own override
if it bothers you. The "real" claude config dir is managed
separately by `programs.claude-code`.

---

## 2. `claude` — Claude Code CLI

```nix
neusis.agent-harness.tools.claude.enable = true;
```

Enables `programs.claude-code` with the bundled
`skillsDir`/`commandsDir`/`agentsDir` and a sensible default
settings file (`acceptEdits` permissions, dark theme, no
co-authored-by trailer).

Override settings:

```nix
neusis.agent-harness.tools.claude.settings = {
  hooks = {
    PreToolUse = [ /* … */ ];
    PostToolUse = [ /* … */ ];
  };
  permissions.defaultMode = "ask";
  theme = "light";
};
```

Add extra packages to the Linux jail (no-op on Darwin):

```nix
neusis.agent-harness.tools.claude.extraPkgs = with pkgs; [ uv nodejs_22 ];
```

---

## 3. `opencode` — Opencode CLI

```nix
neusis.agent-harness.tools.opencode.enable = true;
```

Enables `programs.opencode` with `enableMcpIntegration = true`.
Defaults set `autoshare = false` and `autoupdate = false` (the rest
are opencode's own defaults).

The shared `agentsDir` / `commandsDir` / `skillsDir` / `agentsMd`
are linked into `~/.config/opencode/{agents,commands,skills,AGENTS.md}`.

```nix
neusis.agent-harness.tools.opencode.settings = {
  autoshare = false;
  autoupdate = false;
  # ... other opencode keys
};
```

---

## 4. `gemini` — Gemini CLI

```nix
neusis.agent-harness.tools.gemini.enable = true;
```

Enables `programs.gemini-cli` with vim-mode + nvim editor +
preview features. `context.GEMINI` is wired to the umbrella's
`agentsMd`. The shared dirs are linked into `~/.gemini/{agents,commands,skills}`.

Defaults:

```nix
{
  context.loadMemoryFromIncludeDirectories = true;
  general = {
    preferredEditor = "nvim";
    previewFeatures = true;
    vimMode = true;
  };
  ide.enabled = true;
  privacy.usageStatisticsEnabled = false;
  security.auth.selectedType = "oauth-personal";
}
```

Override:

```nix
neusis.agent-harness.tools.gemini.settings = {
  general.vimMode = false;
  privacy.usageStatisticsEnabled = true;
};
```

---

## 5. `pi` — pi agent

```nix
neusis.agent-harness.tools.pi.enable = true;
```

pi has no first-party home-manager module yet, so this writes its
config files directly via `home.file`:

- `~/.pi/agent/AGENTS.md` ← `agentsMd`
- `~/.pi/agent/skills` ← `skillsDir`
- `~/.pi/agent/prompts` ← `commandsDir` (pi calls them prompts)
- `~/.pi/agent/agents` ← `agentsDir`
- `~/.pi/agent/settings.json` ← `cfg.tools.pi.settings` (JSON-encoded)
- `~/.pi/agent/models.json` ← `cfg.tools.pi.models` (JSON-encoded)

Defaults (full set in the module source):

```nix
settings = {
  defaultThinkingLevel = "medium";
  theme = "dark";
  compaction = {
    enabled = true;
    reserveTokens = 16384;
    keepRecentTokens = 20000;
  };
  # … retry, warnings, packages
};

models = {
  providers.lmstudio = {
    baseUrl = "http://localhost:1234/v1";
    api = "openai-completions";
    apiKey = "lm-studio";
    models = [ { id = "google/gemma-4-e4b"; input = [ "text" "image" ]; } ];
  };
};
```

Point pi at a different local LLM gateway:

```nix
neusis.agent-harness.tools.pi.models.providers.lmstudio.baseUrl =
  "http://devbox.local:9876/v1";
```

---

## 6. `hermes` — hermes agent

```nix
neusis.agent-harness.tools.hermes.enable = true;
```

Installs the jailed `hermes-agent` binary; no per-agent config yet.
The legacy `cli_agents.nix` accidentally passed the `pi` package as
the source for the hermes jail — this module uses `hermes-agent`
instead, matching the variable name.

---

## Putting it all together

```nix
imports = [
  self.homeModules.supercharged-git
  self.homeModules.supercharged-shell
  self.homeModules.terminal-velocity
  self.homeModules.agent-harness
];

neusis.agent-harness = {
  enable = true;
  tools = {
    claude.enable = true;
    opencode.enable = true;
    gemini.enable = true;
    pi.enable = true;
    # hermes.enable = false  # off until needed
  };
};
```

A typical session afterwards:

```sh
agent-deck                       # browse all configured agents
claude                           # Claude Code with jailed config
opencode                         # Opencode
gemini                           # Gemini CLI in vim mode

bd ready                         # beads — find available work
qmd update && qmd embed          # re-index notes for retrieval
```

---

## Linux jailing

On Linux, each agent CLI is wrapped via `jail-nix`. The wrapper
restricts the agent so it can only:

- See `commonPkgs` (bash, curl, wget, jq, git, ripgrep, gnugrep,
  ps, find, gzip, unzip, tar, diffutils, nh, …) — minimum tooling
  to actually do something useful.
- Read/write its **own state dirs**:
  - claude: `~/.claude`, `~/.claude.json`, `~/.claude.json.backup`
  - opencode: `~/.config/opencode`, `~/.local/share/opencode`,
    `~/.local/state/opencode`
  - gemini: `~/.gemini`
  - pi: `~/.pi`
  - hermes: `~/.hermes`
- Read/write the **current working tree** (`mount-cwd`).
- Use network + local timezone, and no-new-session for clean
  process accounting.

Anything outside those paths is opaque to the agent. To grant
read/write of additional paths, fork the module or use the
`extraPkgs` knob to add tools that already know how to find their
own data outside the jail.

On **Darwin**, jail-nix isn't supported — the unwrapped packages
are used. That means agents have full FS access on macOS hosts;
keep that in mind when granting them filesystem-level tools.

---

## Overlap with sister umbrellas

| Tool | Umbrella |
|---|---|
| `gh`, `gh-dash`, `lazygit`, `delta`, `pre-commit`, `commitizen`, `jujutsu`, `act`, `mergiraf`, `gitleaks`, `multi-account`, `bootstrap-repos`, `gclb` | supercharged-git |
| `direnv`, `zoxide`, `fzf`, `tv`, `nix-search-tv`, `nix-your-shell`, `nix-init`, `yazi`, `atuin` | supercharged-shell |
| `wezterm`, `kitty`, `zellij`, `tmux`, `sesh`, `mosh`, `eternal-terminal` | terminal-velocity |
| `claude-code`, `opencode`, `gemini-cli`, `pi`, `hermes`, `agent-deck`, `beads`, `beads-viewer`, `spec-kit`, `skills`, `qmd` | agent-harness (this umbrella) |
| `paperwm`, `activespace` (macOS-only window tiling) | hammerspoon |

---

## Where to go next

- `programs.{claude-code,opencode,gemini-cli}` from
  `llm-agents.nix` expose more knobs than we surface here. Override
  via `programs.<x>.<…>` after enabling — home-manager merges your
  config with ours.
- The bundled `skills/skill-creator/` is upstream's reference skill.
  Treat it as starting material; create your own under
  `skills/<name>/` and they'll get picked up the same way (every
  enabled agent links the whole `skillsDir`).
- `AGENTS.md` is intentionally short (~60 lines of behavioral
  rules). Extend it before sharing the umbrella across team
  members — agent quality is dominated by the prompt, not the
  binary.
