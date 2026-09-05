#!/usr/bin/env bash
# github-ci-watch.sh — check the latest GitHub Actions run on each repo you
# list below, push a gotify alert only if one is red. Silent on a clean day —
# a daily check that announced "still fine" every time would just be noise.
#
# Uses the `gh` CLI's own logged-in auth (`gh auth login`) — no separate
# token or credential to manage here.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPOS=(
  "your-org/repo-one"
  "your-org/repo-two"
)

command -v gh >/dev/null || { echo "gh CLI not found"; exit 2; }

fail_lines=""
for r in "${REPOS[@]}"; do
  info="$(gh run list --repo "$r" --limit 1 \
            --json conclusion,status,workflowName,headBranch,createdAt \
            -q '.[0] | "\(.status)|\(.conclusion)|\(.workflowName)|\(.headBranch)|\(.createdAt)"' 2>/dev/null)"
  if [ -z "$info" ]; then
    continue
  fi
  IFS='|' read -r status conclusion wf branch created <<< "$info"
  if [ "$status" = "completed" ] && [ "$conclusion" != "success" ]; then
    fail_lines+="$r: $wf on $branch -> $conclusion (run at $created)"$'\n'
  fi
done

if [ -n "$fail_lines" ]; then
  printf '%s' "$fail_lines" | bash "$HERE/notify.sh" -t "GitHub Actions CI failing" -p 7 -m -
  echo "$fail_lines"
  exit 1
fi

echo "all CI green"
exit 0
