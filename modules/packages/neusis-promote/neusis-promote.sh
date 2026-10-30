# neusis-promote — move the deploy/<group> branches to the commits their
# hosts may run (docs/auto-update-spec.md §4.3).
#
#   neusis-promote --groups FILE [--candidate SHA --gated true|false]
#                  [--report FILE] [--remote NAME] [--push]
#
# FILE is `{ <group>: { branch, after, soakHours, members } }`, the lab's
# registry.deployGroups with `members` a list of `{ host, kind }` (kind
# nixos or darwin). A group without `after` moves to the candidate
# (a commit on main whose gates ran; `--gated` says whether they passed)
# and is left alone when there is none. A group with `after` moves to the
# newest commit its `after` group reached at least `soakHours` ago. A
# move must fast-forward, the commit must be signed by a key in the
# allowed signers of the group's current head (what its hosts check), and
# no member that runs comin on the group's branch at the head may stop
# doing so at the commit: comin would deploy that and remove itself. To
# unenroll a host, take it out of the group first.
#
# Promotions are recorded as git notes on refs/notes/neusis-deploy, one
# "<group> <epoch>" line each; soak times are read from them.
#
# Environment:
#   DEPLOY_HOLD  groups to leave alone (space or comma separated)
#   NOW          current time in epoch seconds (default: now)
#   SIGNERS_CMD  executable printing the allowed_signers of revision $1
#                (default: render registry.signers.anklab with nix eval)
#   ENROLLED_CMD executable printing true or false: does host $3 (kind $2)
#                run comin on branch $4 at revision $1 (default: nix eval)
#
# Without --push nothing leaves the clone. The report (default stdout) is
# a JSON array of { group, action, from, to, reason }, action one of
# promoted, held, paused, unchanged, waiting.

usage() {
  cat >&2 <<'EOF'
usage: neusis-promote --groups FILE [--candidate SHA --gated true|false]
                      [--report FILE] [--remote NAME] [--push]
EOF
  exit 2
}

groups=""
candidate=""
gated=false
report=/dev/stdout
remote=origin
push=0
while [ $# -gt 0 ]; do
  case "$1" in
    --groups) groups="$2"; shift 2 ;;
    --candidate) candidate="$2"; shift 2 ;;
    --gated) gated="$2"; shift 2 ;;
    --report) report="$2"; shift 2 ;;
    --remote) remote="$2"; shift 2 ;;
    --push) push=1; shift ;;
    -h | --help) usage ;;
    *) echo "neusis-promote: unknown argument $1" >&2; usage ;;
  esac
done
[ -n "$groups" ] || usage

now=${NOW:-$(date +%s)}
notes=refs/notes/neusis-deploy
hold=" $(printf '%s' "${DEPLOY_HOLD:-}" | tr ',' ' ') "
top=$(git rev-parse --show-toplevel)
out=$(mktemp)
tmp=$(mktemp -d)
trap 'rm -rf "$out" "$tmp"' EXIT

git fetch -q "$remote" "+refs/heads/deploy/*:refs/remotes/$remote/deploy/*"
git fetch -q "$remote" "+$notes:$notes" 2>/dev/null || true

signers() {
  if [ -n "${SIGNERS_CMD:-}" ]; then
    "$SIGNERS_CMD" "$1"
  else
    nix eval --raw --impure --expr "
      let f = builtins.getFlake \"git+file://$top?rev=$1\";
      in f.neusis.lib.autoUpdate.allowedSigners f.neusis.registry.signers.anklab"
  fi
}

enrolled() {
  if [ -n "${ENROLLED_CMD:-}" ]; then
    "$ENROLLED_CMD" "$@"
  else
    nix eval --raw --impure --expr "
      let
        f = builtins.getFlake \"git+file://$top?rev=$1\";
        hosts = f.$2Configurations or { };
        comin = if hosts ? \"$3\" then hosts.\"$3\".config.services.comin or null else null;
      in
      if comin != null && comin.enable && builtins.any (r: r.branches.main.name == \"$4\") comin.remotes
      then \"true\" else \"false\""
  fi
}

# Members enrolled on branch $2 at revision $1 that are not at $3.
unenrolled() {
  local kind host
  while read -r kind host; do
    if [ "$(enrolled "$1" "$kind" "$host" "$2")" = true ] &&
      [ "$(enrolled "$3" "$kind" "$host" "$2")" != true ]; then
      echo "$host"
    fi
  done < <(jq -r --arg g "$g" '.[$g].members[]? | "\(.kind) \(.host)"' "$groups")
}

record() {
  jq -nc --arg group "$1" --arg action "$2" --arg from "$3" --arg to "$4" --arg reason "$5" \
    '{ $group, $action, $from, $to, $reason }' >>"$out"
}

field() { jq -r --arg g "$1" ".[\$g].$2 // empty" "$groups"; }

# Newest first-parent commit of branch $1 that group $2 reached at least
# $3 seconds ago; empty when there is none.
soaked() {
  local ref="refs/remotes/$remote/$1" blob commit t c
  local -A at=()
  git rev-parse -q --verify "$ref" >/dev/null || return 0
  while read -r blob commit; do
    t=$(git cat-file -p "$blob" | awk -v g="$2" '$1 == g { print $2; exit }')
    if [ -n "$t" ]; then at[$commit]=$t; fi
  done < <(git notes --ref="$notes" list 2>/dev/null)
  for c in $(git rev-list --first-parent "$ref"); do
    if [ -n "${at[$c]:-}" ] && [ $((now - at[$c])) -ge "$3" ]; then
      echo "$c"
      return 0
    fi
  done
}

# `after` chains first: a group sees its `after` group's move in this run.
order=$(jq -r 'def depth($g): if .[$g].after == null then 0 else 1 + depth(.[$g].after) end;
  [keys[] as $k | { k: $k, d: depth($k) }] | sort_by(.d, .k)[] | .k' "$groups")

moved=0
for g in $order; do
  branch=$(field "$g" branch)
  after=$(field "$g" after)
  soak=$(field "$g" soakHours)
  head=$(git rev-parse -q --verify "refs/remotes/$remote/$branch^{commit}" || true)

  if [ -z "$after" ]; then
    [ -n "$candidate" ] || continue
    cand=$(git rev-parse --verify "$candidate^{commit}")
    if [ "$gated" != true ]; then
      record "$g" held "$head" "$cand" "the gates failed on $cand"
      continue
    fi
  else
    cand=$(soaked "$(field "$after" branch)" "$after" $((soak * 3600)))
    if [ -z "$cand" ]; then
      record "$g" waiting "$head" "" "nothing has run on $after for ${soak}h yet"
      continue
    fi
  fi

  if [ "$cand" = "$head" ] || { [ -n "$head" ] && git merge-base --is-ancestor "$cand" "$head"; }; then
    record "$g" unchanged "$head" "$head" ""
    continue
  fi
  case "$hold" in
    *" $g "*)
      record "$g" paused "$head" "$cand" "in DEPLOY_HOLD"
      continue
      ;;
  esac
  if [ -n "$head" ] && ! git merge-base --is-ancestor "$head" "$cand"; then
    record "$g" held "$head" "$cand" "$branch does not fast-forward from $head to $cand"
    continue
  fi
  signers "${head:-$cand}" >"$tmp/allowed_signers"
  if ! git -c gpg.ssh.allowedSignersFile="$tmp/allowed_signers" verify-commit "$cand" 2>/dev/null; then
    record "$g" held "$head" "$cand" "$cand is not signed by an allowed signer"
    continue
  fi
  if [ -n "$head" ]; then
    gone=$(unenrolled "$head" "$branch" "$cand" | paste -sd, -)
    if [ -n "$gone" ]; then
      record "$g" held "$head" "$cand" "$cand would unenroll $gone (comin off or not on $branch there); take a host out of the group before dropping comin"
      continue
    fi
  fi

  if [ "$push" = 1 ]; then
    git push -q "$remote" "$cand:refs/heads/$branch"
  fi
  git update-ref "refs/remotes/$remote/$branch" "$cand"
  git notes --ref="$notes" append -m "$g $now" "$cand"
  moved=1
  record "$g" promoted "$head" "$cand" ""
done

if [ "$push" = 1 ] && [ "$moved" = 1 ]; then
  git push -q "$remote" "$notes"
fi
jq -s . "$out" >"$report"
