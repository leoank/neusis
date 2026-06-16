# kumarank user — same human (Ankur Kumar), different system
# username. Lives on `darwin001` where macOS already assigned this
# account name. Bundles are NOT redefined here; we reuse the ones
# already declared under `flake.neusis.users.ank.hmBundles.*` so
# both identities get the same shell/editor/agent/theming stack.
#
# SSH keys are reused from `users/ank/id_*.pub` for the same
# reason — same person, same key material.
{ self, ... }:
{
  flake.neusis.users.kumarank.neusisOS = {
    username = "kumarank";
    fullName = "Ankur Kumar";
    shell = "zsh";
    sshKeys = [
      ../ank/id_rsa.pub
      ../ank/id_ed25519.pub
      ../ank/id2_ed25519.pub
    ];
    machineToBundlesMap = {
      darwin001 = [
        self.neusis.features.agnostic.nix-pkgs
        self.neusis.users.ank.hmBundles.kalam-ide
        self.neusis.users.ank.hmBundles.terminal-life
        self.neusis.users.ank.hmBundles.agent-harness
        self.neusis.users.ank.hmBundles.darwin-tools
        self.neusis.users.ank.hmBundles.theming
        self.neusis.users.ank.hmBundles.browsers
        ../ank/_packages.nix
      ];
    };
  };
}
