# Tests for flake.agnosticModules.build-server: a dedicated, nix-trusted
# build user with the shared build public key. Darwin is covered; the
# NixOS path is pinned as a known evaluation failure (see below).
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      f = t.fixtures;

      server = extra: {
        neusis.services.build-server = {
          enable = true;
          authorizedKeys = [ f.hostPubkey ];
          authorizedKeyFiles = [ ../_fixtures/placeholder.age ];
        }
        // extra;
      };

      darwinWith = extra: t.evalDarwin { modules = [ self.darwinModules.build-server (server extra) ]; };
      nixosWith =
        extra:
        t.evalNixos {
          modules = [
            self.nixosModules.build-server
            f.nixosBase
            (server extra)
          ];
        };

      darwin = darwinWith { };
      nixos = nixosWith { };

      common = cfg: user: {
        trusted = builtins.elem user cfg.nix.settings.trusted-users;
        keys = cfg.users.users.${user}.openssh.authorizedKeys.keys;
        keyFiles = map baseNameOf cfg.users.users.${user}.openssh.authorizedKeys.keyFiles;
        failed = t.failedAssertions cfg;
      };
    in
    {
      tests.agnostic-build-server = {
        # KNOWN BUG, pinned: the module does not evaluate on NixOS, even
        # when disabled. `users.knownUsers` is Darwin-only and is gated with
        # `lib.mkIf pkgs.stdenv.isDarwin`, which still registers the option
        # path on Linux. Fix: dispatch on `options ? launchd` like
        # tailscale.nix does, then replace this with the real expectations
        # (isSystemUser, group, useDefaultShell, users.groups.nixremote).
        test-nixos-does-not-evaluate-yet = {
          expr = common nixos "nixremote";
          expectedError = {
            type = "ThrownError";
            msg = "users.knownUsers' does not exist";
          };
        };

        test-darwin-creates-known-build-user = {
          expr = common darwin "nixremote" // {
            inherit (darwin.users.users.nixremote) uid home;
            shell = toString darwin.users.users.nixremote.shell;
            known = builtins.elem "nixremote" darwin.users.knownUsers;
          };
          expected = {
            trusted = true;
            keys = [ f.hostPubkey ];
            keyFiles = [ "placeholder.age" ];
            failed = [ ];
            uid = 601;
            home = "/Users/nixremote";
            shell = "/bin/zsh";
            known = true;
          };
        };

        test-user-name-uid-and-trust-are-configurable = {
          expr =
            let
              cfg = darwinWith {
                user = "builder";
                uid = 777;
                trust = false;
              };
            in
            {
              users = builtins.attrNames (lib.filterAttrs (n: _: n == "builder" || n == "nixremote") cfg.users.users);
              uid = cfg.users.users.builder.uid;
              trusted = builtins.elem "builder" cfg.nix.settings.trusted-users;
            };
          expected = {
            users = [ "builder" ];
            uid = 777;
            trusted = false;
          };
        };

        test-disabled-creates-no-user = {
          expr =
            let
              cfg = t.evalDarwin { modules = [ self.darwinModules.build-server ]; };
            in
            {
              user = cfg.users.users ? nixremote;
              trusted = builtins.elem "nixremote" cfg.nix.settings.trusted-users;
            };
          expected = {
            user = false;
            trusted = false;
          };
        };
      };
    };
}
