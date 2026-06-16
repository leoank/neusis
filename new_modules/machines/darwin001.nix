# darwin001 — second macOS host. Identical to rogue at the
# module/feature level; only the primaryUser/registry differ
# because macOS already named the account `kumarank` rather than
# `ank`. See `users/kumarank/kumarank.nix` for the user identity
# wiring (reuses ank's home-manager bundles).
{
  self,
  ...
}:
{

  flake.neusis.machines.darwin001 = {
    system = "aarch64-darwin";
    hostname = "darwin001";
    computerName = "darwin001";
    primaryUser = "kumarank";
    hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO1mRq8v1ey40YLIMwWTYezJ6pkADlXN6kXfYz0RLXMm";
    modulesSpecialArgs = { inherit (self) inputs outputs; };
    userRegistries = [ self.neusis.registry.users.kumaranklab ];
    module =
      { inputs, outputs, ... }:
      {
        imports = [
          self.neusis.features.darwin.defaults
          self.neusis.features.darwin.homebrew-defaults
          self.neusis.features.darwin.setup-keyboard
          ./_homebrew.nix
        ];
        programs.zsh.enable = true;
      };
  };
}
