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
      home = self.homeConfigurations."ank@curiosity".config;
      unit = cfg.boot.initrd.systemd.services.curiosity-host-key;
      script = cfg.boot.initrd.systemd.contents."/etc/curiosity-host-key.sh".text;
    in
    {
      tests.machine-curiosity = {
        # ank's saarthi node: a user service pointed at ghost001's hub, offering the app a
        # shell on this machine (saarthi ADR-0054).
        test-saarthi-node = {
          expr =
            let
              line = lib.concatStringsSep " " (lib.toList home.systemd.user.services.saarthi-node.Service.ExecStart);
            in
            {
              hub = lib.hasInfix "--hub http://saarthi-hub:7700" line;
              name = lib.hasInfix "--name curiosity" line;
              terminal = lib.hasInfix "--terminal" line;
            };
          expected = {
            hub = true;
            name = true;
            terminal = true;
          };
        };

        # A live disk joins tailscale as a new device each boot; its offline predecessor is
        # deleted, not kept as curiosity-old-<timestamp>.
        test-tailscale-deletes-its-previous-boot = {
          expr = {
            inherit (cfg.neusis.services.tailscale.profiles.runxi) forceHostName deleteOfflineConflicts;
            shntnuDeletes = cfg.neusis.services.tailscale.profiles.shntnu.deleteOfflineConflicts;
            default = cfg.neusis.services.tailscale.defaultProfile;
            # anklab_mesh's runxi key; the saarthi node joins leoank with anklab's leoank key
            meshKey = baseNameOf cfg.age.secrets.runxiTsAuthKey.rekeyFile;
            saarthiKey = baseNameOf home.age.secrets.saarthiNodeTailnetKey.rekeyFile;
            # the scripts use runxi's devices:core client; the all-permission one stays on rogue
            scriptClient = baseNameOf cfg.neusis.services.tailscale.profiles.runxi.clientSecretFile;
            adminClients = builtins.filter (n: builtins.hasAttr n (cfg.age.secrets // home.age.secrets)) [
              "runxiTsClientId"
              "leoankTsClientId"
            ];
          };
          expected = {
            forceHostName = true;
            deleteOfflineConflicts = true;
            shntnuDeletes = true;
            default = "runxi";
            meshKey = "runxiTsAuthKey.age";
            saarthiKey = "leoankTsAuthKey.age";
            scriptClient = "runxiDeviceTsClientSecret";
            adminClients = [ ];
          };
        };

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
        # The kernel's -dev output rides on the live image, so building an out-of-tree
        # module after a fresh boot doesn't recompile the whole kernel to get it back.
        test-kernel-dev-on-the-image = {
          expr = map (p: p.outputName or "out") (
            builtins.filter (
              p: (p.pname or "") == cfg.boot.kernelPackages.kernel.pname
            ) cfg.system.extraDependencies
          );
          expected = [ "dev" ];
        };

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

        # sandhi (users/ank/sandhi.nix, ADR-0021): curiosity on leoank as `sandhi-curiosity`;
        # it starts after the agenix user unit decrypts the key a first join needs, and the
        # home-manager ssh config includes the `*.leoank` block. Its identity outlives the
        # live disk's reboots on SPARKDATA (ADR-0023): not ephemeral, kept in
        # /var/lib/sandhi-ank, restored by the initrd, given to ank by tmpfiles, saved back
        # by a path unit.
        test-sandhi = {
          expr =
            let
              b = home.services.sandhi.backends;
              u = home.systemd.user.services.sandhi.Unit;
            in
            {
              leoank = {
                inherit (b.leoank) forwards domains;
                inherit (b.leoank.tailnet) hostname authKeyFile ephemeral;
              };
              backends = builtins.attrNames b;
              onPath = t.hasPkg "sandhi" home.home.packages;
              sshInclude = home.home.file.".ssh/config.d/sandhi".text;
              key = home.age.secrets.sandhiLeoankTsAuthKey.rekeyFile;
              after = u.After;
              sshIncludes = home.programs.ssh.enable && builtins.elem "config.d/sandhi" home.programs.ssh.includes;
              failed = t.failedAssertions home;
              stateDir = home.services.sandhi.stateDir;
              tmpfiles = builtins.filter (lib.hasInfix "sandhi") cfg.systemd.tmpfiles.rules;
              restore = lib.hasInfix "install -m 0600 \"$s\" /sysroot/var/lib/sandhi-ank/leoank/tailscaled.state" cfg.boot.initrd.systemd.contents."/etc/curiosity-host-key.sh".text;
              saveOn = cfg.systemd.paths.sandhi-state-save.pathConfig.PathChanged;
              saveTo = lib.hasInfix "dst=/mnt/sparkdata/config/curiosity/sandhi/leoank" cfg.systemd.services.sandhi-state-save.script;
              saveAtBoot = cfg.systemd.services.sandhi-state-save.wantedBy;
            };
          expected = {
            leoank = {
              forwards = [
                {
                  port = 22;
                  to = "127.0.0.1:22";
                }
              ];
              domains = [ "tail73031.ts.net" ];
              hostname = "sandhi-curiosity";
              authKeyFile = home.age.secrets.sandhiLeoankTsAuthKey.path;
              ephemeral = false;
            };
            backends = [ "leoank" ];
            onPath = true;
            sshInclude = ''
              Host *.leoank *.tail73031.ts.net
                ProxyCommand ${lib.getExe home.services.sandhi.package} connect %h %p
            '';
            key = ../../secrets/anklab/leoankTsAuthKey.age;
            after = [ "agenix.service" ];
            sshIncludes = true;
            failed = [ ];
            stateDir = "/var/lib/sandhi-ank";
            tmpfiles = [
              "d /var/lib/sandhi-ank 0700 ank users -"
              "Z /var/lib/sandhi-ank - ank users -"
            ];
            restore = true;
            saveOn = "/var/lib/sandhi-ank/leoank/tailscaled.state";
            saveTo = true;
            saveAtBoot = [ "multi-user.target" ];
          };
        };
      };
    };
}
