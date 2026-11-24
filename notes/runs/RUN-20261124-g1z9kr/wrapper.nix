# Candidate 2 for neusis: before agenix's mount script runs, remove every generation under
# the mount point except the one the secrets symlink points at. A run killed after age
# opened its output leaves a read-only <name>.tmp in the next generation, and every later
# run fails on it ("permission denied"). The script is passed to sh as $0.
{ config, lib, ... }:
let
  cfg = config.age;
in
{
  launchd.agents.activate-agenix.config.ProgramArguments = lib.mkBefore [
    "/bin/sh"
    "-c"
    ''
      cur=$(basename "$(readlink "${cfg.secretsDir}")" 2>/dev/null) || cur=
      for g in "${cfg.secretsMountPoint}"/*; do
        [ -e "$g" ] && [ "''${g##*/}" != "$cur" ] && rm -rf "$g"
      done
      exec "$0"
    ''
  ];
}
