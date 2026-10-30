#!/usr/bin/env bash
# Rolling alert issues for the auto-update pipelines
# (docs/auto-update-spec.md §6.4).
#
#   alert.sh failed|ok TITLE BODY
#
# failed  comments on the open issue titled TITLE, or opens it and sends
#         the email, so a failure that persists mails once, not every run.
# ok      closes that issue, if open, with BODY as the last comment.
#
# Needs GH_TOKEN (issues: write) and GH_REPO. The email runs
# neusis-notify from the checkout and needs POSTMARK_API_KEY, ALERT_FROM
# and ALERT_TO.
set -euo pipefail

[ $# -eq 3 ] || { echo "usage: alert.sh failed|ok TITLE BODY" >&2; exit 2; }
state=$1
title=$2
body=$3
label=auto-update

gh label create "$label" --force --color B60205 \
  --description "auto-update pipeline alerts" >/dev/null
num=$(gh issue list --label "$label" --state open --limit 100 --json number,title |
  jq -r --arg t "$title" 'first(.[] | select(.title == $t) | .number) // empty')

case "$state" in
  failed)
    if [ -n "$num" ]; then
      gh issue comment "$num" --body "$body"
    else
      gh issue create --title "$title" --label "$label" --body "$body"
      nix run .#neusis-notify -- --title "$title" --priority high --tags warning "$body"
    fi
    ;;
  ok)
    if [ -n "$num" ]; then
      gh issue close "$num" --comment "Recovered: $body"
    fi
    ;;
  *)
    echo "usage: alert.sh failed|ok TITLE BODY" >&2
    exit 2
    ;;
esac
