#!/usr/bin/env bash
# push-github-repos.sh — commit-drift + push a set of git repos on a schedule,
# each independent of the others (one failing doesn't stop the rest).
#
# Extracted out of a larger nightly backup script so this piece has its own
# pass/fail history — useful once you're running it from something like n8n
# (see automation/n8n-workflows/) rather than cron, where you actually get
# per-run visibility instead of a script that silently does five things.
#
# Configure REPOS below: "local/path|label" pairs, one per git repo you want
# kept in sync with its GitHub remote. Each repo needs its own working `git
# push` already set up (deploy key or credential helper) — this script just
# adds + commits any drift and pushes, it doesn't configure remotes.
set -u

REPOS=(
  "/opt/example/repo-one|repo-one"
  "/opt/example/repo-two|repo-two"
)

GIT_USER_NAME="repo-sync"
GIT_USER_EMAIL="git-sync@example.com"

log(){ printf '%s %s\n' "$(date '+%F %T')" "$1"; }

push_repo(){
  local dir="$1" label="$2"
  [ -d "$dir/.git" ] || { log "SKIP $label — no .git at $dir"; return 0; }
  (
    set -e
    cd "$dir"
    git remote get-url origin >/dev/null 2>&1 || { echo "no origin remote"; exit 3; }
    git add -A
    if ! git diff --cached --quiet; then
      git -c user.name="$GIT_USER_NAME" -c user.email="$GIT_USER_EMAIL" \
          commit -q -m "sync: $label snapshot $(date +%F)"
    fi
    GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=yes" \
        git push -q origin HEAD:main
  )
  if [ $? -eq 0 ]; then
    log "$label -> github ok"
  else
    log "WARN $label git push failed"
    return 1
  fi
}

fail=0
for entry in "${REPOS[@]}"; do
  IFS='|' read -r dir label <<< "$entry"
  push_repo "$dir" "$label" || fail=$((fail+1))
done

log "done — $fail repo(s) failed to push"
exit "$fail"
