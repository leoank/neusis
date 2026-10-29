# neusis-notify — send one alert to ntfy and by email (Postmark).
#
#   neusis-notify [--env-file FILE] [--title T] [--priority P] [--tags a,b]
#                 [--no-email] MESSAGE
#
# Channels are configured from the environment (or a dotenv FILE):
#   ntfy   NTFY_TOPIC (required), NTFY_URL (default https://ntfy.sh),
#          NTFY_TOKEN (optional bearer token)
#   email  POSTMARK_API_KEY (a Postmark server token), ALERT_FROM,
#          ALERT_TO (comma-separated),
#          POSTMARK_URL (default https://api.postmarkapp.com/email)
# A channel whose settings are missing is skipped. Exits non-zero when
# no channel is configured or every configured channel failed.

usage() {
  cat >&2 <<'EOF'
usage: neusis-notify [--env-file FILE] [--title T] [--priority P] [--tags a,b]
                     [--no-email] MESSAGE
EOF
  exit 2
}

title="neusis"
priority="default"
tags=""
email=1
while [ $# -gt 0 ]; do
  case "$1" in
    --env-file)
      set -a
      # shellcheck disable=SC1090
      . "$2"
      set +a
      shift 2
      ;;
    --title) title="$2"; shift 2 ;;
    --priority) priority="$2"; shift 2 ;;
    --tags) tags="$2"; shift 2 ;;
    --no-email) email=0; shift ;;
    -h | --help) usage ;;
    --) shift; break ;;
    -*) echo "neusis-notify: unknown option $1" >&2; usage ;;
    *) break ;;
  esac
done
[ $# -eq 1 ] || usage
message="$1"

case "$priority" in
  min | low | default | high | urgent) ;;
  *) echo "neusis-notify: --priority must be min, low, default, high or urgent" >&2; exit 2 ;;
esac

tried=0
sent=0

if [ -n "${NTFY_TOPIC:-}" ]; then
  tried=$((tried + 1))
  auth=()
  if [ -n "${NTFY_TOKEN:-}" ]; then
    auth=(-H "Authorization: Bearer $NTFY_TOKEN")
  fi
  if curl -fsS --max-time 30 -o /dev/null \
    -H "Title: $title" -H "Priority: $priority" -H "Tags: $tags" \
    "${auth[@]}" --data-binary "$message" \
    "${NTFY_URL:-https://ntfy.sh}/$NTFY_TOPIC"; then
    sent=$((sent + 1))
  else
    echo "neusis-notify: ntfy failed" >&2
  fi
fi

if [ "$email" = 1 ] && [ -n "${POSTMARK_API_KEY:-}" ] && [ -n "${ALERT_FROM:-}" ] && [ -n "${ALERT_TO:-}" ]; then
  tried=$((tried + 1))
  body=$(jq -n \
    --arg from "$ALERT_FROM" --arg to "$ALERT_TO" \
    --arg subject "$title" --arg text "$message" \
    '{
      From: "neusis <\($from)>",
      To: ($to | split(",") | map(gsub("^ +| +$"; "")) | join(", ")),
      Subject: $subject,
      TextBody: $text,
      MessageStream: "outbound"
    }')
  if curl -fsS --max-time 30 -o /dev/null \
    -H "X-Postmark-Server-Token: $POSTMARK_API_KEY" \
    -H "Accept: application/json" -H "Content-Type: application/json" \
    --data-binary "$body" "${POSTMARK_URL:-https://api.postmarkapp.com/email}"; then
    sent=$((sent + 1))
  else
    echo "neusis-notify: email failed" >&2
  fi
fi

if [ "$tried" = 0 ]; then
  echo "neusis-notify: no channel configured (NTFY_TOPIC, or POSTMARK_API_KEY + ALERT_FROM + ALERT_TO)" >&2
  exit 1
fi
[ "$sent" -gt 0 ]
