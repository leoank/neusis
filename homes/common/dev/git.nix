{
  username,
  userEmail,
  id_ed25519_pub,
  ...
}:
{
  imports = [ ./git_clone_bare.nix ];
  home.file.".ssh/allowed_signers".text = "* ${id_ed25519_pub}";
  programs.git = {
    enable = true;
    lfs.enable = true;
    userName = username;
    userEmail = userEmail;
    extraConfig = {
      # Sign all commits using ssh key
      commit.gpgsign = true;
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      user.signingkey = "~/.ssh/id_ed25519.pub";
    };
  };
}
