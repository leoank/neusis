{ ... }:
{
  perSystem =
    {
      config,
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
        ];

        # Automatically adds rekeyed secrets to git without
        # requiring `agenix rekey -a`.
        env.AGENIX_REKEY_ADD_TO_GIT = true;
      };
    };
}
