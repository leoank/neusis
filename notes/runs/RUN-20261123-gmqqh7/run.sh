#!/usr/bin/env bash
# RUN-20261123-gmqqh7: does rcodesign, signing from a self-signed PEM key with no keychain,
# give two different builds of a binary the same designated requirement?
# From the repo root on a Mac: notes/runs/RUN-20261123-gmqqh7/run.sh
# Makes a throwaway code-signing certificate (deleted at the end), builds two binaries that
# differ by one string, signs each with rcodesign and a fixed identifier, and writes each
# one's designated requirement and the cross-checks to results.txt. rcodesign and openssl
# come from the nixpkgs pinned in flake.lock; cc, codesign come from macOS.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=${YAJNA_RUN_DIR:-$here}
cd "$(git rev-parse --show-toplevel)"
rev=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)
pkgs="github:nixos/nixpkgs/$rev"
id=dev.leoank.sigtest

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

nix shell "$pkgs#openssl" -c openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout key.pem -out cert.pem -days 1 -subj "/CN=neusis-codesign-test" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "basicConstraints=critical,CA:false" 2>/dev/null
cat key.pem cert.pem > ident.pem
certsha1=$(nix shell "$pkgs#openssl" -c openssl x509 -in cert.pem -outform der | shasum | cut -d' ' -f1)

for v in 1 2; do
  printf '#include <stdio.h>\nint main(void){puts("build %s");return 0;}\n' "$v" > b$v.c
  /usr/bin/cc -o b$v b$v.c                       # ad-hoc, linker-signed, as Nix builds are
  cp b$v s$v
  nix shell "$pkgs#rcodesign" -c rcodesign sign --pem-file ident.pem \
    --binary-identifier "$id" s$v > /dev/null 2>&1
done

dr() { codesign -d -r- "$1" 2>&1 | grep 'designated =>'; }
{
  echo "rcodesign: $(nix shell "$pkgs#rcodesign" -c rcodesign --version)"
  echo "certificate sha1: $certsha1"
  echo "adhoc build 1:  $(dr b1)"
  echo "adhoc build 2:  $(dr b2)"
  echo "signed build 1: $(dr s1)"
  echo "signed build 2: $(dr s2)"
  # a "#" before "designated" means codesign inferred it; none means it is embedded
  echo "embedded: $( [ "$(dr s1 | cut -c1)" = d ] && echo yes || echo no )"
  echo "same requirement: $( [ "$(dr s1)" = "$(dr s2)" ] && echo yes || echo no )"
  echo "no cdhash in it: $( dr s1 | grep -q cdhash && echo no || echo yes )"
  req=$(dr s1 | sed 's/^designated => //')
  echo "build 2 satisfies build 1's requirement: $(codesign --verify -R="$req" s2 2>/dev/null && echo yes || echo no)"
  echo "adhoc build 2 satisfies it: $(codesign --verify -R="$req" b2 2>/dev/null && echo yes || echo no)"
  echo "strict verify: $(codesign --verify --strict s1 s2 2>/dev/null && echo ok || echo failed)"
  echo "signed builds run: $(./s1) / $(./s2)"
} | tee "$out/results.txt"
