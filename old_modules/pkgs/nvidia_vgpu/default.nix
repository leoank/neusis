{
  lib,
  stdenv,
  dpkg,
  glibc,
  gcc-unwrapped,
  autoPatchelfHook,
  requireFile,
}: let
  # Please keep the version x.y.0.z and do not update to x.y.76.z because the
  # source of the latter disappears much faster.
  version = "1.11.268";

  src = requireFile {
    name = "NVIDIA-Linux-x86_64-535.154.02-vgpu-kvm.run";
    url = "https://nvidia.com/";
    message = "Download the run file from official website";
    sha256 = "1slcvj68zbpwr7f5blqyjqlz5rj4and5ck90wzf40aycbn1n4xfb";
  };
in
  stdenv.mkDerivation {
    pname = "sst";
    inherit version;
    system = "x86_64-linux";

    inherit src;

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    # Required for compilation
    nativeBuildInputs = [
      autoPatchelfHook # Automatically setup the loader, and do the magic
    ];
    # runtimeDependencies = [ out/lib ];
    # autoPatchelfIgnoreMissingDeps = true;

    # Required at running time
    buildInputs = [
      glibc
      gcc-unwrapped
      dpkg
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      dpkg -x $src $out
      mv $out/usr/bin/* $out/bin/
      rm -r $out/usr/bin
      mkdir -p $out/lib
      mv $out/usr/lib/solidigm/* $out/bin/
      rm -r $out/usr/lib
      mv $out/usr/share/* $out/share/
      rm -r $out/usr

      addAutoPatchelfSearchPath $out/lib
      autoPatchelf $out/bin/*
      patchelf --set-rpath $(patchelf --print-rpath $out/bin/sst):$out/lib $out/bin/sst
      runHook postInstall
    '';

    meta = with lib; {
      description = "Solidigm storage tool";
      homepage = "https://solidigm.com/";
      license = licenses.mit;
      maintainers = with stdenv.lib.maintainers; [ank];
      platforms = ["x86_64-linux"];
    };
  }
