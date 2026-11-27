# Stable code signatures on darwin

macOS keeps a privacy grant (Input Monitoring, Local Network, …) per program, keyed by its
code signature. Nix builds are ad-hoc signed, so every rebuild is a new program to macOS and
the grant is lost. [ADR-0022](decisions/ADR-0022-stable-darwin-code-signing-from-agenix-keys.md)
fixes this by running such programs from a copy signed with a fixed, self-signed identity
whose key lives in agenix. A grant given once then survives rebuilds.

The signing step is `neusis.lib.darwinSigning.mkSignScript` (`modules/lib/darwin-signing.nix`).
It runs in a launchd job of its own, because nix-darwin's agenix decrypts secrets in its
`activate-agenix` launchd daemon rather than during activation. It signs with `rcodesign`
from the PEM key and certificate, re-signs only when the store program changed, and never
fails a switch: with no key it keeps the previous signed copy, or runs the program unsigned
and warns in the job's log.

Only kanata uses it so far (`neusis.services.kanata.darwin.signing`).

## Create the system signing key (once)

The key for system daemons is root-only on the machine. Create it from the neusis checkout;
the private key goes straight into agenix and is never committed in plaintext:

```bash
d=$(mktemp -d)
nix shell nixpkgs#openssl -c openssl req -x509 -newkey rsa:2048 -nodes -days 7300 \
  -keyout "$d/key.pem" -out modules/secrets/common/neusisCodesignSystem.crt \
  -subj "/CN=neusis-codesign-system" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "basicConstraints=critical,CA:false"
nix develop -c agenix edit -i "$d/key.pem" modules/secrets/common/neusisCodesignSystem.age
rm -rf "$d"
```

The certificate (`neusisCodesignSystem.crt`) is public and is committed. Its root hash is
part of every grant, so replacing it costs one re-grant per program.

## Turn it on for a machine

```nix
age.secrets.neusisCodesignSystem.rekeyFile = ../secrets/common/neusisCodesignSystem.age;
neusis.services.kanata.darwin.signing = {
  enable = true;
  keyFile = config.age.secrets.neusisCodesignSystem.path;
  certFile = ../secrets/common/neusisCodesignSystem.crt;
};
```

Then `agenix rekey -a`, commit, and switch.

## Grant once, then check

1. The job's log is `/Library/Logs/kanata-sign.log`; after the switch it says
   `signed /nix/store/…-kanata-…/bin/kanata`.
2. `codesign -d -r- "/Library/Application Support/neusis/signed/dev.leoank.kanata/kanata"`
   shows `identifier "dev.leoank.kanata" and certificate root = H"…"`, with no cdhash.
3. System Settings → Privacy & Security → Input Monitoring: remove any old kanata entry, add
   the signed copy above (⇧⌘G for the path), then
   `sudo launchctl kickstart -k system/org.nixos.kanata-default`.
4. After the next kanata rebuild the keys keep working with no trip to System Settings.
