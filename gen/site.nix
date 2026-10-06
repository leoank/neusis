# Wires the generators together:
#
#   options.nix ─┐
#   meta.nix ────┼─► render (python) ─► src/ + SUMMARY.md ─► mdbook ─► site
#   cli/ ────────┘
#
# `prepare` runs the same render step against a working tree, which is
# what `nix run .#serve` uses for live preview.
{
  lib,
  pkgs,
  runCommand,
  writeShellScriptBin,
  mdbook,
  python3,
  neusis,
  repoUrl ? "https://github.com/leoank/neusis",
}:
let
  rev = neusis.rev or "main";

  optionsJson = import ./options.nix { inherit pkgs neusis rev repoUrl; };
  metaJson = import ./meta.nix { inherit pkgs neusis; };
  cliJson = pkgs.callPackage ./cli { inherit neusis; };

  # Hand-written part of the site: book.toml, nav.md, src/, theme/.
  siteSrc = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../book.toml
      ../nav.md
      ./autolink.py
      ../src
      ../theme
    ];
  };

  renderCmd = root: ''
    PYTHONPATH=${./.} ${python3}/bin/python3 -m render \
      --root ${root} \
      --neusis ${neusis} \
      --options ${optionsJson} \
      --meta ${metaJson} \
      --cli ${cliJson} \
      --rev ${rev} \
      --repo-url ${repoUrl}
  '';

  # The full mdBook source tree, generated pages included.
  generated = runCommand "neusis-site-src" { } ''
    cp -r --no-preserve=mode ${siteSrc} $out
    ${renderCmd "$out"}
  '';

  prepare = writeShellScriptBin "prepare-site" ''
    set -euo pipefail
    [ -f book.toml ] || { echo "run from the site root (where book.toml is)" >&2; exit 1; }
    ${renderCmd "$PWD"}
  '';
in
runCommand "neusis-site"
  {
    # for the autolink preprocessor
    nativeBuildInputs = [ python3 ];
    passthru = {
      inherit
        optionsJson
        metaJson
        cliJson
        generated
        prepare
        ;
    };
  }
  ''
    ${mdbook}/bin/mdbook build ${generated} --dest-dir $out
  ''
