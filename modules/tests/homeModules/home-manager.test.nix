# Tests for modules/homeModules/home-manager.nix: the home-manager
# flake-parts module is loaded, and the set of exported homeModules is
# exactly what we expect (guards accidental export changes).
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    {
      tests.hm-home-manager = {
        test-exported-home-modules = {
          expr = builtins.attrNames self.homeModules;
          expected = [
            "agent-harness"
            "brave"
            "brew-cask"
            "claude-remote"
            "hammerspoon"
            "mpd"
            "qmd-reindex"
            "rmpc"
            "secrets"
            "supercharged-git"
            "supercharged-git-act"
            "supercharged-git-bootstrap-repos"
            "supercharged-git-commitizen"
            "supercharged-git-delta"
            "supercharged-git-gh"
            "supercharged-git-gh-dash"
            "supercharged-git-gitleaks"
            "supercharged-git-jujutsu"
            "supercharged-git-lazygit"
            "supercharged-git-mergiraf"
            "supercharged-git-multi-account"
            "supercharged-git-pre-commit"
            "supercharged-shell"
            "supercharged-shell-atuin"
            "supercharged-shell-direnv"
            "supercharged-shell-fzf"
            "supercharged-shell-nix-init"
            "supercharged-shell-nix-search-tv"
            "supercharged-shell-nix-your-shell"
            "supercharged-shell-television"
            "supercharged-shell-yazi"
            "supercharged-shell-zoxide"
            "terminal-velocity"
            "terminal-velocity-eternal-terminal"
            "terminal-velocity-kitty"
            "terminal-velocity-mosh"
            "terminal-velocity-sesh"
            "terminal-velocity-tmux"
            "terminal-velocity-wezterm"
            "terminal-velocity-zellij"
          ];
        };

        test-home-configurations-exist-for-registered-users = {
          expr = builtins.attrNames self.homeConfigurations;
          expected = [
            "ank@rogue"
            "kumarank@darwin001"
          ];
        };
      };
    };
}
