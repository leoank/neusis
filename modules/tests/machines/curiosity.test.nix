# Invariants of the real `curiosity` host, a live disk whose secrets all hang on the host key
# copied from SPARKDATA in the initrd: without it the boot stops rather than coming up with no
# password and no secrets.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      cfg = self.nixosConfigurations.curiosity.config;
      unit = cfg.boot.initrd.systemd.services.curiosity-host-key;
      script = cfg.boot.initrd.systemd.contents."/etc/curiosity-host-key.sh".text;
    in
    {
      tests.machine-curiosity = {
        test-missing-host-key-stops-the-boot = {
          expr = {
            requiredBy = unit.requiredBy;
            beforeInitrdTarget = builtins.elem "initrd.target" unit.before;
            beforeActivation = builtins.elem "initrd-nixos-activation.service" unit.before;
            console = unit.serviceConfig.StandardOutput;
            # the emergency shell is reachable on the console
            emergencyAccess = cfg.boot.initrd.systemd.emergencyAccess;
            failsWithoutDrive = lib.hasInfix ''[ -e /dev/disk/by-label/SPARKDATA ] || fail "SPARKDATA not found"'' script;
            failsWithoutKey = lib.hasInfix ''fail "no $k on SPARKDATA"'' script;
            escapeHatch = lib.hasInfix "curiosity.nohostkey" script;
          };
          expected = {
            requiredBy = [ "initrd.target" ];
            beforeInitrdTarget = true;
            beforeActivation = true;
            console = "journal+console";
            emergencyAccess = true;
            failsWithoutDrive = true;
            failsWithoutKey = true;
            escapeHatch = true;
          };
        };

        # A builder for the others, but its own builds stay local (its only aarch64-linux peer
        # is ghost001's two slow slots).
        test-serves-builds-but-keeps-its-own-local = {
          expr = {
            server = cfg.neusis.services.build-server.enable;
            client = cfg.neusis.services.build-client.enable;
            distributed = cfg.nix.distributedBuilds;
            buildMachines = cfg.nix.buildMachines;
          };
          expected = {
            server = true;
            client = false;
            distributed = false;
            buildMachines = [ ];
          };
        };

        # atuin sync: the shared key and session at atuin's own paths (18.15 reads the key
        # from key_path and imports the legacy session file into meta.db), and the daemon
        # waits for agenix, so atuin never makes a key of its own first.
        test-atuin-shares-the-key-and-session = {
          expr =
            let
              h = cfg.home-manager.users.ank;
            in
            {
              key = h.age.secrets.atuinKey.path;
              session = h.age.secrets.atuinSession.path;
              keyFile = baseNameOf h.age.secrets.atuinKey.rekeyFile;
              sessionFile = baseNameOf h.age.secrets.atuinSession.rekeyFile;
              keyPathSetting = h.programs.atuin.settings ? key_path;
              daemonAfterAgenix = builtins.elem "agenix.service" h.systemd.user.services.atuin-daemon.Unit.After;
            };
          expected = {
            key = "/home/ank/.local/share/atuin/key";
            session = "/home/ank/.local/share/atuin/session";
            keyFile = "atuinKey.age";
            sessionFile = "atuinSession.age";
            keyPathSetting = false;
            daemonAfterAgenix = true;
          };
        };

        # Immutable users: ank's password comes from the agenix secret at every activation.
        test-password-from-the-host-key-secret = {
          expr = {
            mutable = cfg.users.mutableUsers;
            passwordFile = cfg.users.users.ank.hashedPasswordFile == cfg.age.secrets.commonInitialHashedPassword.path;
            failed = t.failedAssertions cfg;
          };
          expected = {
            mutable = false;
            passwordFile = true;
            failed = [ ];
          };
        };
      };
    };
}
