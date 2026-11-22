# sandhi — each machine on ank's leoank tailnet through a tsnet identity of its own (a
# dutavas), whatever tailnet its system tailscaled is on (ADR-0021). The daemon is the
# sandhi flake's home-manager module (sandhi ADR-0006): `sandhi up` as a launchd agent or
# systemd user service, `sandhi` on PATH.
#
# Every machine publishes its sshd into leoank (22 -> 127.0.0.1:22) and reaches leoank's
# peers as `<peer>.leoank` through `ProxyCommand sandhi connect %h %p`, written to
# ~/.ssh/config.d/sandhi. A home whose ssh config home-manager manages includes it; rogue's
# ~/.ssh/config is hand-written and includes it by hand (`Include config.d/*` at the top).
#
# On leoank each dutavas is `sandhi-<host>`, so an old device keeping the bare host name
# never takes it from it: `ssh sandhi-ghost001.leoank`. The system tailnet (runxi on all
# three today) is not a sandhi backend: those peers stay reachable as before.
{ self, ... }:
{
  flake-file.inputs.sandhi = {
    url = "github:leoank/sandhi";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
    # The notebook CLI of its dev shell and checks; ours (users/ank/ank.nix).
    inputs.yajna.follows = "yajna";
  };

  # What every machine shares; the machine's bundle below adds its name and its key.
  flake.neusis.users.ank.hmBundles.sandhi =
    {
      config,
      inputs,
      lib,
      ...
    }:
    {
      imports = [ inputs.sandhi.homeModules.sandhi ];

      services.sandhi = {
        enable = true;
        backends.leoank = {
          forwards = [
            {
              port = 22;
              to = "127.0.0.1:22";
            }
          ];
          tailnet = { };
        };
      };

      # The binary by its store path: ssh may run from a GUI app without the profile on PATH.
      home.file.".ssh/config.d/sandhi".text = ''
        Host *.leoank
          ProxyCommand ${lib.getExe config.services.sandhi.package} connect %h %p
      '';
      programs.ssh.includes = [ "config.d/sandhi" ];
    };

  # rogue: the leoank key as a home secret (the `secrets` bundle), at a fixed path since
  # launchd does not expand agenix's default per-user temporary directory.
  flake.neusis.users.ank.hmBundles.sandhi-rogue =
    { config, ... }:
    {
      imports = [ self.neusis.users.ank.hmBundles.sandhi ];
      age.secrets.sandhiLeoankTsAuthKey = {
        rekeyFile = ../../secrets/anklab/leoankTsAuthKey.age;
        path = "${config.home.homeDirectory}/.config/sandhi/leoank-authkey";
      };
      services.sandhi.backends.leoank.tailnet = {
        hostname = "sandhi-rogue";
        authKeyFile = config.age.secrets.sandhiLeoankTsAuthKey.path;
      };
    };

  # ghost001: no home secrets there; the key is a system secret owned by ank
  # (machines/ghost001.nix), decrypted at activation, before the lingering user services.
  flake.neusis.users.ank.hmBundles.sandhi-ghost001 = {
    imports = [ self.neusis.users.ank.hmBundles.sandhi ];
    services.sandhi.backends.leoank.tailnet = {
      hostname = "sandhi-ghost001";
      authKeyFile = "/run/agenix/sandhiLeoankTsAuthKey";
    };
  };

  # curiosity: the live disk loses the dutavas's state at every reboot and joins anew, so the
  # identity is ephemeral and the tailnet drops each old one instead of keeping it offline.
  # The key is a home secret (secrets-curiosity), decrypted by the agenix user unit, which a
  # fresh join needs: start after it.
  flake.neusis.users.ank.hmBundles.sandhi-curiosity =
    { config, ... }:
    {
      imports = [ self.neusis.users.ank.hmBundles.sandhi ];
      age.secrets.sandhiLeoankTsAuthKey = {
        rekeyFile = ../../secrets/anklab/leoankTsAuthKey.age;
        path = "${config.home.homeDirectory}/.config/sandhi/leoank-authkey";
      };
      services.sandhi.backends.leoank.tailnet = {
        hostname = "sandhi-curiosity";
        authKeyFile = config.age.secrets.sandhiLeoankTsAuthKey.path;
        ephemeral = true;
      };
      systemd.user.services.sandhi.Unit = {
        Wants = [ "agenix.service" ];
        After = [ "agenix.service" ];
      };
    };
}
