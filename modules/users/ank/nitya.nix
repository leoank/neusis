# nitya's node for ank (nitya ADR-0016): `nitya-node` on PATH with this machine's settings,
# and an hourly check of the account's audit log against this device's checkpoint, which
# also renews its certificate. The module is the nitya flake's (`homeModules.node`; the
# input is declared in features/nixos/nitya-token-probe.nix). The node reaches the server
# as `nitya:7300` on anklab's leoank tailnet through a tsnet identity of its own; enroll it
# once with a code from `nitya-admin enroll-code --account ank` on ghost001.
{ ... }:
{
  # rogue: the leoank key as a home secret (the `secrets` bundle), at a fixed path since
  # launchd does not expand agenix's default per-user temporary directory.
  flake.neusis.users.ank.hmBundles.nitya-node-rogue =
    { config, inputs, ... }:
    {
      imports = [ inputs.nitya.homeModules.node ];
      age.secrets.nityaNodeTsAuthKey = {
        rekeyFile = ../../secrets/anklab/leoankTsAuthKey.age;
        path = "${config.home.homeDirectory}/.config/nitya/leoank-authkey";
      };
      services.nitya-node = {
        enable = true;
        hostname = "nitya-node-rogue";
        authKeyFile = config.age.secrets.nityaNodeTsAuthKey.path;
      };
    };
}
