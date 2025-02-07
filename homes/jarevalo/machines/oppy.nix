{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ../home.nix
    ../../common/home_manager.nix
    ../../common/dev
    (import ../../common/dev/editors.nix {
      inherit pkgs config inputs;
      enableNvim = true;
      enableAstro = false;
    })
    (import ../../common/dev/git.nix {
      username = "John Arevalo";
      userEmail = "johnarevalo@gmail.com";
      id_ed25519_pub = builtins.readFile ../id_ed25519.pub;
    })
    ../../common/browsers
    ../../common/network
    ../../common/misc
    ../../common/secrets
  ];
}
