# fresh-apps.nix — Leo's curated desktop apps, rebuilt daily against
# upstream releases (faster than nixpkgs). We pull `signal-desktop`
# from here instead of the homebrew `signal` cask; see
# `users/ank/_packages.nix` for the consumer.
#
# Supports aarch64-darwin + {x86_64,aarch64}-linux. It targets the
# nixpkgs-unstable branch, so we point its nixpkgs at ours to dedup
# the closure.
{ ... }:
{
  flake-file.inputs = {
    fresh-apps = {
      url = "github:leoank/fresh-apps.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };
}
