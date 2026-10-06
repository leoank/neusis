# Tests for flake.agnosticModules.build-server: a dedicated, nix-trusted
# build user with the shared build public key, on NixOS and nix-darwin.
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
        test-nixos-creates-system-build-user = {
          expr = common nixos "nixremote" // {
            inherit (nixos.users.users.nixremote) isSystemUser group useDefaultShell;
            hasGroup = nixos.users.groups ? nixremote;
          };
          expected = {
            trusted = true;
            keys = [ f.hostPubkey ];
            keyFiles = [ "placeholder.age" ];
            failed = [ ];
            isSystemUser = true;
            group = "nixremote";
            useDefaultShell = true;
            hasGroup = true;
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
              darwinOff = t.evalDarwin { modules = [ self.darwinModules.build-server ]; };
              nixosOff = t.evalNixos { modules = [ self.nixosModules.build-server ]; };
            in
            {
              darwinUser = darwinOff.users.users ? nixremote;
              darwinKnown = builtins.elem "nixremote" darwinOff.users.knownUsers;
              nixosUser = nixosOff.users.users ? nixremote;
              nixosGroup = nixosOff.users.groups ? nixremote;
              trusted = builtins.elem "nixremote" nixosOff.nix.settings.trusted-users;
            };
          expected = {
            darwinUser = false;
            darwinKnown = false;
            nixosUser = false;
            nixosGroup = false;
            trusted = false;
          };
        };
      };
    };
}
