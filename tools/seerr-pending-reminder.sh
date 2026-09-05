#!/usr/bin/env bash
# seerr-pending-reminder.sh — nag via gotify if Seerr/Overseerr has pending
# media requests sitting unfulfilled. Useful if your *arr stack doesn't have
# a download client wired up yet (or its indexers lapsed) — requests pile up
# silently otherwise. Delete this once that's fixed; a healthy pipeline
# clears its own queue and this becomes noise.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEERR_URL="http://127.0.0.1:5055"
SETTINGS="$HERE/../media/seerr/settings.json"

[ -r "$SETTINGS" ] || { echo "cannot read $SETTINGS"; exit 2; }
API_KEY="$(python3 -c "import json; print(json.load(open('$SETTINGS'))['main']['apiKey'])" 2>/dev/null)"
[ -n "$API_KEY" ] || { echo "no Seerr API key found"; exit 2; }

count="$(curl -s -H "X-Api-Key: $API_KEY" \
  "$SEERR_URL/api/v1/request?filter=pending&take=1" \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('pageInfo',{}).get('results',0))" 2>/dev/null)"

if [ -z "$count" ]; then
  echo "could not read Seerr pending count"
  exit 2
fi

if [ "$count" -gt 0 ]; then
  bash "$HERE/notify.sh" -t "Seerr: $count request(s) awaiting fulfillment" -p 4 \
    -m "$count request(s) are pending and nothing is picking them up automatically — check your download client / indexers." \
    2>&1
  echo "$count pending"
  exit 0
fi

echo "0 pending"
exit 0
