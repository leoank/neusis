# Tests for flake.neusis.features.nixos.nitya-server: it turns on nitya's server with the
# leoank auth key and the delegate key as systemd credentials from the two nitya agenix
# secrets. agenix is stubbed (the machine test exercises it with agenix present).
{ self, inputs, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      stubAgenix =
        { lib, ... }:
        {
          options.age.secrets = lib.mkOption {
            default = { };
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, ... }:
                {
                  options = {
                    rekeyFile = lib.mkOption { type = lib.types.path; };
                    path = lib.mkOption {
                      type = lib.types.str;
                      default = "/run/agenix/${name}";
                    };
                  };
                }
              )
            );
          };
          # the two secrets a machine defines (ghost001 does)
          config.age.secrets = lib.genAttrs [
            "nityaServerTsAuthKey"
            "nityaDelegateKey"
          ] (_: { rekeyFile = ./nitya-server.test.nix; });
        };
      cfg = t.evalNixos {
        system = "aarch64-linux";
        modules = [
          stubAgenix
          inputs.nitya.nixosModules.server
          self.neusis.features.nixos.nitya-server
        ];
      };
      s = cfg.systemd.services.nitya-server.serviceConfig;
    in
    {
      tests.feature-nixos-nitya-server = {
        test-wires-server-to-agenix-secrets = {
          expr = {
            on = cfg.services.nitya-server.enable;
            creds = s.LoadCredential;
            user = s.User;
            state = s.StateDirectory;
            flags = lib.hasSuffix "--hostname nitya --port 7300 --authkey-file %d/authkey --delegate-key %d/delegate-key" (
              builtins.unsafeDiscardStringContext s.ExecStart
            );
            admin = builtins.any (p: (p.name or "") == "nitya-admin") cfg.environment.systemPackages;
          };
          expected = {
            on = true;
            creds = [
              "authkey:/run/agenix/nityaServerTsAuthKey"
              "delegate-key:/run/agenix/nityaDelegateKey"
            ];
            user = "nitya";
            state = "nitya";
            flags = true;
            admin = true;
          };
        };
      };
    };
}
