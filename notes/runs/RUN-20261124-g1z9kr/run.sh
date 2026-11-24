#!/usr/bin/env bash
# RUN-20261124-g1z9kr (EXP-20261124-g1ym5w): agenix's darwin launchd job as upstream ships it,
# with KeepAlive {SuccessfulExit=false} (keepalive.nix), and with that plus a wrapper that
# clears unfinished generations (wrapper.nix). From the repo root on a Mac, as the user:
#   notes/runs/RUN-20261124-g1z9kr/run.sh
# Each variant is the real home-manager plist (mkhm.nix: neusis's locked nixpkgs,
# home-manager, agenix) for one throwaway secret encrypted to a throwaway age key, both in a
# scratch directory that is deleted at the end; the job runs under a test label, so ank's
# own agenix agent and secrets are never touched. A reload is done the way home-manager's
# setupLaunchAgents does it on a switch: bootout --wait, install -Dm444, bootstrap.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=${YAJNA_RUN_DIR:-$here}
repo=$(git -C "$here" rev-parse --show-toplevel)
uid=$(id -u)
wait_s=${WAIT_S:-35} # launchd throttles a relaunch to one per 10 s
scratch=$(mktemp -d "${TMPDIR:-/tmp}/exp-agenix.XXXXXX")
labels=()
cleanup() {
  for l in "${labels[@]}"; do /bin/launchctl bootout "gui/$uid/$l" 2>/dev/null || true; done
  rm -rf "$scratch"
}
trap cleanup EXIT

age=$(nix build --no-link --print-out-paths --impure --expr \
  "(builtins.getFlake \"$repo\").inputs.nixpkgs.legacyPackages.aarch64-darwin.age")/bin

build() { # variant work secret label -> plist path
  local gen
  gen=$(nix build --no-link --print-out-paths --impure --expr \
    "import $here/mkhm.nix { repo = \"$repo\"; work = \"$1\"; secret = \"$2\"; label = \"$3\"; variant = \"$4\"; }")
  echo "$gen/LaunchAgents/$3.plist"
}
load() { # plist work label: what home-manager's setupLaunchAgents does for a changed agent
  /bin/launchctl bootout --wait "gui/$uid/$3" 2>/dev/null || true
  install -Dm444 -T "$1" "$2/$3.plist"
  /bin/launchctl bootstrap "gui/$uid" "$2/$3.plist"
}
field() { /bin/launchctl print "gui/$uid/$1" | awk -v k="$2" -F' = ' '$1 == "\t" k {print $2; exit}'; }
generation() { basename "$(readlink "$1/agenix")" 2>/dev/null || echo none; }
content() { cat "$1/agenix/t" 2>/dev/null || echo none; }

printf 'step\tvariant\truns\tlast_exit\tgeneration\tsecret\texpect\tok\n' >"$out/results.tsv"
record() { # step variant work label expect-runs expect-exit expect-gen expect-secret
  local runs ex gen sec ok=yes
  runs=$(field "$4" runs); ex=$(field "$4" "last exit code"); gen=$(generation "$3"); sec=$(content "$3")
  case $5 in
    '>=3') [ "$runs" -ge 3 ] || ok=no ;;
    *) [ "$runs" = "$5" ] || ok=no ;;
  esac
  [ "$7" = runs ] && set -- "$1" "$2" "$3" "$4" "$5" "$6" "$runs" "$8" # one generation per run
  [ "$ex" = "$6" ] && [ "$gen" = "$7" ] && [ "$sec" = "$8" ] || ok=no
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$runs" "$ex" "$gen" "$sec" \
    "runs $5, exit $6, gen $7, secret $8" "$ok" | tee -a "$out/results.tsv"
}
secret() { # work value -> encrypted file
  printf '%s' "$2" | "$age/age" -r "$(cat "$1/recipient")" -o "$1/$2.age"
  echo "$1/$2.age"
}
setup() { # name -> work dir with a throwaway key
  local w="$scratch/$1"
  mkdir -p "$w"
  "$age/age-keygen" -o "$w/id.txt" 2>/dev/null
  "$age/age-keygen" -y "$w/id.txt" >"$w/recipient"
  echo "$w"
}

# 1. upstream: after a clean exit launchd starts it again, every ~10 s.
w=$(setup upstream); l=dev.leoank.exp-g1z9kr.upstream; labels+=("$l")
load "$(build "$w" "$(secret "$w" v1)" "$l" upstream)" "$w" "$l"; sleep "$wait_s"
record 1-load upstream "$w" "$l" '>=3' 0 runs v1
/bin/launchctl bootout "gui/$uid/$l"

# 2-5 share one work dir, as one machine's agent would across switches.
w=$(setup fixed); l=dev.leoank.exp-g1z9kr.fixed; labels+=("$l")
# 2. keepalive: runs once at load.
load "$(build "$w" "$(secret "$w" v1)" "$l" keepalive)" "$w" "$l"; sleep "$wait_s"
record 2-load keepalive "$w" "$l" 1 0 1 v1
# 3. keepalive: a switch that changes the secret reloads the job, which runs once more.
load "$(build "$w" "$(secret "$w" v2)" "$l" keepalive)" "$w" "$l"; sleep "$wait_s"
record 3-reload-new-secret keepalive "$w" "$l" 1 0 2 v2
# 4. keepalive: what a run killed mid-write leaves (generation 3 with a read-only t.tmp,
#    as age -o creates it under the script's umask u=r), then the next load.
mkdir -p "$w/agenix.d/3"; (umask 0277; : >"$w/agenix.d/3/t.tmp")
load "$(build "$w" "$w/v2.age" "$l" keepalive)" "$w" "$l"; sleep "$wait_s"
record 4-load-after-killed-run keepalive "$w" "$l" '>=3' 1 2 v2
grep -m1 'permission denied' "$w/stderr" | sed "s#$scratch#<scratch>#" >"$out/step4-stderr.txt" || true
# 5. wrapped: the same leftover is cleared and the run succeeds, once.
load "$(build "$w" "$w/v2.age" "$l" wrapped)" "$w" "$l"; sleep "$wait_s"
record 5-load-wrapped-after-killed-run wrapped "$w" "$l" 1 0 3 v2
ls "$w/agenix.d" >"$out/step5-generations.txt"
plutil -p "$(build "$w" "$w/v2.age" "$l" wrapped)" | sed -n '/ProgramArguments/,/^  ]/p' \
  | sed "s#$scratch#<scratch>#g" >"$out/wrapped-program-arguments.txt"
