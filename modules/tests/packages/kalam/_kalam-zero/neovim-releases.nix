# Official Neovim release builds for kalam-zero's version tests (ADR-0016:
# "Neovim 0.8 or newer"). nixpkgs carries only the current Neovim, so these
# are the upstream x86_64-linux tarballs, pinned by hash and patched to run
# in the sandbox. x86_64-linux only: arm64 tarballs start at 0.10.4.
# The latest patch release of each minor version, as of 2026-11-03.
pkgs:
let
  release =
    version: file: hash:
    pkgs.stdenv.mkDerivation {
      pname = "neovim-release";
      inherit version;
      src = pkgs.fetchurl {
        url = "https://github.com/neovim/neovim/releases/download/v${version}/${file}";
        inherit hash;
      };
      nativeBuildInputs = [ pkgs.autoPatchelfHook ];
      buildInputs = [ pkgs.stdenv.cc.cc.lib ];
      sourceRoot = ".";
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        mkdir -p $out
        cp -r nvim-linux*/* $out/
      '';
    };
in
{
  "0.8" = release "0.8.3" "nvim-linux64.tar.gz" "sha256-WKwDs0XoZ14TMi+McTWQbOJqHKeofQQTRNZLIHvnvt8=";
  "0.9" = release "0.9.5" "nvim-linux64.tar.gz" "sha256-RO45XZtfihS+jsANO46tNOGP5kYeQMnIxQ5pVtZDtso=";
  "0.10" = release "0.10.4" "nvim-linux-x86_64.tar.gz" "sha256-laqo6JRz9UIRFPJ4fBOuDsbhHrvRoTob1vz2NCD4Bz8=";
  "0.11" = release "0.11.7" "nvim-linux-x86_64.tar.gz" "sha256-OKfGMX+UUDhBCWwA6P3gXvBLlHL8nX1ituAzzs1veZE=";
}
