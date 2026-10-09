#!/usr/bin/env bash
# dockle-scan.sh — lint every image the compose files reference with Dockle
# (goodwithtech/dockle: CIS Docker benchmark checks plus image best practices).
#
#   tools/dockle-scan.sh            # report findings, always exit 0
#   tools/dockle-scan.sh --strict   # exit 1 if any image has a FATAL finding
#
# Report-only by default: the first run is for triage. Accepted findings go in
# tools/dockle-ignore.txt (one checkpoint code per line, with a reason), and
# images too large for CI go in tools/dockle-skip.txt (one substring per line).
# Images whose reference contains a ${VAR} are skipped, since they can't be
# resolved without a real .env.
#
# Used by .github/workflows/dockle.yml. Needs docker. It pulls every image, so
# expect several GB of transfer on a cold run.
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$(dirname "$0")/.." && pwd; })"
cd "$ROOT"

DOCKLE_IMAGE="goodwithtech/dockle:v0.4.15@sha256:eade932f793742de0aa8755406c7677cd7696f8675b6180926f7eeffa7abe6b9"
STRICT=0
[ "${1:-}" = "--strict" ] && STRICT=1

command -v docker >/dev/null || { echo "docker not found"; exit 2; }

# Non-comment, non-blank lines of a list file.
read_list() { [ -f "$1" ] && grep -vE '^[[:space:]]*(#|$)' "$1" | sed 's/[[:space:]]*#.*//' || true; }

ignore_args=()
while IFS= read -r code; do
  [ -n "$code" ] && ignore_args+=(-i "$code")
done < <(read_list tools/dockle-ignore.txt)

images="$(grep -rhE '^[[:space:]]*image:' --include='docker-compose.y*ml' --include='compose.y*ml' . \
  | sed -E 's/^[[:space:]]*image:[[:space:]]*//; s/["'\'']//g; s/[[:space:]]+#.*$//' \
  | grep -vF '$' | sort -u)"
skips="$(read_list tools/dockle-skip.txt)"

total=0; failed=0; warned=0
while IFS= read -r img; do
  [ -n "$img" ] || continue
  if [ -n "$skips" ] && printf '%s\n' "$img" | grep -qF -f <(printf '%s\n' "$skips"); then
    echo "skip  $img (tools/dockle-skip.txt)"; continue
  fi
  total=$((total + 1))
  echo "=== $img"
  if ! docker pull -q "$img" >/dev/null 2>&1; then
    echo "  could not pull, skipping"; continue
  fi
  out="$(docker run --rm -v /var/run/docker.sock:/var/run/docker.sock "$DOCKLE_IMAGE" \
          --no-color --exit-code 1 --exit-level fatal ${ignore_args[@]+"${ignore_args[@]}"} "$img" 2>&1)"
  rc=$?
  printf '%s\n' "$out" | grep -E '^(FATAL|WARN)' | sed 's/^/  /' || true
  [ "$rc" -eq 0 ] || failed=$((failed + 1))
  printf '%s\n' "$out" | grep -qE '^WARN' && warned=$((warned + 1))
done <<< "$images"

echo
echo "dockle: $total image(s) scanned, $failed with FATAL findings, $warned with warnings"
if [ "$STRICT" -eq 1 ] && [ "$failed" -gt 0 ]; then exit 1; fi
exit 0
