#!/usr/bin/env bash
# RUN-20261103-h3sjsx: kalam-zero's init.lua (oil inlined) on every supported Neovim.
# From the repo root: notes/runs/RUN-20261103-h3sjsx/run.sh
# Builds the headless checks for the official 0.8.3, 0.9.5, 0.10.4 and
# 0.11.7 release builds and nixpkgs' current Neovim (with and without
# ripgrep), all on x86_64-linux, and writes each check's verdict to
# results.txt. Needs an x86_64-linux builder (a Mac uses /etc/nix/machines).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
cd "$(git rev-parse --show-toplevel)"
: > "$here/results.txt"
for c in kalam-zero-headless-nvim-0_8 kalam-zero-headless-nvim-0_9 kalam-zero-headless-nvim-0_10 \
         kalam-zero-headless-nvim-0_11 kalam-zero-headless kalam-zero-headless-no-rg; do
  if out=$(nix build --no-link --print-out-paths ".#checks.x86_64-linux.$c" 2>/dev/null); then
    printf '%-32s %s\n' "$c" "$(grep -o 'kalam-zero: ok.*' "$out")" | tee -a "$here/results.txt"
  else
    printf '%-32s FAILED (nix log .#checks.x86_64-linux.%s)\n' "$c" "$c" | tee -a "$here/results.txt"
  fi
done
