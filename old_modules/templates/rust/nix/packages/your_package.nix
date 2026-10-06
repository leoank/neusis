{
  lib,
  rustPlatform,
  rust-cbindgen,
  pkg-config,
}:
rustPlatform.buildRustPackage rec {
  pname = "your_package";
  version = "0.1";
  cargoLock.lockFile = ../../Cargo.lock;
  src = lib.cleanSource ./../.;
  buildInputs = [
    # Add required native libs here
  ];
  nativeBuildInputs = [
    # Add native tools require for building
    rust-cbindgen
    pkg-config
    rustPlatform.bindgenHook
  ];
}
