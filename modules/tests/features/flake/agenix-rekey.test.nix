# Tests for the flake-level features: agenix-rekey (dev shell with the
# `agenix` CLI, rekey wiring, yajna) and the fresh-apps input.
{ self, inputs, ... }:
{
  perSystem =
    { lib, system, ... }:
    let
      shell = self.devShells.${system}.default;
      shellTools = t: lib.any (p: lib.hasPrefix t (lib.getName p)) (shell.nativeBuildInputs ++ (shell.buildInputs or [ ]));
    in
    {
      tests.feature-flake = {
        test-dev-shell-ships-agenix = {
          expr = {
            name = shell.name;
            agenix = shellTools "agenix";
            # neusis cloud bootstrap needs these on PATH
            age = shellTools "age";
            nixosRebuild = shellTools "nixos-rebuild";
            # notes/ is a yajna notebook (docs/decisions/ADR-0001)
            yajna = shellTools "yajna";
            addToGit = shell.AGENIX_REKEY_ADD_TO_GIT or null;
          };
          expected = {
            name = "nix-shell";
            agenix = true;
            age = true;
            nixosRebuild = true;
            yajna = true;
            addToGit = true;
          };
        };

        test-flake-file-check-is-registered = {
          expr = self.checks.${system} ? check-flake-file;
          expected = true;
        };

        test-fresh-apps-input-is-a-flake = {
          expr = inputs.fresh-apps ? packages && inputs ? llm-agents && inputs ? jail-nix;
          expected = true;
        };
      };
    };
}
