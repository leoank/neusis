# neusis defaults for every terranix stack. A second declaration of
# `terranix.terranixConfigurations` whose submodule merges with terranix's
# own (no default/description here, or the module system refuses to merge
# the two declarations). Imported by ./terranix.nix; kept separate so the
# tests can evaluate it against `inputs.terranix.flakeModule` alone.
#
# Findings behind each line are in docs/cloud-terranix-plan.md (S3):
# `prefixText` runs *inside* `workdir`, `workdir` is relative to the
# invoking cwd, and the bare `.terraform` wrapper does not refresh
# `config.tf.json`.
{ lib, flake-parts-lib, ... }:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.terranix.terranixConfigurations = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, config, ... }:
            let
              # `cd infra/<stack>` has already happened when prefixText
              # runs; climb back out to find the repo root.
              up = lib.concatMapStringsSep "/" (_: "..") (lib.splitString "/" config.workdir);
            in
            {
              workdir = lib.mkDefault "infra/${name}";

              # OpenTofu (native state encryption, see spec §6) with the
              # providers pinned by nixpkgs: no registry downloads at init.
              terraformWrapper.package = lib.mkDefault (
                pkgs.opentofu.withPlugins (p: [
                  p.oracle_oci
                  p.cloudflare_cloudflare
                ])
              );

              terraformWrapper.prefixText = lib.mkBefore ''
                test -f ${up}/flake.nix || {
                  echo "neusis: run stacks from the repo root (cwd is $PWD)" >&2
                  exit 1
                }
                ln -sfn ${config.result.terraformConfiguration} config.tf.json
                # Operator secrets (OCI compartment, state passphrase, …)
                # as TF_VAR_* lines; placed there by the user's home bundle.
                env_file="''${NEUSIS_TF_ENV:-$HOME/.config/neusis/tf.env}"
                if [ -f "$env_file" ]; then
                  set -a
                  # shellcheck disable=SC1090
                  . "$env_file"
                  set +a
                fi
                # Every neusis stack encrypts its state; without the key
                # tofu would prompt for the variable and hang.
                : "''${TF_VAR_state_passphrase:?neusis: TF_VAR_state_passphrase is unset (expected in $env_file)}"
              '';
            }
          )
        );
      };
    }
  );
}
