#!/usr/bin/env bash
# export-n8n-workflows.sh — dump every n8n workflow definition to JSON so they
# live in git alongside everything else, instead of only in n8n's own
# database volume (which a typical config/DB backup script never thinks to
# cover). Read-only against n8n's API, no elevated privileges needed.
#
# Strips per-instance credential IDs from each node before writing — those
# are only valid on the n8n install that created them, so re-importing a
# workflow elsewhere already means re-linking credentials by hand; leaving
# the old ID in would just be a stale, meaningless UUID.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$HERE/../automation/n8n-workflows"
mkdir -p "$OUT_DIR"
ENV_FILE="$HERE/../automation/.env"

[ -r "$ENV_FILE" ] || { echo "cannot read $ENV_FILE"; exit 2; }
API_KEY="$(grep '^N8N_API_KEY=' "$ENV_FILE" | cut -d= -f2-)"
[ -n "$API_KEY" ] || { echo "N8N_API_KEY not set in $ENV_FILE"; exit 2; }

curl -s -H "X-N8N-API-KEY: $API_KEY" http://127.0.0.1:5678/api/v1/workflows \
  | OUT_DIR="$OUT_DIR" python3 -c '
import json, os, re, sys

out_dir = os.environ["OUT_DIR"]
d = json.load(sys.stdin)
count = 0
for wf in d["data"]:
    for n in wf.get("nodes", []):
        n.pop("credentials", None)
    slug = re.sub(r"[^a-z0-9]+", "-", wf["name"].lower()).strip("-")
    with open(os.path.join(out_dir, slug + ".json"), "w") as f:
        json.dump(wf, f, indent=2)
        f.write("\n")
    count += 1
print(f"exported {count} workflow(s) to {out_dir}")
'
