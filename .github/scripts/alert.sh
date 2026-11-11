#!/usr/bin/env bash
# Rolling alert issues for the auto-update pipelines
# (docs/auto-update-spec.md §6.4).
#
#   alert.sh failed|ok TITLE BODY [DETAILS]
#
# failed  comments on the open issue titled TITLE, or opens it and sends
#         the email. DETAILS (failure-summary.sh: the failed jobs and their
#         errors) goes into the comment with a hash of it; a repeat sends
#         the email again only when DETAILS differs from the last one on
#         the issue, so the same break mails once and a new break mails too.
# ok      closes that issue, if open, with BODY as the last comment.
#
# Needs GH_TOKEN (issues: write) and GH_REPO. The email runs
# neusis-notify from the checkout and needs POSTMARK_API_KEY, ALERT_FROM
# and ALERT_TO.
set -euo pipefail

usage() { echo "usage: alert.sh failed|ok TITLE BODY [DETAILS]" >&2; exit 2; }
[ $# -eq 3 ] || [ $# -eq 4 ] || usage
state=$1
title=$2
body=$3
details=${4:-}
label=auto-update

notify() {
  nix run .#neusis-notify -- --title "$1" --priority high --tags warning \
    "$body${details:+

$details}"
}

gh label create "$label" --force --color B60205 \
  --description "auto-update pipeline alerts" >/dev/null
num=$(gh issue list --label "$label" --state open --limit 100 --json number,title |
  jq -r --arg t "$title" 'first(.[] | select(.title == $t) | .number) // empty')

case "$state" in
  failed)
    text=$body
    sig=
    if [ -n "$details" ]; then
      sig=$(printf '%s' "$details" | git hash-object --stdin | cut -c1-12)
      # shellcheck disable=SC2016 # the backticks are a markdown fence
      text=$(printf '%s\n\n```\n%s\n```\n<!-- alert-sig: %s -->' "$body" "$details" "$sig")
    fi
    if [ -n "$num" ]; then
      last=$(gh issue view "$num" --json body,comments \
        --jq '[.body, .comments[].body | capture("<!-- alert-sig: (?<s>[0-9a-f]+) -->").s?] | last // empty')
      gh issue comment "$num" --body "$text"
      if [ -n "$sig" ] && [ "$sig" != "$last" ]; then
        notify "$title: the failure changed"
      fi
    else
      gh issue create --title "$title" --label "$label" --body "$text"
      notify "$title"
    fi
    ;;
  ok)
    if [ -n "$num" ]; then
      gh issue close "$num" --comment "Recovered: $body"
    fi
    ;;
  *) usage ;;
esac
