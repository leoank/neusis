# neusis-switch-check — refuse to activate a commit comin would replace
# (docs/auto-update-spec.md §9.5).
#
#   neusis-switch-check REV OWNER/REPO BRANCH [BRANCH…]
#
# Succeeds when one of the BRANCHes on GitHub already contains REV, the
# commit the new system was built from; those are the branches comin
# deploys (the deploy group's, then the host's testing branch). Fails
# otherwise: comin would deploy the branch head over this system, and on
# a first enrollment that head may not run comin at all, which removes
# comin. It only warns, and succeeds, when it can't tell: REV unknown or
# built from a dirty tree, or GitHub unreachable.
#
# `$NEUSIS_STATE_DIR/force-switch` (default /var/lib/neusis-auto-update)
# skips the check once; the file is removed. GITHUB_API overrides
# https://api.github.com (tests).

[ $# -ge 3 ] || {
  echo "usage: neusis-switch-check REV OWNER/REPO BRANCH [BRANCH…]" >&2
  exit 2
}
rev=$1
repo=$2
shift 2
api=${GITHUB_API:-https://api.github.com}
force=${NEUSIS_STATE_DIR:-/var/lib/neusis-auto-update}/force-switch

warn() { echo "neusis-switch-check: warning: $*" >&2; }

if [ -e "$force" ]; then
  rm -f "$force"
  warn "force-switch set, not checking $rev against $*"
  exit 0
fi
case "$rev" in
  "")
    warn "unknown revision; comin will replace this system with the head of $1 on its next deploy"
    exit 0
    ;;
  *-dirty)
    warn "built from uncommitted changes; comin will replace them with the head of $1 on its next deploy"
    exit 0
    ;;
esac

body=$(mktemp)
trap 'rm -f "$body"' EXIT
for branch in "$@"; do
  code=$(curl -sS --max-time 15 -o "$body" -w '%{http_code}' \
    -H "Accept: application/vnd.github+json" \
    "$api/repos/$repo/compare/$branch...$rev" 2>/dev/null) || code=000
  case "$code" in
    200)
      case "$(jq -r .status "$body")" in
        identical | behind) exit 0 ;;
      esac
      ;;
    404) ;;
    *)
      warn "could not ask GitHub whether $branch contains $rev (HTTP $code); switching anyway"
      exit 0
      ;;
  esac
done

cat >&2 <<EOF
neusis-switch-check: refusing to activate $rev: no branch comin follows ($*)
contains it yet. comin would deploy the head of $1 over this system, and on
a first enrollment that head may not run comin at all, which removes it.
Push the commit to main and wait until CI promotes it to $1, or, to switch
anyway (comin still replaces it later):

  sudo mkdir -p ${force%/*} && sudo touch $force
EOF
exit 1
