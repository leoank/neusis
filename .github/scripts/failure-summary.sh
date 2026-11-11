#!/usr/bin/env bash
# What failed in a workflow run, for alert.sh: the failed jobs and the
# distinct `error:` lines of their logs, with what changes between runs of
# the same failure (timestamps, store hashes, build directories) masked, so
# the same break prints the same text and a new break prints new text.
#
#   failure-summary.sh RUN_ID
#
# Needs GH_TOKEN (actions: read) and GH_REPO. Works while the run is still
# going (the calling job's own run): logs are read per finished job.
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: failure-summary.sh RUN_ID" >&2; exit 2; }
run=$1

gh api --paginate "repos/$GH_REPO/actions/runs/$run/jobs" \
  --jq '.jobs[] | select(.conclusion == "failure") | "\(.id)\t\(.name)"' |
  sort -t$'\t' -k2 |
  while IFS=$'\t' read -r id name; do
    echo "Failed: $name"
    # gh api refuses a log with terminal escapes in it; curl does not.
    curl -fsSL --max-time 120 -H "Authorization: Bearer $GH_TOKEN" \
      "https://api.github.com/repos/$GH_REPO/actions/jobs/$id/logs" 2>/dev/null |
      sed -E 's/^[0-9-]+T[0-9:.]+Z //; s/\x1b\[[0-9;]*m//g; s/^[[:space:]>]+//; s/^[a-zA-Z0-9_.+-]+> //' |
      grep -E '^error(\[[A-Z0-9]+\])?:' |
      grep -vE '^error: (Cannot build|Build failed due to failed dependency|builder for .* failed)|^error:$' |
      sed -E 's#/nix/store/[a-z0-9]{32}-#/nix/store/…-#g; s#/nix/var/nix/builds/[^/ ]+#/nix/var/nix/builds/…#g; s#rustc[A-Za-z0-9]{6}/#rustc…/#g; s#\(pid [0-9]+\)#(pid …)#g' |
      sort -u | head -n 8 | sed 's/^/  /' || true
  done
