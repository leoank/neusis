# SpecStory CLI - saves AI coding conversations locally
# https://github.com/specstoryai/getspecstory
# https://docs.specstory.com/integrations/claude-code
{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  glibc,
  gcc-unwrapped,
}:

stdenv.mkDerivation rec {
  pname = "specstory";
  version = "1.0.0";

  src = fetchzip {
    url = "https://github.com/specstoryai/getspecstory/releases/download/v${version}/SpecStoryCLI_Linux_x86_64.tar.gz";
    sha256 = "sha256-BSlJ9tbMR3UyXFSnFCFIiDYQ0to2DPFJ68WxhdcCAik=";
    stripRoot = false;  # tarball extracts files directly without a parent directory
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    glibc
    gcc-unwrapped  # for libstdc++
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 specstory $out/bin/specstory
    runHook postInstall
  '';

  meta = with lib; {
    description = "CLI that wraps AI coding tools (Claude Code, Cursor, Codex) to save conversations locally";
    homepage = "https://specstory.com";
    downloadPage = "https://github.com/specstoryai/getspecstory/releases";
    license = licenses.unfree;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "specstory";
  };
}
