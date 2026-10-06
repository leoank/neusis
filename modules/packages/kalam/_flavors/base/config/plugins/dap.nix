# Debug Adapter Protocol stack.
#
#   * nvim-dap          — the core DAP client (breakpoints, stepping,
#                          variable inspection through the protocol)
#   * nvim-dap-view     — the UI. Newer alternative to nvim-dap-ui;
#                          smaller API, more recent, picks up on dap
#                          events automatically.
#   * nvim-dap-python   — Python adapter. Ships debugpy via a nixpkgs
#                          python3.withPackages so no imperative
#                          install is required.
#
# All configuration goes through nixvim's native plugin options —
# no extraConfigLua. Sign highlights come from catppuccin's dap
# integration (enabled in theme.nix).
{ pkgs, ... }:
let
  pythonWithDebugpy = pkgs.python3.withPackages (p: [ p.debugpy ]);
in
{
  plugins = {
    dap = {
      enable = true;
      signs = {
        dapBreakpoint = {
          text = "●";
          texthl = "DapBreakpoint";
        };
        dapBreakpointCondition = {
          text = "◆";
          texthl = "DapBreakpointCondition";
        };
        dapBreakpointRejected = {
          text = "◌";
          texthl = "DapBreakpointRejected";
        };
        dapLogPoint = {
          text = "◆";
          texthl = "DapLogPoint";
        };
        dapStopped = {
          text = "→";
          texthl = "DapStopped";
          linehl = "Visual";
        };
      };
    };

    # auto_toggle: opens dap-view automatically on session start
    # and closes it when the session ends. No manual <leader>du.
    dap-view = {
      enable = true;
      settings.auto_toggle = true;
    };

    # dap-python registers its `Launch file` / `Launch file with
    # arguments` / `Attach remote` / `Run doctests in file` configs
    # plus the test_method/test_class/debug_selection helpers.
    dap-python = {
      enable = true;
      adapterPythonPath = "${pythonWithDebugpy}/bin/python";
    };

    # Inline variable values as virtual text while stepping. Shows
    # `= <value>` after the line where a variable is assigned /
    # referenced. Complements dap-view's scopes pane — you see
    # values where you're reading code, not just where the panel is.
    dap-virtual-text = {
      enable = true;
      settings = {
        enabled = true;
        enabled_commands = true;
        # Highlight values that changed since the last stop —
        # makes step-through visually obvious.
        highlight_changed_variables = true;
        highlight_new_as_changed = false;
        # Annotate the line that hit a breakpoint with the reason.
        show_stop_reason = true;
        commented = false;
        # Skip subsequent references; only annotate the first
        # definition of each var in scope. Keeps lines uncluttered.
        only_first_definition = true;
        all_references = false;
        # `eol` keeps annotations at the end of the line so they
        # don't shift code positions. `inline` overlays values
        # in-place if you'd rather.
        virt_text_pos = "eol";
      };
    };
  };

  extraPackages = [ pythonWithDebugpy ];

  keymaps = [
    # --- session lifecycle ---
    {
      mode = "n";
      key = "<leader>dc";
      action.__raw = "function() require('dap').continue() end";
      options.desc = "continue / start";
    }
    {
      mode = "n";
      key = "<leader>dl";
      action.__raw = "function() require('dap').run_last() end";
      options.desc = "run last";
    }
    {
      mode = "n";
      key = "<leader>dt";
      action.__raw = "function() require('dap').terminate() end";
      options.desc = "terminate";
    }
    {
      mode = "n";
      key = "<leader>dp";
      action.__raw = "function() require('dap').pause() end";
      options.desc = "pause";
    }

    # --- stepping ---
    {
      mode = "n";
      key = "<leader>ds";
      action.__raw = "function() require('dap').step_over() end";
      options.desc = "step over";
    }
    {
      mode = "n";
      key = "<leader>di";
      action.__raw = "function() require('dap').step_into() end";
      options.desc = "step into";
    }
    {
      mode = "n";
      key = "<leader>do";
      action.__raw = "function() require('dap').step_out() end";
      options.desc = "step out";
    }
    {
      mode = "n";
      key = "<leader>dC";
      action.__raw = "function() require('dap').run_to_cursor() end";
      options.desc = "run to cursor";
    }

    # --- breakpoints ---
    {
      mode = "n";
      key = "<leader>db";
      action.__raw = "function() require('dap').toggle_breakpoint() end";
      options.desc = "toggle breakpoint";
    }
    {
      mode = "n";
      key = "<leader>dB";
      action.__raw = ''
        function()
          vim.ui.input({ prompt = "breakpoint condition: " }, function(cond)
            if cond then require('dap').set_breakpoint(cond) end
          end)
        end
      '';
      options.desc = "conditional breakpoint";
    }

    # --- inspection ---
    {
      mode = [ "n" "v" ];
      key = "<leader>de";
      action.__raw = "function() require('dap.ui.widgets').hover() end";
      options.desc = "evaluate (hover value)";
    }
    {
      mode = "n";
      key = "<leader>dr";
      action.__raw = "function() require('dap').repl.toggle() end";
      options.desc = "repl";
    }

    # --- ui ---
    {
      mode = "n";
      key = "<leader>du";
      action = "<cmd>DapViewToggle<cr>";
      options.desc = "toggle dap view";
    }

    # --- python-specific (dap-python) ---
    {
      mode = "n";
      key = "<leader>dPm";
      action.__raw = "function() require('dap-python').test_method() end";
      options.desc = "test method (python)";
    }
    {
      mode = "n";
      key = "<leader>dPc";
      action.__raw = "function() require('dap-python').test_class() end";
      options.desc = "test class (python)";
    }
    {
      mode = "v";
      key = "<leader>dPs";
      action.__raw = "function() require('dap-python').debug_selection() end";
      options.desc = "debug selection (python)";
    }

    # --- IDE-familiar F-key aliases ---
    {
      mode = "n";
      key = "<F5>";
      action.__raw = "function() require('dap').continue() end";
      options.desc = "debug: continue";
    }
    {
      mode = "n";
      key = "<F10>";
      action.__raw = "function() require('dap').step_over() end";
      options.desc = "debug: step over";
    }
    {
      mode = "n";
      key = "<F11>";
      action.__raw = "function() require('dap').step_into() end";
      options.desc = "debug: step into";
    }
    {
      mode = "n";
      key = "<F12>";
      action.__raw = "function() require('dap').step_out() end";
      options.desc = "debug: step out";
    }
  ];
}
