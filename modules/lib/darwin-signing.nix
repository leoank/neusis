# Stable code signatures on darwin (ADR-0022): a program that needs a privacy grant
# (Input Monitoring, Local Network, …) runs from a copy outside the store, signed with
# rcodesign from a self-signed key kept in agenix. macOS keys the grant on the signature's
# designated requirement, which is then `identifier "<id>" and certificate root = H"…"`,
# the same for every build, so a grant given once survives rebuilds.
#
# `mkSignScript` returns the shell text of the signing step. It is meant to run in a
# launchd job of its own, not in activation: nix-darwin's agenix decrypts in its
# `activate-agenix` launchd daemon, beside activation and at boot, so the key may only
# appear after a moment. The step
#   - does nothing when the copy already holds a signed `program` (a stamp beside it);
#   - otherwise waits up to `keyWait` seconds for the key, signs `program` straight from
#     the store into `dir/<name>`, and runs `onChange` (restart whatever runs the copy).
#     No time-stamp server: a grant needs none, and the job must not depend on the network
#     (rcodesign asks timestamp.apple.com by default);
#   - when signing fails (no key, rcodesign error), keeps a previously signed copy, or with
#     none installs the store program unsigned so the job still runs, and warns. It exits 0
#     either way: a missing key must never leave launchd retrying in a loop.
{ ... }:
{
  flake.neusis.lib.darwinSigning.mkSignScript =
    {
      pkgs,
      name,
      program,
      identifier,
      keyFile,
      certFile,
      dir,
      onChange ? "",
      keyWait ? 60,
    }:
    let
      dest = "${dir}/${name}";
    in
    ''
      set -u
      dest=${pkgs.lib.escapeShellArg dest}
      stamp="$dest.source"
      program=${pkgs.lib.escapeShellArg program}
      key=${pkgs.lib.escapeShellArg keyFile}
      cert=${pkgs.lib.escapeShellArg (toString certFile)}
      warn() { echo "neusis-sign ${identifier}: $*" >&2; }

      if [ -x "$dest" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$program signed" ]; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/mkdir -p ${pkgs.lib.escapeShellArg dir}

      n=0
      while [ ! -r "$key" ] && [ "$n" -lt ${toString keyWait} ]; do
        sleep 1
        n=$((n + 1))
      done

      if [ -r "$key" ] && [ -r "$cert" ] \
        && ${pkgs.rcodesign}/bin/rcodesign sign --pem-file "$key" --pem-file "$cert" --timestamp-url none \
             --binary-identifier ${pkgs.lib.escapeShellArg identifier} "$program" "$dest.new" >/dev/null 2>&1; then
        ${pkgs.coreutils}/bin/chmod 0555 "$dest.new"
        ${pkgs.coreutils}/bin/mv -f "$dest.new" "$dest"
        echo "$program signed" > "$stamp"
        echo "neusis-sign ${identifier}: signed $program" >&2
      else
        ${pkgs.coreutils}/bin/rm -f "$dest.new"
        if [ -r "$key" ]; then warn "rcodesign could not sign $program"; else warn "no key at $key"; fi
        case "$(cat "$stamp" 2>/dev/null)" in
          *" signed")
            warn "keeping the previously signed copy, $(cut -d' ' -f1 "$stamp")"
            exit 0
            ;;
        esac
        [ "$(cat "$stamp" 2>/dev/null)" = "$program unsigned" ] && [ -x "$dest" ] && exit 0
        ${pkgs.coreutils}/bin/install -m 0555 "$program" "$dest"
        echo "$program unsigned" > "$stamp"
        warn "running $program unsigned: macOS will ask for the grant again"
      fi
      ${onChange}
      exit 0
    '';
}
