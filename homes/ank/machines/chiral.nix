{
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ../home.nix
    ../../common/home_manager.nix
    ../../common/dev
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
    ../../common/gpu_tools.nix
    ../../common/dev/kalam.nix
    ../../common/themes
  ];

  programs.zsh.initContent = ''
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/wsl/lib
  '';

  programs.git.extraConfig = {
    safe.directory = "*";
  };
}
