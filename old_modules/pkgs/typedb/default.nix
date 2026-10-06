{
  lib,
  stdenv,
  fetchFromGitHub,
  jdk,
  bazel,
  glibc,
  gcc,
}:
stdenv.mkDerivation {
  pname = "typedb";
  version = "2.27.0";
  system = "x86_64-linux";

  src = fetchFromGitHub {
    owner = "vaticle";
    repo = "typedb";
    rev = "2.27.0";
    sha256 = "sha256-YqYWEH620Yl8iB0gKV8+aZZ4h5ifcloCysPb26XgQGY=";
  };

  patches = [
    ./bazelversion.patch
  ];

  # Required for compilation
  nativeBuildInputs = [
    bazel
  ];

  # Required at running time
  buildInputs = [
    jdk
    glibc
    gcc
  ];

  buildPhase = ''
    bazel build //:assemble-linux-x86_64-targz
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp bazel-bin/* $out/bin/
  '';

  meta = with lib; {
    description = "TypeDB database";
    homepage = "https://typedb.com";
    license = licenses.mit;
    maintainers = with stdenv.lib.maintainers; [ank];
    platforms = ["x86_64-linux"];
  };
}
