#!/usr/bin/env bash
# export-n8n-workflows.sh — dump every n8n workflow definition to JSON so they
# live in git alongside everything else, instead of only in n8n's own
# database volume (which a typical config/DB backup script never thinks to
# cover). Read-only against n8n's API, no elevated privileges needed.
#
# This repo is public, so the dump is sanitized on the way out:
#   - per-instance credential IDs are dropped (they are only valid on the
#     n8n install that created them, so an import re-links by hand anyway);
#   - host paths are rewritten to the placeholder tree this repo documents;
#   - workflows are written inactive, so importing a copy never starts
#     firing schedules against someone else's machines;
#   - n8n's activeVersion block is dropped — it is a full second copy of the
#     workflow and doubles the file for nothing.
#
# The rewrite map lives in automation/.env (untracked), not here, so this
# file carries no host specifics of its own:
#
#   N8N_EXPORT_REWRITES="/real/tool/path=/opt/homelab;/scripts/=/opt/homelab/scripts/"
#
# Afterwards it refuses to write anything still carrying a secret, a real
# home/mount path, or a non-placeholder private IP. That check is the reason
# the rewrite map being unset is safe: an unsanitized workflow is refused,
# never written. A workflow that embeds a token directly in a node parameter
# (rather than in an n8n credential) fails by design — move the token into a
# credential, or add the workflow to EXCLUDE.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$HERE/../automation/n8n-workflows"
mkdir -p "$OUT_DIR"
ENV_FILE="$HERE/../automation/.env"

[ -r "$ENV_FILE" ] || { echo "cannot read $ENV_FILE"; exit 2; }
API_KEY="$(grep '^N8N_API_KEY=' "$ENV_FILE" | cut -d= -f2-)"
[ -n "$API_KEY" ] || { echo "N8N_API_KEY not set in $ENV_FILE"; exit 2; }
REWRITES="$(grep '^N8N_EXPORT_REWRITES=' "$ENV_FILE" | cut -d= -f2- | sed 's/^"//;s/"$//')"

curl -s -H "X-N8N-API-KEY: $API_KEY" http://127.0.0.1:5678/api/v1/workflows \
  | OUT_DIR="$OUT_DIR" REWRITES="${REWRITES:-}" python3 -c '
import json, os, re, sys

# Workflows deliberately not published. Keep the reason next to the name.
EXCLUDE = {
    # embeds a Gotify application token directly in node parameters, and is
    # site-publishing automation rather than homelab infrastructure
    "Homelab blog post: deploy + LinkedIn draft",
}

# The placeholder LAN addresses this repo documents; anything else that looks
# like a private address is a real one that escaped the rewrite map.
ALLOWED_IPS = {"10.0.0.10", "10.0.0.9", "10.0.0.0"}

FORBIDDEN = [
    (r"gtfy[A-Za-z0-9._-]{10,}", "gotify application token"),
    (r"(?i)\"(token|api[_-]?key|password|secret)\"\s*:\s*\"[A-Za-z0-9._\-]{16,}\"",
     "secret-looking value"),
    (r"/mnt/[a-z0-9_-]+", "real mount path"),
    (r"/home/[a-z_][a-z0-9_-]*/", "real home path"),
]

def unsanitized_ips(text):
    pat = (r"\b(?:10(?:\.\d{1,3}){3}"
           r"|192\.168(?:\.\d{1,3}){2}"
           r"|172\.(?:1[6-9]|2\d|3[01])(?:\.\d{1,3}){2})\b")
    return {ip for ip in re.findall(pat, text) if ip not in ALLOWED_IPS}

def strip(wf):
    for n in wf.get("nodes", []):
        n.pop("credentials", None)
    # derived / instance-local state: noise in git, and a second copy of the workflow
    for k in ("activeVersion", "activeVersionId", "triggerCount"):
        wf.pop(k, None)
    wf["active"] = False
    return wf

rewrites = []
for pair in os.environ.get("REWRITES", "").split(";"):
    if "=" in pair:
        src, dst = pair.split("=", 1)
        if src:
            rewrites.append((src, dst))

out_dir = os.environ["OUT_DIR"]
d = json.load(sys.stdin)
written, skipped, failed = 0, [], []
for wf in d["data"]:
    name = wf["name"]
    if name in EXCLUDE:
        skipped.append(name)
        continue
    text = json.dumps(strip(wf), indent=2) + "\n"
    for src, dst in rewrites:
        text = text.replace(src, dst)
    hits = [why for pat, why in FORBIDDEN if re.search(pat, text)]
    stray = unsanitized_ips(text)
    if stray:
        hits.append("unsanitized address " + ", ".join(sorted(stray)))
    if hits:
        failed.append((name, hits))
        continue
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    with open(os.path.join(out_dir, slug + ".json"), "w") as f:
        f.write(text)
    written += 1

print(f"exported {written} workflow(s) to {out_dir}")
for n in skipped:
    print(f"  skipped (EXCLUDE): {n}")
for n, why in failed:
    reasons = ", ".join(why)
    print(f"  REFUSED: {n} -> {reasons}", file=sys.stderr)
if failed:
    sys.exit(1)
'
