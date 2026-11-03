{ ... }:
{
  perSystem =
    {
      config,
      inputs',
      pkgs,
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        nativeBuildInputs = [
          config.agenix-rekey.package
          config.packages.neusis
          # `neusis cloud bootstrap`: age decrypts the bootstrap tree,
          # nixos-rebuild switches the instance (works from Darwin).
          pkgs.age
          pkgs.nixos-rebuild
          # the notebook CLI (notes/, yajna.toml; ADR-0001); the input is
          # declared in modules/users/ank/ank.nix
          inputs'.yajna.packages.yajna
        ];

        # Automatically adds rekeyed secrets to git without
        # requiring `agenix rekey -a`.
        env.AGENIX_REKEY_ADD_TO_GIT = true;
      };
    };
}
