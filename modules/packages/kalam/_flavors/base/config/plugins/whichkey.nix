# which-key is base's discoverability spine. Every `<leader>X` letter
# used elsewhere must have its group label declared here so the popup
# is self-describing — `<leader>` alone shows the whole map.
#
# Individual bindings live with their plugin (snacks.nix, mini.nix,
# git.nix, etc.) — never declare a binding here.
{
  plugins.which-key = {
    enable = true;

    settings = {
      preset = "modern";
      delay = 200;

      icons = {
        breadcrumb = "»";
        group = "+";
        separator = "";
      };

      win = {
        border = "rounded";
        padding = [ 1 1 ];
      };

      spec = [
        { __unkeyed-1 = "<leader>b"; group = "buffer"; }
        { __unkeyed-1 = "<leader>c"; group = "code"; mode = [ "n" "v" ]; }
        { __unkeyed-1 = "<leader>d"; group = "debug"; }
        { __unkeyed-1 = "<leader>dP"; group = "python"; }
        { __unkeyed-1 = "<leader>f"; group = "find/file"; }
        { __unkeyed-1 = "<leader>g"; group = "git"; mode = [ "n" "v" ]; }
        { __unkeyed-1 = "<leader>gd"; group = "diffview"; }
        { __unkeyed-1 = "<leader>gh"; group = "hunks"; mode = [ "n" "v" ]; }
        { __unkeyed-1 = "<leader>go"; group = "github (octo)"; mode = [ "n" "v" ]; }
        { __unkeyed-1 = "<leader>gw"; group = "worktrees"; }
        { __unkeyed-1 = "<leader>q"; group = "quit/session"; }
        { __unkeyed-1 = "<leader>s"; group = "search"; }
        { __unkeyed-1 = "<leader>t"; group = "terminal/tab"; }
        { __unkeyed-1 = "<leader>u"; group = "toggles"; }
        { __unkeyed-1 = "<leader>w"; group = "window"; proxy = "<c-w>"; }
        { __unkeyed-1 = "<leader>x"; group = "trouble"; }
        { __unkeyed-1 = "<leader>z"; group = "zen"; }

        # Non-leader prefix group: `gs` is mini.surround (moved
        # from `s*` because leap.nvim took `s`/`S`).
        { __unkeyed-1 = "gs"; group = "surround"; mode = [ "n" "x" ]; }
      ];
    };
  };
}
