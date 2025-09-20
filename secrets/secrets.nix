let
  # User keys
  ank = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH40XzfXPtcTwJ8FHxHXCaEteylFOwtuw5TaY5CZ5NS ank@leoank.me";
  shantanu = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/6FQiQUwpJ6TJyPolx+B4oB/b8wBvLQ08Bgm4VUAKs shsingh@broadinstitute.org";

  users = [
    ank
    shantanu
  ];

  # Machine keys
  karkinos = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINidmZsZlAone6QTsgkeRHzk3GsIMxCXI0RL53aRDMce";
  oppy = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINCW3CZ4r7VhI7+4rC+oOE4n3AMXEy3F2vm8jjHeTClR";

  machines = [
    karkinos
    oppy
  ];
in
{
  # Common
  "common/persistent_tsauthkey.age".publicKeys = users ++ machines;
  "common/persistent_tsapikey.age".publicKeys = users ++ machines;
  "common/persistent_tsapiid.age".publicKeys = users ++ machines;
  "common/ephemeral_tsauthkey.age".publicKeys = users ++ machines;
  "common/hashedInitialPassword.age".publicKeys = users ++ machines;
  "common/tsclient.age".publicKeys = users ++ machines;
  "common/tssecret.age".publicKeys = users ++ machines;

  # Oppy
  "oppy/anywhere/etc/ssh/ssh_host_ed25519_key.age".publicKeys = [
    ank
    shantanu
    oppy
  ];
  "oppy/tsauthkey.age".publicKeys = users ++ machines;
  "oppy/alloy_key.age".publicKeys = [
    ank
    shantanu
    oppy
  ];

  # ank
  "ank/ghauth.age".publicKeys = [ ank ];

  "common/persistent_cslab_mesh.age".publicKeys = machines;
}
