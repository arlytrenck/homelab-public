#!/usr/bin/env bash
# notify.sh — send one push message to a self-hosted gotify server.
#
#   notify.sh -t TITLE [-p PRIORITY] [-m MESSAGE]
#   notify.sh -t TITLE -m -            # message body from stdin
#
# Config (first readable wins): $NOTIFY_ENV (default /root/.config/backup/notify.env),
# then ./monitoring/.env relative to this repo. Needs:
#       GOTIFY_URL=http://127.0.0.1:8070          (optional; this is the default)
#       GOTIFY_TOKEN_INFRA=Axxxxxxxxxxxxxx
# or the same names already exported in the environment.
#
# Never fails its caller: a delivery problem prints a warning to stderr and
# still exits 0. Only a usage error exits non-zero (2).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PRIO=5 TITLE="" MSG=""
while getopts ':t:p:m:h' o; do
  case "$o" in
    t) TITLE=$OPTARG ;;
    p) PRIO=$OPTARG ;;
    m) MSG=$OPTARG ;;
    h) grep -E '^#( |$)' "$0" | sed '1d; s/^# \{0,1\}//'; exit 0 ;;
    *) echo "notify.sh: bad option; -h for help" >&2; exit 2 ;;
  esac
done
[ -n "$TITLE" ] || { echo "notify.sh: -t TITLE is required" >&2; exit 2; }
[ "$MSG" = "-" ] && MSG=$(cat)

# pull just the two keys we need, from the first file that has a token
kv(){ sed -n "s/^[[:space:]]*$1=//p" "$2" 2>/dev/null | tail -1 | tr -d '"\r'; }
for f in "${NOTIFY_ENV:-/root/.config/backup/notify.env}" "$HERE/../monitoring/.env"; do
  [ -r "$f" ] || continue
  t=$(kv GOTIFY_TOKEN_INFRA "$f")
  if [ -n "$t" ]; then
    GOTIFY_TOKEN_INFRA=$t
    u=$(kv GOTIFY_URL "$f"); [ -n "$u" ] && GOTIFY_URL=$u
    break
  fi
done
URL=${GOTIFY_URL:-http://127.0.0.1:8070}
TOKEN=${GOTIFY_TOKEN_INFRA:-}

if [ -z "$TOKEN" ]; then
  echo "notify.sh: no GOTIFY_TOKEN_INFRA (checked notify.env + monitoring/.env) — message dropped: $TITLE" >&2
  exit 0
fi

if ! curl -sf --max-time 10 \
      -F "title=${TITLE}" \
      -F "message=${MSG:-$TITLE}" \
      -F "priority=${PRIO}" \
      "${URL%/}/message?token=${TOKEN}" >/dev/null 2>&1; then
  echo "notify.sh: gotify POST to ${URL} failed — message dropped: $TITLE" >&2
fi
exit 0
