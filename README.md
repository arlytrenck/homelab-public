# homelab-public

A sanitized, public mirror of the Docker Compose infrastructure-as-code
behind my personal homelab — ~35 containers across 9 Compose projects on a
single VM, run the way I'd run production. Companion to
[`sysadmin-linux`](https://github.com/arlytrenck/sysadmin-linux) and
[`sysadmin-windows`](https://github.com/arlytrenck/sysadmin-windows).

**This is a showcase, not the live source.** Domain names, LAN IPs, email
addresses, and a couple of personal file-path specifics have been replaced
with placeholders (`example.com`, `10.0.0.10`, `alerts@example.com`, …).
Everything else — the compose structure, the hardening conventions, the
alerting pipeline, the actual Prometheus rules — is real.

**If you're building your own homelab**, start at
[`docs/getting-started.md`](docs/getting-started.md) rather than copying
these compose files directly — it covers what this repo assumes you already
have, a saner order to bring services up in than all-at-once, and how to
swap the placeholders for your own values. Then
[`docs/lessons-learned.md`](docs/lessons-learned.md) is every real mistake
that shaped the conventions here, so you can skip repeating them.

## Layout

| Stack | Compose | Services |
|-------|---------|----------|
| `frontend/` | `docker-compose.yaml` | homepage (dashboard) |
| `identity/` | `docker-compose.yaml` | Authelia (forward-auth SSO) |
| `media/` | `docker-compose.yaml` | Emby, Sonarr, Radarr, Prowlarr, Bazarr, Seerr, Tdarr, Komga, TinyMediaManager, Jellystat (+ its db) |
| `media/immich/` | `docker-compose.yml` | Immich server / ML / Postgres / Redis (kept close to the upstream template) |
| `monitoring/` | `docker-compose.yaml` | Prometheus, Grafana, node-exporter, cAdvisor, Uptime Kuma, Dozzle, Gotify, Alertmanager (+ a Gotify bridge), autoheal, Loki + Alloy |
| `security/` | `docker-compose.yaml` | Vaultwarden |
| `automation/` | `docker-compose.yaml` | n8n |
| `analytics/` | `docker-compose.yaml` | Umami (+ its db) — self-hosted website analytics |
| `networking/` | `bootstrap.sh` + `docker-compose.yaml` (AdGuard Home) + `README.md` | creates the shared external `frontend` Docker network; AdGuard Home = LAN DNS split-horizon + ad blocking |

One Compose project per directory; the project `name:` is set explicitly in
each file. `frontend` is an **external** Docker network shared by eight
containers across five stacks — `homepage`, `prometheus`, `grafana`,
`gotify`, `alertmanager`, `umami`, `n8n`, `adguardhome` — so they can reach
each other by container name without publishing more than necessary.
`networking/bootstrap.sh` creates it idempotently, and it has to exist before
any of those five stacks come up. `homepage` also joins `media_default` (the
media project's own network) so the Emby/*arr dashboard widgets can use
container DNS names.

## Conventions

- **Secrets never live in a compose file or a tracked file.** Each stack that
  needs them has a `chmod 600` `.env` referenced as `${VAR}` (git-ignored).
  Every key a stack references is documented, with no value, in that stack's
  `.env.example` — generated automatically, see [Tooling](#tooling) below.
- **Port publishing**:
  - Behind a reverse-proxy vhost → publish on `127.0.0.1` only.
  - Meant for direct LAN use, no vhost (homepage, Jellystat, Uptime Kuma) →
    publish on the LAN IP, never `0.0.0.0`.
  - Emby is published on **both** `127.0.0.1` (for the vhost) and the LAN IP
    (for TV / console clients that can't go through the proxy).
- **Every service** sets `security_opt: [no-new-privileges:true]`, a
  `restart:` policy, a `healthcheck`, `TZ=`, and json-file log rotation
  (`max-size: 10m`, `max-file: 5`) via the `x-common` / `x-hardening` anchor
  at the top of each file.
- **Resource limits** — every service has `mem_limit` + `pids_limit`
  (ceilings, no reservations, sized ~3-4x observed use); a couple of the
  heavier transcode/render services also cap `cpus`.
- **Databases** set `stop_grace_period: 60s` so Postgres checkpoints cleanly
  on shutdown.
- **Updates**: **Renovate** opens a PR per image bump against this repo (see
  `renovate.json` + `docs/renovate.md`); nothing auto-applies — you merge the
  PR after the `validate` workflow passes, then `docker compose up -d`.
  `:latest` images are digest-pinned and grouped into one weekly PR;
  version-tagged images and the read-notes-first set (immich, authelia,
  vaultwarden, postgres/valkey majors) get individual PRs. Watchtower was
  removed 2026-09-07 (abandoned upstream); its `enable=false` labels are inert.
- **Self-healing**: `autoheal` restarts any container labeled `autoheal=true`
  the moment Docker reports it unhealthy. Databases, the identity provider,
  and anything where a mid-flight restart would do more harm than good are
  deliberately excluded.

## Alerting pipeline

```
Prometheus rules  ->  Alertmanager  ->  alertmanager-gotify  ->  Gotify (push)
                              \-------------------------------->  email
```

Prometheus rules (`monitoring/prometheus/rules/*.yml`) set a `severity` label
(drives grouping/inhibition) and a `priority` annotation (1–10, mapped to the
Gotify push priority). Alertmanager fans every alert out to both a Gotify
bridge (for a phone push notification) and email, with a shorter repeat
interval for `severity=critical`. A `warning` for the same alert+instance is
inhibited while a `critical` for it is already firing, so a phone doesn't get
two notifications for one problem. The actual rule files are included
verbatim under [`monitoring/prometheus/rules/`](monitoring/prometheus/rules/)
— host resource pressure, container health, TLS cert expiry, and
backup-job freshness (via a node-exporter textfile collector that cron
scripts write to).

## Tooling

- **`tools/gen-env-examples.sh`** — scans every compose file for `${VAR}`
  references (and `env_file:` targets), and writes a `.env.example` next to
  each one listing every key with its compose-provided default, value blank.
  It never reads a real secret value — only key *names*, and only from
  `${VAR}` interpolation or an `env_file:` target's key list. Also writes
  [`docs/env-inventory.md`](docs/env-inventory.md), a repo-wide key × stack
  table, generated the same way. Run with `--check` in CI to fail on drift
  between the committed files and what the compose files actually reference.
- **`tools/check-compose.sh`** — runs `docker compose config` against every
  stack to catch a syntax error or a bad `${VAR:?required}` before it reaches
  a host. Seeds a throwaway `.env` from each stack's `.env.example` so a
  required-variable check doesn't fail on an intentionally-blank placeholder.
- **CI** (`.github/workflows/validate.yml`) runs all three checks — a
  [gitleaks](https://github.com/gitleaks/gitleaks) secret scan, compose
  validation, and `.env.example` drift — on every push. The same three run
  locally via `pre-commit` (`.pre-commit-config.yaml`), plus a hard block on
  ever staging a real `.env` file.
- **`tools/notify.sh`**, **`tools/push-github-repos.sh`**,
  **`tools/weekly-health-digest.sh`**, **`tools/github-ci-watch.sh`**,
  **`tools/seerr-pending-reminder.sh`**, **`tools/export-n8n-workflows.sh`** —
  the scripts behind the n8n workflows in `automation/n8n-workflows/`. Each
  one also runs standalone from a terminal or cron; n8n is just one caller.
  See [`docs/n8n-automation.md`](docs/n8n-automation.md).

## Common operations

```sh
# deploy / update a stack
docker compose -f <stack>/docker-compose.yaml up -d

# pull + recreate (manual update of a pinned/excluded stack)
docker compose -f <stack>/docker-compose.yaml pull
docker compose -f <stack>/docker-compose.yaml up -d

# validate every stack at once
tools/check-compose.sh

# regenerate every .env.example + the env inventory
tools/gen-env-examples.sh

# logs
docker compose -f <stack>/docker-compose.yaml logs -f <service>
```

## Further reading

- [`docs/getting-started.md`](docs/getting-started.md) — building your own?
  Start here: prerequisites this repo assumes, a saner bring-up order than
  all 9 stacks at once, and how to swap in your own domain/IPs.
- [`docs/architecture.md`](docs/architecture.md) — network topology, boot
  order, and how the pieces fit together.
- [`docs/hardening-conventions.md`](docs/hardening-conventions.md) — the
  reasoning behind the `x-common` anchor, resource-limit sizing, and the
  Renovate/autoheal split.
- [`docs/service-catalog.md`](docs/service-catalog.md) — every service: port,
  how it's reached, auth posture, update policy, backup coverage.
- [`docs/monitoring-and-alerting.md`](docs/monitoring-and-alerting.md) — the
  full metrics → Alertmanager → push pipeline, what's covered by rules, and
  the design choices (alert on the derivative, freshness metrics, independent
  black-box checks).
- [`docs/backup-strategy.md`](docs/backup-strategy.md) — what's protected,
  how, and an honest list of what this design still does **not** cover
  (single failure domain, key loss, ransomware).
- [`docs/runbooks/`](docs/runbooks/) — step-by-step for the recurring jobs:
  [add a service](docs/runbooks/add-a-service.md),
  [add a reverse-proxy vhost](docs/runbooks/add-a-vhost.md),
  [rotate a secret](docs/runbooks/rotate-a-secret.md).
- [`docs/lessons-learned.md`](docs/lessons-learned.md) — real mistakes this
  setup made and fixed (an exposed VNC port, NAS-mounted scratch disk,
  a clustering feature that made things worse), so you can skip them.
- [`docs/env-inventory.md`](docs/env-inventory.md) — every environment
  variable referenced across every stack, auto-generated.
- [`docs/n8n-automation.md`](docs/n8n-automation.md) — using n8n to replace
  cron for scheduled maintenance scripts, with real per-run history;
  sanitized example workflows in `automation/n8n-workflows/`.
- [`docs/renovate.md`](docs/renovate.md) — how image updates arrive as PRs,
  what's grouped vs individual, and what to set up on a fork.
- [`docs/maintenance-calendar.md`](docs/maintenance-calendar.md) — the
  daily/weekly/monthly/quarterly routine that keeps the above honest.
- [`docs/resource-library.md`](docs/resource-library.md) — upstream docs for
  each tool used here, when you need vendor behavior rather than this repo's
  opinion of it.

## What's not here

Application state and data directories, the identity provider's real config,
any real `.env` file, and the SMTP password file are all git-ignored by
design — see [`.gitignore`](.gitignore). This repo is the compose layer, not
a backup of live service data.

## License

MIT — see [LICENSE](LICENSE).
