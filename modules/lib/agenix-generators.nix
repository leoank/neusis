# agenix-rekey generators: `flake.neusis.lib.agenixGenerators`.
{ ... }:
{
  flake.neusis.lib.agenixGenerators = {
    # An ed25519 SSH key pair: `agenix generate` encrypts the private half as the secret and
    # this writes the public half beside it (<name>.pub, to commit). The private half is only
    # ever in a temporary directory removed on exit.
    #   age.secrets.<name>.generator.script = self.neusis.lib.agenixGenerators.sshKey "<comment>";
    sshKey =
      comment:
      {
        lib,
        pkgs,
        file,
        ...
      }:
      ''
        (
          umask 077
          d=$(mktemp -d)
          trap 'rm -rf "$d"' EXIT
          ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C ${lib.escapeShellArg comment} -f "$d/key"
          cp "$d/key.pub" ${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
          cat "$d/key"
        )
      '';
  };
}
