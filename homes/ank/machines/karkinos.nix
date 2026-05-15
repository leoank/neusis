{
  pkgs,
  config,
  inputs,
  ...
}:
{
  imports = [
    ../home.nix
    ../../common/home_manager.nix
    ../../common/dev
    ../../common/dev/kalam.nix
    ../../common/themes
    ../configs/agent_harness/cli_agents.nix
    ../configs/terminal/zsh.nix
    ../configs/terminal/tmux.nix
    (import ../../common/dev/editors.nix {
      inherit pkgs config inputs;
      enableNvim = false;
      enableAstro = false;
    })
    (import ../../common/dev/git.nix {
      username = "Ankur Kumar";
      userEmail = "ank@leoank.me";
      id_ed25519_pub = builtins.readFile ../id_ed25519.pub;
    })
    ../../common/secrets
    ../../common/browsers
    ../../common/browsers/brave.nix
    ../../common/network
    ../../common/misc
    ../../common/gpu_tools.nix
  ];

  # programs.gh.package = pkgs.writeBin "gh" ''
  #   GITHUB_TOKEN=''$(cat ${config.age.secrets.ank_github_token.path}) gh
  # '';
}
