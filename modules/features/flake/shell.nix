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
        ];

        # Automatically adds rekeyed secrets to git without
        # requiring `agenix rekey -a`.
        env.AGENIX_REKEY_ADD_TO_GIT = true;
      };
    };
}
