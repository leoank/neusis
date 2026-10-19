# Tests for flake.terranixModules.state-encryption: the OpenTofu
# encryption block in the JSON-syntax shape spike S2 established.
{ self, inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      cfg =
        (inputs.terranix.lib.evalTerranixConfiguration {
          inherit pkgs;
          modules = [ self.terranixModules.state-encryption ];
        }).config;
    in
    {
      tests.terranix-state-encryption = {
        test-state-and-plan-are-enforced = {
          expr = cfg.terraform.encryption;
          expected = {
            key_provider.pbkdf2.main.passphrase = "\${var.state_passphrase}";
            method.aes_gcm.main.keys = "key_provider.pbkdf2.main";
            state = {
              method = "method.aes_gcm.main";
              enforced = true;
            };
            plan = {
              method = "method.aes_gcm.main";
              enforced = true;
            };
          };
        };

        test-passphrase-is-a-sensitive-variable = {
          expr = cfg.variable.state_passphrase;
          expected = {
            type = "string";
            sensitive = true;
          };
        };
      };
    };
}
