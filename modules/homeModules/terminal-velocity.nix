# Neusis terminal-velocity home-manager module.
# (Physics pun: "max speed of a falling object" → "go fast at the
# terminal". Pairs with `supercharged-git` and `supercharged-shell`.)
#
# Umbrella for terminal emulators, multiplexers, and remote-shell
# clients:
#   - `wezterm` — GPU-accelerated emulator with a Lua config.
#   - `kitty`   — second emulator (most macOS users keep both).
#   - `zellij`  — modern multiplexer (tmux alternative), with layouts.
#   - `tmux`    — classic multiplexer with vim-tmux-navigator,
#                  resurrect/continuum, popup bindings.
#   - `sesh`    — tmux session orchestrator (fuzzy session picker).
#   - `mosh`    — UDP-based SSH replacement (roaming-friendly).
#   - `eternal-terminal` — TCP-based SSH replacement (firewall-friendly).
#
# Each tool is opt-in via `neusis.terminal-velocity.tools.<name>.enable`.
# No umbrella `enable` — there's no shared config across tools.
{ self, ... }:
{
  flake.homeModules.terminal-velocity =
    { ... }:
    {
      imports = [
        self.homeModules.terminal-velocity-wezterm
        self.homeModules.terminal-velocity-kitty
        self.homeModules.terminal-velocity-zellij
        self.homeModules.terminal-velocity-tmux
        self.homeModules.terminal-velocity-sesh
        self.homeModules.terminal-velocity-mosh
        self.homeModules.terminal-velocity-eternal-terminal
      ];
    };
}
