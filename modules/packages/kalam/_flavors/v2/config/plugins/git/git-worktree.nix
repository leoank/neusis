{ pkgs, ... }:
{

  extraPlugins = [
    pkgs.git-worktree-custom
  ];

  plugins.git-worktree = {
    enable = false;
    package = pkgs.git-worktree-custom;
    enableTelescope = true;
  };
  keymaps = [
    {
      mode = "n";
      key = "<leader>fg";
      action = ":Telescope git_worktree<CR>";
      options = {
        desc = "Git Worktree";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>gwc";
      action.__raw = ''
        function()
          require('telescope').extensions.git_worktree.create_git_worktree()
        end
      '';
      options = {
        desc = "Create worktree";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>gws";
      action.__raw = ''
        function()
          require('telescope').extensions.git_worktree.git_worktree()
        end
      '';
      options = {
        desc = "Switch / Delete worktree";
        silent = true;
      };
    }

  ];
}
