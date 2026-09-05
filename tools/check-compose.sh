#!/usr/bin/env bash
# check-compose.sh — run `docker compose config` on every stack in the repo.
# Fails if any compose file is invalid. Missing ${VAR} values only warn (real
# values live in gitignored .env files), so they don't fail the check — except
# a compose file's own ${VAR:?required} checks, which a blank value can't
# satisfy; for those, a throwaway .env is seeded from that stack's
# .env.example instead of left empty (see the loop below).
#
#   tools/check-compose.sh            # from anywhere in the repo
#
# Used by CI (.github/workflows/validate.yml) and the pre-commit hook. If
# `docker compose` isn't available (e.g. running pre-commit off-box) it warns
# and passes — CI still enforces it.
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$(dirname "$0")/.." && pwd; })"
cd "$ROOT"

list_repo_files() {
  local g; g="$(git ls-files 2>/dev/null || true)"
  if [ -n "$g" ]; then printf '%s\n' "$g"
  else find . -type f -not -path './.git/*' | sed 's|^\./||'
  fi
}

if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
  echo "WARN: 'docker compose' not available here — skipping (CI enforces this)."
  exit 0
fi

mapfile -t COMPOSE < <(list_repo_files | grep -E '(^|/)(docker-)?compose\.ya?ml$' | sort -u)
[ "${#COMPOSE[@]}" -gt 0 ] || { echo "no compose files found under $ROOT"; exit 1; }

rc=0
MADE_ENV=()
cleanup(){ local e; for e in "${MADE_ENV[@]:-}"; do [ -n "$e" ] && rm -f "$e"; done; }
trap cleanup EXIT

env_file_targets() {   # $1 = compose file — prints referenced env_file paths, one per line
  awk '
    /^[[:space:]]*env_file:[[:space:]]*\[/ { s=$0; sub(/.*\[/,"",s); sub(/\].*/,"",s);
      n=split(s,a,","); for(i=1;i<=n;i++){ gsub(/[[:space:]"'\'']/,"",a[i]); if(a[i]!="") print a[i] } next }
    /^[[:space:]]*env_file:[[:space:]]*[^[:space:]#]/ { v=$2; gsub(/["'\'']/,"",v); print v; next }
    /^[[:space:]]*env_file:[[:space:]]*$/ { blk=1; next }
    blk && /^[[:space:]]*-[[:space:]]*/ { v=$2; gsub(/["'\'']/,"",v); print v; next }
    blk { blk=0 }
  ' "$1"
}

for f in "${COMPOSE[@]}"; do
  d="$(dirname "$f")"
  # `config` needs any referenced env files (incl. the implicit project .env) to
  # exist. Seed throwaways from that stack's .env.example when there is one —
  # its placeholder values (e.g. GOTIFY_DEFAULTUSER_PASS=changeme-long-random)
  # satisfy a compose file's ${VAR:?required} checks; an empty file wouldn't.
  # Remove the throwaway on exit either way.
  while IFS= read -r ef; do
    [ -n "$ef" ] || continue
    ep="$d/$ef"
    if [ ! -e "$ep" ]; then
      if [ -f "$d/.env.example" ]; then cp "$d/.env.example" "$ep"; else : > "$ep"; fi
      MADE_ENV+=("$ep")
    fi
  done < <(env_file_targets "$f"; echo ".env")

  printf -- '--- %s\n' "$f"
  if docker compose -f "$f" config -q 2> >(grep -v -e 'variable is not set' -e 'Defaulting to a blank string' >&2); then
    echo "    ok"
  else
    echo "    FAIL"
    rc=1
  fi
done

if [ $rc -eq 0 ]; then echo "all ${#COMPOSE[@]} compose file(s) valid."
else echo "compose validation FAILED."; fi
exit $rc
