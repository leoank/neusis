# Builds the docgen helper against the CLI sources of the neusis being
# documented and runs it, producing the command tree as JSON. Reuses the
# neusis package's vendored Go modules, so no extra vendorHash is
# needed as long as docgen only imports the CLI's existing deps.
{
  runCommand,
  neusis,
  stdenv,
}:
let
  docgen = neusis.packages.${stdenv.hostPlatform.system}.neusis.overrideAttrs (old: {
    pname = "neusis-docgen";
    postPatch = (old.postPatch or "") + ''
      cp ${./export.go} cmd/zz_docs_export.go
      mkdir -p docgen && cp ${./main.go} docgen/main.go
    '';
    subPackages = [ "docgen" ];
    postInstall = "";
    doCheck = false;
  });
in
runCommand "neusis-cli.json" { } ''
  ${docgen}/bin/docgen > $out
''
