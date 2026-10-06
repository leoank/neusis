{
  username,
  userEmail,
  id_ed25519_pub,
  ...
}:
{

  home.file.".ssh/allowed_signers".text = "* ${id_ed25519_pub}";
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = username;
        email = userEmail;
        signingkey = "~/.ssh/id_ed25519.pub";
      };
      commit.gpgsign = true;
      gpg = {
        format = "ssh";
        ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      };
    };
  };
}
