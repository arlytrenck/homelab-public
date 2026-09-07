# Renovate — image updates via PR

How container images stay current here, replacing **Watchtower** (removed
2026-09-07 — the `containrrr/watchtower` upstream is abandoned). Instead of a
daemon that watches registries and optionally recreates containers, Renovate
opens a **pull request** per image bump; the `validate` workflow checks it;
you apply by merging + `docker compose up -d`. This fits a git + CI repo far
better than an in-cluster updater.

- Config: [`../renovate.json`](../renovate.json)
- Runner: [`.github/workflows/renovate.yml`](../.github/workflows/renovate.yml)

## Setup on a fork

The workflow here is **manual-trigger only** and does nothing until you:

1. Create a fine-grained PAT scoped to your fork —
   **Contents + Pull requests + Issues = Read and write**
   (a classic PAT with `repo` scope also works, broader than needed).
2. Add it as the `RENOVATE_TOKEN` repository secret
   (*Settings → Secrets and variables → Actions*).
3. *Actions → renovate → Run workflow* (leave "Dry run" on for the first try to
   see what it *would* do), or add a `schedule:` trigger to the workflow.

## What it manages

| Kind | Behaviour |
|---|---|
| `:latest` images (adguard, grafana, gotify, prometheus, n8n, dozzle, …) | pinned to `:latest@sha256:…`, then digest bumps — all in **one weekly PR** (`container digests`). |
| Version-tagged images (`uptime-kuma:1.23.x`, `jellystat:1.1.x`, `postgres:16-alpine`, `valkey:9@…`, cadvisor digest) | individual PRs with the upstream changelog. |
| **immich** (server + ML + its Postgres) | grouped — moves as a set. |
| **LinuxServer `*arr`** | grouped. |
| `authelia`, `vaultwarden`, immich major/minor | individual, `review-release-notes` label, never auto-merged. |
| `postgres` / `valkey` **majors** | `review-release-notes` + `breaking`. |
| GitHub Actions | grouped, monthly. |
| Security advisories | bypass the weekly window; `security` label. |

Not managed: anything in `.env` (gitignored) — so an env-var-driven image tag
like immich's stays a manual, release-notes-first bump.

## Enabling auto-merge later

Nothing auto-merges initially. After a few clean weeks, add a rule to
`renovate.json` `packageRules`:

```json
{ "matchUpdateTypes": ["digest"], "automerge": true, "platformAutomerge": true }
```

to let the weekly digest PR merge itself when CI is green. Keep version bumps
manual.
