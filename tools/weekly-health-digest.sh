#!/usr/bin/env bash
# weekly-health-digest.sh — run a set of read-only health checks and push one
# combined summary to gotify, instead of scripts that only ever get run by
# hand when someone remembers to. Swap CHECKS below for your own read-only,
# non-destructive scripts (compose drift, pipeline health, cert expiry —
# whatever you already have lying around).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CHECKS=(
  "$HERE/check-compose.sh"
  # add more read-only check scripts here
)

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

rc=0
for check in "${CHECKS[@]}"; do
  [ -x "$check" ] || continue
  {
    echo "=== $(basename "$check") ==="
    bash "$check" 2>&1 || rc=1
    echo
  } >> "$out"
done

# strip ANSI color codes — gotify renders plain/markdown, not terminal escapes
sed -i 's/\x1b\[[0-9;]*m//g' "$out"

prio=3
title="Weekly health digest: all clear"
if [ "$rc" -ne 0 ]; then
  prio=6
  title="Weekly health digest: issues found"
fi

bash "$HERE/notify.sh" -t "$title" -p "$prio" -m - < "$out"
exit "$rc"
