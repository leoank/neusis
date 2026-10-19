# OpenTofu client-side state encryption: every neusis stack commits its
# state to git, so plaintext state must be impossible to write (spec §6).
#
# The passphrase arrives as `TF_VAR_state_passphrase` (the stack wrapper
# sources it from ~/.config/neusis/tf.env). JSON-syntax rule found in
# spike S2: references inside `encryption` are bare strings
# ("method.aes_gcm.main"), not `${…}` templates; only the passphrase is an
# ordinary expression.
{ ... }:
{
  flake.terranixModules.state-encryption = {
    variable.state_passphrase = {
      type = "string";
      sensitive = true;
    };

    terraform.encryption = {
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
}
