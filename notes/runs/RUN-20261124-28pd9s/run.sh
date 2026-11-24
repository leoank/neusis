#!/usr/bin/env bash
# RUN-20261124-28pd9s: what ak2396@cam.ac.uk's mail on rogue shows about EXP-20261106-2s4hg4.
# From the repo root on rogue: notes/runs/RUN-20261124-28pd9s/run.sh
# Reads the cam maildir only (no token is read or printed): how much the Inbox holds, how
# recently mbsync (IMAP, XOAUTH2 with oama's token) brought mail in, and whether the synced
# Sent Items hold a message sent by aerc (SMTP, XOAUTH2). MAILDIR defaults to ~/Maildir.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=${YAJNA_RUN_DIR:-$here}
cam=${MAILDIR:-$HOME/Maildir}/cam
{
  echo "inbox messages: $(find "$cam/Inbox" -type f | wc -l | tr -d ' ')"
  echo "inbox files from the last 48 h: $(find "$cam/Inbox" -type f -mtime -2 | wc -l | tr -d ' ')"
  sent=$( (find "$cam/Sent Items" -type f -print0 | xargs -0 grep -l -i -E '^(User-Agent|X-Mailer): *aerc' 2>/dev/null || true) | wc -l | tr -d ' ')
  echo "sent items written by aerc: $sent"
} | tee "$out/results.txt"
