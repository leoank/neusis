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
    # ../../common/dev
    # ../../common/dev/kalam.nix
    # ../../common/themes
    # (import ../../common/dev/editors.nix {
    #   inherit pkgs config inputs;
    #   enableNvim = false;
    #   enableAstro = false;
    # })
    (import ../../common/dev/git.nix {
      username = "Alán F. Muñoz";
      userEmail = "amunozgo@broadinstitute.org";
      id_ed25519_pub = builtins.readFile ../id_ed25519.pub;
    })
    ../../common/secrets
    ../../common/browsers
    ../../common/network
    ../../common/misc
    ../../common/gpu_tools.nix
  ];
}
