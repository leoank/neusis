# supercharged-shell: fzf module.
# Enables `programs.fzf` with the "full" style preset and a
# `bat`-backed file preview. Zsh integration on by default — gives
# you Ctrl-T (paste-from-fuzzy-find), Alt-C (cd-from-fuzzy-find), and
# Ctrl-R (fuzzy history search) bindings.
{ ... }:
{
  flake.homeModules.supercharged-shell-fzf =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.neusis.supercharged-shell.tools.fzf;
    in
    {
      options.neusis.supercharged-shell.tools.fzf = {
        enable = lib.mkEnableOption "fzf fuzzy finder";

        defaultOptions = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "--style full" ];
          description = "Flags appended to `FZF_DEFAULT_OPTS`.";
        };

        fileWidgetOptions = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "--preview='bat --color=always {}'" ];
          description = ''
            Flags for the Ctrl-T file-picker widget. Default uses
            `bat` to syntax-highlight the file under the cursor.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        programs.fzf = {
          enable = true;
          enableZshIntegration = true;
          inherit (cfg) defaultOptions fileWidgetOptions;
        };
      };
    };
}
