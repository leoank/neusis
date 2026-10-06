# snacks.nvim is base's "everything UI" toolkit:
#
#   bigfile / quickfile     — performance shortcuts for huge files
#   dashboard               — startup screen
#   indent / scope          — indent guides + current-scope highlight
#   input                   — better vim.ui.input prompts
#   notifier                — replaces nvim-notify
#   picker                  — replaces telescope (with a smaller API)
#   rename                  — keep imports in sync when files rename
#   scratch                 — quick throwaway buffers
#   statuscolumn            — folds + signs + numbers in a clean column
#   terminal                — toggleable floating terminal
#   toggle                  — UI toggles wired to which-key automatically
#   words                   — highlight occurrences of word under cursor
#   zen                     — distraction-free editing
#
# Almost every leader binding below maps to a snacks feature.
{
  plugins.snacks = {
    enable = true;
    settings = {
      bigfile = {
        enabled = true;
        notify = true;
      };
      quickfile.enabled = true;

      dashboard = {
        enabled = true;
        preset = {
          # snacks centers each header line INDIVIDUALLY based on
          # its visible length — so lines of different length get
          # different left-pad, and any vertical column in the art
          # drifts. Pad every line to the same width here (in Lua,
          # via __raw, so backslashes only need one level of
          # escaping instead of two).
          header.__raw = ''
            (function()
              local lines = {
                ".-.__      \\ .-.  ___  __",
                "|_|  '--.-.-(   \\/\\;;\\_\\.-._______.-.",
                "(-)___     \\ \\ .-\\ \\;;\\(   \\       \\ \\",
                " Y    '---._\\_((Q)) \\;;\\\\ .-\\     __(_)",
                " I           __'-' / .--.((Q))---'    \\",
                " I     ___.-:    \\|  |   \\'-'_          \\",
                " A  .-'      \\ .-.\\   \\   \\ \\ '--.__     '\\",
                " |  |____.----((Q))\\   \\__|--\\_      \\     '",
                "    ( )        '-'  \\_  :  \\-' '--.___\\",
                "     Y                \\  \\  \\       \\(_)",
                "     I                 \\  \\  \\         \\",
                "     I                  \\  \\  \\          \\",
                "     A                   \\  \\  \\          '\\",
                "     |              kalam \\  \\__|           '",
                "                           \\_:.  \\",
                "                             \\ \\  \\",
                "                              \\ \\  \\",
                "                               \\_\\_|",
              }
              local max = 0
              for _, l in ipairs(lines) do
                if #l > max then max = #l end
              end
              for i, l in ipairs(lines) do
                lines[i] = l .. string.rep(" ", max - #l)
              end
              return table.concat(lines, "\n")
            end)()
          '';

          # Override the default key list so we drop the `L = :Lazy`
          # entry — kalam doesn't use lazy.nvim and snacks's
          # `enabled = …lazy` gate has tripped in some versions.
          keys = [
            { icon = " "; key = "f"; desc = "find file"; action = ":lua Snacks.dashboard.pick('files')"; }
            { icon = " "; key = "n"; desc = "new file"; action = ":ene | startinsert"; }
            { icon = " "; key = "g"; desc = "grep"; action = ":lua Snacks.dashboard.pick('live_grep')"; }
            { icon = " "; key = "r"; desc = "recent files"; action = ":lua Snacks.dashboard.pick('oldfiles')"; }
            # mini.sessions: lowercase `s` loads the session whose name
            # matches the cwd basename (paired with `<leader>qs` save).
            # Uppercase `S` opens the picker so you can grab any saved
            # session — useful when launching nvim from $HOME.
            { icon = " "; key = "s"; desc = "load session"; action = ":lua require('mini.sessions').read(vim.fs.basename(vim.uv.cwd()))"; }
            { icon = " "; key = "S"; desc = "select session"; action = ":lua require('mini.sessions').select()"; }
            { icon = " "; key = "c"; desc = "config"; action = ":lua Snacks.dashboard.pick('files', { cwd = vim.fn.stdpath('config') })"; }
            { icon = " "; key = "q"; desc = "quit"; action = ":qa"; }
          ];
        };

        # Replace snacks's `startup` section (it calls
        # `require('lazy.status')`) with a function-section that
        # reads vim.g.kalam_loaded_ms set by the VimEnter autocmd
        # in extraConfigLuaPre. The whole section is the function
        # (not text-as-function inside a section), so snacks
        # resolves it once at render time and gets a static
        # segment table.
        #
        # `projects` is dropped — without a project provider
        # plugin it's the most likely section to render badly.
        sections = [
          { section = "header"; }
          { section = "keys"; gap = 0; padding = 1; }
          { section = "recent_files"; padding = 1; }
          {
            __raw = ''
              function()
                return {
                  align = "center",
                  text = {
                    { "⚡ neovim ready in ", hl = "Special" },
                    { tostring(vim.g.kalam_loaded_ms or 0), hl = "Number" },
                    { " ms", hl = "Special" },
                  },
                }
              end
            '';
          }
        ];
      };

      # Inline image rendering — markdown previews, image-file
      # buffers, hover/preview popups. Uses the terminal graphics
      # protocol (kitty / wezterm support it natively, iTerm via
      # tic). Falls back to a placeholder block on unsupported
      # terminals so nothing visually breaks.
      image.enabled = true;

      indent = {
        enabled = true;
        animate.enabled = false;
        scope.enabled = true;
      };

      input.enabled = true;
      notifier = {
        enabled = true;
        timeout = 3000;
      };

      picker.enabled = true;
      rename.enabled = true;
      scratch.enabled = true;
      scope.enabled = true;
      statuscolumn.enabled = true;
      terminal.enabled = true;
      toggle.enabled = true;
      words.enabled = true;
      zen.enabled = true;
    };
  };

  # Wire vim.g.kalam_loaded_ms for the dashboard footer. Capture
  # start time before any plugin loads; compute elapsed on VimEnter.
  extraConfigLuaPre = ''
    _G.kalam_start_time = (vim.uv or vim.loop).hrtime()
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        local elapsed = (vim.uv or vim.loop).hrtime() - _G.kalam_start_time
        vim.g.kalam_loaded_ms = math.floor(elapsed / 1e6)
      end,
    })
  '';

  keymaps =
    let
      # Tiny helper — every snacks binding wants the same shape and
      # repeating `mode = "n"; options.desc = …;` got noisy.
      snacks = key: action: desc: {
        mode = "n";
        inherit key;
        action = "<cmd>lua Snacks.${action}<cr>";
        options = { silent = true; inherit desc; };
      };
    in
    [
      # --- pickers ---
      (snacks "<leader>,"    "picker.buffers()"           "buffers")
      (snacks "<leader>:"    "picker.command_history()"   "command history")
      (snacks "<leader>/"    "picker.grep()"              "grep")
      (snacks "<leader>ff"   "picker.files()"             "files")
      (snacks "<leader>fb"   "picker.buffers()"           "buffers")
      (snacks "<leader>fg"   "picker.git_files()"         "git files")
      (snacks "<leader>fr"   "picker.recent()"            "recent files")
      (snacks "<leader>fh"   "picker.help()"              "help")
      (snacks "<leader>fk"   "picker.keymaps()"           "keymaps")
      (snacks "<leader>fc"   "picker.commands()"          "commands")
      (snacks "<leader>fn"   "picker.notifications()"     "notifications")

      # --- search ---
      (snacks "<leader>sg"   "picker.grep()"              "grep workspace")
      (snacks "<leader>sw"   "picker.grep_word()"         "word under cursor")
      (snacks "<leader>sd"   "picker.diagnostics()"       "diagnostics")
      (snacks "<leader>ss"   "picker.lsp_symbols()"       "lsp symbols")
      (snacks "<leader>sS"   "picker.lsp_workspace_symbols()" "lsp workspace symbols")
      (snacks "<leader>sr"   "picker.resume()"            "resume last picker")
      (snacks "<leader>sm"   "picker.marks()"             "marks")
      (snacks "<leader>sq"   "picker.qflist()"            "quickfix list")
      (snacks "<leader>sj"   "picker.jumps()"             "jumps")
      (snacks "<leader>su"   "picker.undo()"              "undo tree")

      # --- code ---
      (snacks "<leader>cR"   "rename.rename_file()"       "rename file")

      # explorer/files removed from snacks — see files.nix
      # (yazi for browsing, oil for editing names).

      # --- git ---
      # Repo-level UI lives in git.nix (neogit/diffview/octo).
      # snacks still owns the two things it does best:
      #   <leader>gb   — line blame popup (faster than :Gitsigns blame_line)
      #   <leader>gW   — open the current line on the git web host
      (snacks "<leader>gb"   "git.blame_line()"           "blame line (popup)")
      (snacks "<leader>gW"   "gitbrowse()"                "browse on remote")

      # --- terminal / tab ---
      (snacks "<leader>tt"   "terminal()"                 "toggle terminal")

      # --- ui toggles ---
      # snacks.toggle wires these into which-key automatically when
      # `Snacks.toggle.<name>():map("<leader>uX")` runs. We declare
      # them here so they're discoverable from one place.
      (snacks "<leader>un"   "toggle.line_number():toggle()"       "line numbers")
      (snacks "<leader>ur"   "toggle.option('relativenumber'):toggle()"
                                                                    "relative numbers")
      (snacks "<leader>uw"   "toggle.option('wrap'):toggle()"        "wrap")
      (snacks "<leader>us"   "toggle.option('spell'):toggle()"       "spell")
      (snacks "<leader>uh"   "toggle.inlay_hints():toggle()"         "inlay hints")
      (snacks "<leader>ud"   "toggle.diagnostics():toggle()"         "diagnostics")
      (snacks "<leader>ui"   "toggle.indent():toggle()"              "indent guides")
      (snacks "<leader>uD"   "toggle.dim():toggle()"                 "dim")
      (snacks "<leader>uT"   "toggle.treesitter():toggle()"          "treesitter")

      # --- zen ---
      (snacks "<leader>zz"   "zen()"                      "zen mode")
      (snacks "<leader>zZ"   "zen.zoom()"                 "zoom buffer")

      # --- scratch ---
      (snacks "<leader>."    "scratch()"                  "scratch buffer")
      (snacks "<leader>S"    "scratch.select()"           "select scratch")

      # --- notifications ---
      (snacks "<leader>n"    "notifier.show_history()"    "notification history")

      # --- quit ---
      {
        mode = "n";
        key = "<leader>qq";
        action = "<cmd>qa<cr>";
        options.desc = "quit all";
      }
      {
        mode = "n";
        key = "<leader>qQ";
        action = "<cmd>qa!<cr>";
        options.desc = "quit all (force)";
      }
    ];

}
