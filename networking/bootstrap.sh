#!/usr/bin/env bash
# Create the shared external Docker networks other stacks expect.
# Idempotent — safe to run any time (e.g. after `docker network prune`).
set -euo pipefail

ensure_net() {
  local name=$1
  if docker network inspect "$name" >/dev/null 2>&1; then
    echo "ok   network '$name' already exists"
  else
    docker network create --driver bridge "$name" >/dev/null
    echo "made network '$name'"
  fi
}

ensure_net frontend

echo
echo "note: 'media_default' is created by the media compose project itself;"
echo "bring 'media/' up before 'frontend/'."
