# ank's tailnet administration from rogue: the all-permission OAuth clients of
# the runxi and leoank tailnets (every machine's tailscale scripts use the
# devices:core clients instead, anklab_mesh), and `neusis-ts-authkey`, which
# checks and renews the auth keys anklab_mesh joins with.
#
#   neusis-ts-authkey <runxi|leoank> status
#   neusis-ts-authkey <runxi|leoank> rotate [--expiry-days N] [--revoke-old]
#
# Run it from the neusis checkout. `status` shows the current key's expiry and
# capabilities. `rotate` creates a key with the same capabilities (reusable,
# ephemeral, preauthorized, tags) through the tailnet's API, encrypts it to
# the agenix master key straight into secrets/anklab/<profile>TsAuthKey.age
# (the key is never written in plaintext), and with --revoke-old revokes the
# previous one. Then `agenix rekey -a` and commit; machines that already
# joined keep working, the key only matters for a new join or a logged-out
# identity.
{ ... }:
{
  flake.neusis.users.ank.hmBundles.tailnet-admin =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      profiles = [
        "runxi"
        "leoank"
      ];
      dir = "${config.home.homeDirectory}/.config/tailscale-admin";
      master = builtins.head config.age.rekey.masterIdentities;

      authkey = pkgs.writeShellApplication {
        name = "neusis-ts-authkey";
        runtimeInputs = [
          pkgs.age
          pkgs.curl
          pkgs.jq
          pkgs.git
          pkgs.coreutils
        ];
        text = ''
          usage() {
            echo "usage: neusis-ts-authkey <${lib.concatStringsSep "|" profiles}> status|rotate [--expiry-days N] [--revoke-old]" >&2
            exit 2
          }
          die() { echo "neusis-ts-authkey: $*" >&2; exit 1; }

          [ $# -ge 2 ] || usage
          profile=$1 action=$2
          shift 2
          case "$profile" in ${lib.concatStringsSep "|" profiles}) ;; *) usage ;; esac
          days=90 revoke=0
          while [ $# -gt 0 ]; do
            case "$1" in
              --expiry-days) days=''${2:?}; shift 2 ;;
              --revoke-old) revoke=1; shift ;;
              *) usage ;;
            esac
          done

          root=$(git rev-parse --show-toplevel 2>/dev/null) || die "run it from the neusis checkout"
          file="$root/modules/secrets/anklab/''${profile}TsAuthKey.age"
          [ -f "$file" ] || die "no $file"
          id_file="${dir}/''${profile}TsClientId"
          secret_file="${dir}/''${profile}TsClientSecret"
          [ -r "$id_file" ] && [ -r "$secret_file" ] || die "no admin client for $profile in ${dir}"

          api=https://api.tailscale.com/api/v2
          # call METHOD PATH [JSON]: the response body; fails with Tailscale's message
          call() {
            local out status
            out=$(curl -s -w '\n%{http_code}' -X "$1" "$api$2" -H "Authorization: Bearer $token" \
              ''${3:+-H "Content-Type: application/json" -d "$3"}) || die "could not reach the Tailscale API"
            status=''${out##*$'\n'}
            out=''${out%$'\n'*}
            case "$status" in
              2*) printf '%s' "$out" ;;
              *) die "$1 $2: HTTP $status: $(printf '%s' "$out" | jq -r '.message // .' 2>/dev/null | head -c 300)" ;;
            esac
          }

          token=$(curl -s -X POST "$api/oauth/token" \
            -d "client_id=$(cat "$id_file")" -d "client_secret=$(cat "$secret_file")" | jq -r '.access_token // empty')
          [ -n "$token" ] || die "the $profile admin client was refused an OAuth token"

          # The current key, only in memory: its id is the third field of tskey-auth-<id>-<secret>.
          old=$(age -d -i ${lib.escapeShellArg master.identity} "$file") || die "could not decrypt $file"
          old_id=$(printf '%s' "$old" | tr -d '[:space:]' | cut -d- -f3)
          unset old
          [ -n "$old_id" ] || die "$file does not hold a tskey-auth-<id>-… key"

          info=$(call GET "/tailnet/-/keys/$old_id")

          if [ "$action" = status ]; then
            printf '%s' "$info" | jq -r --arg p "$profile" '
              "\($p): key \(.id)",
              "  created  \(.created)",
              "  expires  \(.expires) (\(((.expires | sub("\\.[0-9]+";"") | fromdateiso8601) - now) / 86400 | floor) days)",
              "  revoked  \(.revoked // "no")",
              "  device   \(.capabilities.devices.create | {reusable, ephemeral, preauthorized, tags})"'
            exit 0
          fi
          [ "$action" = rotate ] || usage

          caps=$(printf '%s' "$info" | jq -c '{devices: {create: (.capabilities.devices.create | {reusable, ephemeral, preauthorized, tags})}}')
          body=$(jq -cn --argjson caps "$caps" --argjson s "$((days * 86400))" --arg d "neusis $profile" \
            '{capabilities: $caps, expirySeconds: $s, description: $d}')
          new=$(call POST "/tailnet/-/keys" "$body")
          new_id=$(printf '%s' "$new" | jq -r .id)
          tmp=$(mktemp "$file.XXXXXX")
          printf '%s' "$new" | jq -r .key | age -r ${lib.escapeShellArg master.pubkey} -o "$tmp" || { rm -f "$tmp"; die "could not encrypt the new key"; }
          mv -f "$tmp" "$file"
          echo "$profile: new key $new_id ($(printf '%s' "$new" | jq -r .expires)), written to ''${file#"$root/"}"

          if [ "$revoke" = 1 ]; then
            call DELETE "/tailnet/-/keys/$old_id" >/dev/null
            echo "$profile: revoked the previous key $old_id"
          fi
          echo "next: nix develop -c agenix rekey -a, then commit ''${file#"$root/"} and the rekeyed files"
        '';
      };
    in
    {
      age.secrets = lib.listToAttrs (
        lib.concatMap (
          p:
          map
            (
              k:
              lib.nameValuePair "${p}Ts${k}" {
                rekeyFile = ../../secrets/anklab + "/${p}Ts${k}.age";
                path = "${dir}/${p}Ts${k}";
              }
            )
            [
              "ClientId"
              "ClientSecret"
            ]
        ) profiles
      );

      home.packages = [ authkey ];
    };
}
