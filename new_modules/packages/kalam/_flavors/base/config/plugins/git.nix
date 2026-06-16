{ pkgs, ... }:
{
  # ── Gutter hunks ──────────────────────────────────────────────────
  plugins.gitsigns = {
    enable = true;
    settings = {
      # The "rich diff while editing" features all default OFF —
      # the gutter sign is enough for daily editing, and turning
      # all of these on by default makes the editor noisy.
      # Toggle the bundle on/off with <leader>ug; inline blame
      # has its own toggle on <leader>ub.
      linehl = false;             # tint the whole changed line
      numhl  = false;             # tint just the line-number column
      word_diff = false;          # word-level highlight within the line
      current_line_blame = false; # author/commit virt-text after idle
      signs = {
        add.text          = "▎";
        change.text       = "▎";
        delete.text       = "";
        topdelete.text    = "";
        changedelete.text = "▎";
        untracked.text    = "▎";
      };
      signs_staged = {
        add.text          = "▎";
        change.text       = "▎";
        delete.text       = "";
        topdelete.text    = "";
        changedelete.text = "▎";
      };
    };
  };

  # ── Repo-level git: magit-style popups for commit / merge / push ──
  # `integrations.diffview = true` makes `d` inside the status buffer
  # open the diffview UI instead of the built-in 2-pane diff.
  plugins.neogit = {
    enable = true;
    settings = {
      kind = "tab";                         # full-tab status buffer
      graph_style = "unicode";
      disable_insert_on_commit = "auto";    # don't force insert mode
      integrations = {
        diffview = true;
        snacks = true;                      # use snacks.input/select prompts
      };
      sections = {
        # Default everything to unfolded so a freshly-opened status
        # buffer shows actionable work without extra <Tab> presses.
        untracked.folded = false;
        unstaged.folded  = false;
        staged.folded    = false;
        stashes.folded   = true;
        unpulled_upstream.folded = true;
        unmerged_upstream.folded = false;
        recent.folded    = true;
      };
    };
  };

  # ── Side-by-side diffs + file history ─────────────────────────────
  # diffview's defaults are good — we just enable it. Repo-level
  # actions go through neogit (which calls into diffview); the
  # standalone keymaps below cover the cases neogit doesn't, like
  # "show me just this one file's history".
  plugins.diffview.enable = true;

  # ── GitHub: issues, PRs, reviews, comments ────────────────────────
  # `picker = "snacks"` reuses the same picker UX as <leader>ff etc.
  # so issue/PR pickers feel native, not bolted on. `gh` CLI must be
  # authenticated (`gh auth login`) — octo shells out to it.
  plugins.octo = {
    enable = true;
    settings = {
      picker = "snacks";
      enable_builtin = true;
      use_local_fs = false;
      default_remote = [ "upstream" "origin" ];
    };
  };

  # gh is octo's transport; gitsigns/neogit need git on PATH.
  extraPackages = [ pkgs.gh pkgs.git ];

  # ── Smart diffview toggle + gitsigns rich view ────────────────────
  # Diffview has no built-in toggle — querying lib.get_current_view()
  # lets us close-if-open / open-otherwise from a single keystroke.
  #
  # The two Snacks.toggle.new bundles below register `<leader>uG`
  # and `<leader>uB` with snacks so they appear in which-key and
  # get a notification with the new state when toggled. The "rich"
  # bundle flips three gitsigns features at once because they're
  # always wanted together:
  #
  #   linehl       — tint changed lines so they pop in context
  #   word_diff    — highlight the bytes that actually changed
  #   toggle_deleted — show deleted lines as virt-text in place
  #
  # That last one is the answer to "I can see I added stuff but
  # what did I delete?" — the removed lines render in red where
  # they used to be, without taking up real buffer rows.
  extraConfigLua = ''
    _G.kalam_diffview_toggle = function()
      local ok, lib = pcall(require, "diffview.lib")
      if ok and lib.get_current_view() then
        vim.cmd("DiffviewClose")
      else
        vim.cmd("DiffviewOpen")
      end
    end

    -- Defer until snacks + gitsigns are both loaded; safe inside
    -- a VimEnter callback because both load synchronously at start.
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        local ok_snacks, Snacks = pcall(function() return _G.Snacks end)
        if not ok_snacks or not Snacks or not Snacks.toggle then return end

        Snacks.toggle.new({
          id = "gitsigns-rich",
          name = "git inline diff",
          get = function() return vim.g.kalam_gitsigns_rich == true end,
          set = function(state)
            vim.g.kalam_gitsigns_rich = state
            local ok, gs = pcall(require, "gitsigns")
            if not ok then return end
            -- gitsigns toggles accept a bool to force a state.
            gs.toggle_linehl(state)
            gs.toggle_word_diff(state)
            gs.toggle_deleted(state)
          end,
        }):map("<leader>ug")

        Snacks.toggle.new({
          id = "gitsigns-blame",
          name = "git inline blame",
          get = function() return vim.g.kalam_gitsigns_blame == true end,
          set = function(state)
            vim.g.kalam_gitsigns_blame = state
            local ok, gs = pcall(require, "gitsigns")
            if not ok then return end
            gs.toggle_current_line_blame(state)
          end,
        }):map("<leader>ub")
      end,
    })
  '';

  keymaps =
    let
      gh = key: action: desc: {
        mode = "n";
        inherit key;
        action = ":Gitsigns ${action}<cr>";
        options = { silent = true; inherit desc; };
      };
      ghv = key: action: desc: {
        mode = [ "n" "v" ];
        inherit key;
        action = ":Gitsigns ${action}<cr>";
        options = { silent = true; inherit desc; };
      };
      cmd = key: action: desc: {
        mode = "n";
        inherit key;
        action = "<cmd>${action}<cr>";
        options = { silent = true; inherit desc; };
      };
      cmdv = key: action: desc: {
        mode = [ "n" "v" ];
        inherit key;
        action = "<cmd>${action}<cr>";
        options = { silent = true; inherit desc; };
      };
    in
    [
      # ── gitsigns: hunk navigation + per-hunk ops ──────────────────
      (gh  "]h"           "next_hunk"          "next hunk")
      (gh  "[h"           "prev_hunk"          "prev hunk")
      (ghv "<leader>ghs"  "stage_hunk"         "stage hunk")
      (ghv "<leader>ghr"  "reset_hunk"         "reset hunk")
      (gh  "<leader>ghS"  "stage_buffer"       "stage buffer")
      (gh  "<leader>ghR"  "reset_buffer"       "reset buffer")
      (gh  "<leader>ghu"  "undo_stage_hunk"    "undo stage hunk")
      (gh  "<leader>ghp"  "preview_hunk"       "preview hunk")
      (gh  "<leader>ghb"  "blame_line"         "blame line")
      (gh  "<leader>ghd"  "diffthis"           "diff this")

      # ── neogit: status / commit / merge / push / rebase ───────────
      # `<leader>gg` mirrors what lazygit had — a single keystroke
      # into the full git UI. From the status buffer, magit-style
      # single-letter popups handle the rest:
      #   c = commit · p = pull · P = push · m = merge ·
      #   r = rebase · b = branch · l = log · Z = stash · ? = help
      # The leader-bindings below preempt the most common popups so
      # you can go straight there without opening status first.
      (cmd "<leader>gg"  "Neogit"                       "neogit status")
      (cmd "<leader>gc"  "Neogit commit"                "commit")
      (cmd "<leader>gp"  "Neogit pull"                  "pull")
      (cmd "<leader>gP"  "Neogit push"                  "push")
      (cmd "<leader>gm"  "Neogit merge"                 "merge")
      (cmd "<leader>gR"  "Neogit rebase"                "rebase")
      (cmd "<leader>gB"  "Neogit branch"                "branch")
      (cmd "<leader>gz"  "Neogit stash"                 "stash")
      (cmd "<leader>gl"  "Neogit log"                   "log")

      # ── diffview: side-by-side + file history ─────────────────────
      # Toggle-style binding for the common case: hit <leader>gdd to
      # enter the working-tree-vs-HEAD diff, hit it again to leave.
      # <leader>gdf is the answer to "let me see just this file's
      # history across the repo" — the canonical single-file flow.
      {
        mode = "n";
        key = "<leader>gdd";
        action.__raw = "function() _G.kalam_diffview_toggle() end";
        options = { silent = true; desc = "diff toggle"; };
      }
      (cmd "<leader>gdo"  "DiffviewOpen"                 "open")
      (cmd "<leader>gdc"  "DiffviewClose"                "close")
      (cmd "<leader>gdh"  "DiffviewFileHistory"          "repo history")
      (cmd "<leader>gdf"  "DiffviewFileHistory %"        "this file's history")
      (cmd "<leader>gdr"  "DiffviewRefresh"              "refresh")
      (cmd "<leader>gdF"  "DiffviewToggleFiles"          "toggle file panel")

      # ── octo: GitHub issues, PRs, reviews ─────────────────────────
      # Octo's command surface is `Octo <noun> <verb>`; the bindings
      # below cover the high-traffic verbs. For anything else, run
      # `:Octo` and tab-complete — the command tree is discoverable.
      #
      # Issues
      (cmd "<leader>goi"  "Octo issue list"              "issues: list")
      (cmd "<leader>goI"  "Octo issue create"            "issues: create")
      (cmd "<leader>gos"  "Octo issue search"            "issues: search")
      # Pull requests
      (cmd "<leader>gop"  "Octo pr list"                 "PRs: list")
      (cmd "<leader>goP"  "Octo pr create"               "PRs: create")
      (cmd "<leader>goS"  "Octo pr search"               "PRs: search")
      (cmd "<leader>gor"  "Octo review start"            "PRs: start review")
      (cmd "<leader>goR"  "Octo review resume"           "PRs: resume review")
      (cmd "<leader>gof"  "Octo review submit"           "PRs: submit review")
      (cmd "<leader>gom"  "Octo pr merge"                "PRs: merge")
      (cmd "<leader>goh"  "Octo pr checkout"             "PRs: checkout")
      # Comments — work in normal & visual (visual = comment on
      # selected lines from inside a diff review).
      (cmdv "<leader>goc" "Octo comment add"             "comment: add")
      (cmd "<leader>goC"  "Octo comment delete"          "comment: delete")
      # Reactions on the comment/issue under cursor
      (cmd "<leader>go+"  "Octo reaction thumbs_up"      "react: +1")
      (cmd "<leader>go-"  "Octo reaction thumbs_down"    "react: -1")
    ];
}
