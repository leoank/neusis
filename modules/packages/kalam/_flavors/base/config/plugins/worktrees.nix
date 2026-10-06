# worktrees.nvim — git worktree manager (create / delete / switch).
#
# Why this and not git-worktree.nvim (ThePrimeagen / polarmutex)? Two
# practical wins:
#
#   * `switch` keeps your cursor/buffer in the same logical file —
#     so jumping `main → feature-x → main` doesn't lose your place.
#   * Hooks (`on_create`/`on_delete`/`on_switch`) and configurable
#     `:WorktreeCreate` / `:WorktreeDelete` / `:WorktreeSwitch`
#     commands are first-class. No telescope dependency either.
#
# Not in nixpkgs.vimPlugins, so we build it inline from upstream
# rather than carrying an overlay. Rev is pinned; bump by running
# `nix flake prefetch github:afonsofrancof/worktrees.nvim` and
# pasting the new hash here.
{ pkgs, ... }:
let
  worktrees-nvim = pkgs.vimUtils.buildVimPlugin {
    pname = "worktrees-nvim";
    version = "2026-06-17";
    src = pkgs.fetchFromGitHub {
      owner = "afonsofrancof";
      repo = "worktrees.nvim";
      rev = "bd3bb6db01aee69775b8d237dcb50d66d96d2d68";
      hash = "sha256-L6M6PuIdrhK/vGq6sR8GJfddc0v+cFnVHv0OCSIL//g=";
    };
  };
in
{
  extraPlugins = [ worktrees-nvim ];

  # Sensible defaults: worktrees go in a sibling directory to the
  # git common dir, named after the branch. Hooks left unset —
  # add them per-project if you want post-create scaffolding.
  extraConfigLua = ''
    require("worktrees").setup({
      base_path = "..",
      path_template = "{branch}",
    })
  '';

  keymaps =
    let
      wt = key: action: desc: {
        mode = "n";
        inherit key;
        action = "<cmd>${action}<cr>";
        options = { silent = true; inherit desc; };
      };
    in
    [
      # All worktree ops live under <leader>gw — sits alongside
      # <leader>gd (diffview), <leader>gh (hunks), <leader>go (github).
      (wt "<leader>gwc"  "WorktreeCreate"  "worktree: create")
      (wt "<leader>gwd"  "WorktreeDelete"  "worktree: delete")
      (wt "<leader>gws"  "WorktreeSwitch"  "worktree: switch")
    ];
}
