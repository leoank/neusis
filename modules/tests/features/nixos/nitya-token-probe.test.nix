# Tests for flake.neusis.features.nixos.nitya-token-probe: it turns on nitya's token
# probe with the four nitya agenix secrets as systemd credentials, every 6 hours, as a
# dynamic user. agenix is stubbed (the machine test exercises it with agenix present).
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
                    owner = lib.mkOption {
                      type = lib.types.str;
                      default = "root";
                    };
                    path = lib.mkOption {
                      type = lib.types.str;
                      default = "/run/agenix/${name}";
                    };
                  };
                }
              )
            );
          };
          # the four secrets a machine defines (ghost001 does)
          config.age.secrets = lib.genAttrs [
            "nityaGoogleClient"
            "nityaGoogleToken"
            "nityaMicrosoftToken"
            "nityaICloudToken"
          ] (_: { rekeyFile = ./nitya-token-probe.test.nix; });
        };
      cfg = t.evalNixos {
        system = "aarch64-linux";
        modules = [
          stubAgenix
          inputs.nitya.nixosModules.token-probe
          self.neusis.features.nixos.nitya-token-probe
        ];
      };
      s = cfg.systemd.services.nitya-token-probe.serviceConfig;
    in
    {
      tests.feature-nixos-nitya-token-probe = {
        test-wires-probe-to-agenix-secrets = {
          expr = {
            on = cfg.services.nitya-token-probe.enable;
            creds = s.LoadCredential;
            dynamicUser = s.DynamicUser;
            state = s.StateDirectory;
            every = cfg.systemd.timers.nitya-token-probe.timerConfig.OnCalendar;
            flags = lib.hasSuffix "--google-client %d/google-client --google-token %d/google-token --icloud %d/icloud --microsoft-token %d/microsoft-token" (
              builtins.unsafeDiscardStringContext s.ExecStart
            );
          };
          expected = {
            on = true;
            creds = [
              "google-client:/run/agenix/nityaGoogleClient"
              "google-token:/run/agenix/nityaGoogleToken"
              "icloud:/run/agenix/nityaICloudToken"
              "microsoft-token:/run/agenix/nityaMicrosoftToken"
            ];
            dynamicUser = true;
            state = "nitya-token-probe";
            every = "*-*-* 00/6:00:00";
            flags = true;
          };
        };
      };
    };
}
