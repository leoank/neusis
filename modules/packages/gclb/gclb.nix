# gclb — git clone bare (with worktree bootstrap).
#
# Flake-parts module that exposes `flake.packages.<system>.gclb`.
# Built from the python script next to this file via
# `writers.writePython3Bin`. `writers.writePython3Bin` also runs
# flake8 over the source as part of the build — the `# flake8: noqa`
# directive at the top of `gclb.py` suppresses those checks.
#
# Usage:
#   gclb git@github.com:org/repo.git
#   # clones into ./repo/.bare, writes a `.git` file pointing at it,
#   # configures origin fetch refs, then adds a worktree for the
#   # remote's default branch.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.gclb = pkgs.writers.writePython3Bin "gclb" { } (builtins.readFile ./gclb.py);
    };
}
