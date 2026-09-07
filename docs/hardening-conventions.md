# Hardening conventions

The baseline every service in this repo gets, and the reasoning behind each
piece. Applied via the `x-common`/`x-hardening` YAML anchor at the top of
each stack's compose file, so it's declared once and reused, not
copy-pasted per service.

## The baseline

```yaml
x-common: &common
  security_opt:
    - no-new-privileges:true
  logging:
    driver: json-file
    options:
      max-size: "10m"
      max-file: "5"

services:
  some-service:
    <<: *common
    mem_limit: 512m
    pids_limit: 512
    ...
```

- **`no-new-privileges:true`** — blocks a process inside the container from
  gaining more privileges than it started with (via setuid binaries, file
  capabilities, etc.), even if the image itself runs as root. Costs nothing
  for images that don't rely on privilege escalation, which is nearly all of
  them.
- **json-file log rotation** (`max-size`/`max-file`) — without this, a noisy
  container's logs grow unbounded until they fill the disk. `10m` × `5`
  files is deliberately generous for debugging headroom, not tuned tight.
- **`mem_limit` + `pids_limit`** — ceilings, not reservations. Sized at
  roughly 3-4x each service's *observed* steady-state use (checked via
  cAdvisor after the service had been running a while), not a guess from the
  image's docs. A ceiling this loose rarely triggers in normal operation; its
  job is to stop one runaway container (a log-parsing loop, a memory leak in
  a transcode job) from taking down the whole host via OOM pressure on
  everything else.
- **A `restart:` policy on everything** — `unless-stopped` almost
  everywhere, `always` on Immich's stack to match its own upstream template.
- **A `healthcheck` on every long-running service** — not just so `docker ps`
  shows something useful, but because it's the signal `autoheal` and the
  Prometheus container-health alerts both act on.

## Port publishing

Three patterns, chosen per service, not per stack:

1. **Behind the reverse-proxy vhost** → `127.0.0.1:<port>:<port>`. The proxy
   is the only thing that can reach it. This is the default for anything
   with a web UI.
2. **LAN-only, no vhost** → the LAN IP, never `0.0.0.0`. For services meant
   to be reached directly on the network and not worth a public hostname
   (an internal dashboard, a metrics UI meant for one operator).
3. **Both** — a service published on `127.0.0.1` *and* the LAN IP
   simultaneously, for the rare case where one client population goes
   through the proxy (browsers, via the vhost) and another can't (native
   apps/TVs that only take a bare IP:port).

`0.0.0.0` (all interfaces) is never used deliberately — Uptime Kuma's
`network_mode: host` service explicitly binds its own listener to the LAN IP
instead, after an earlier config left it reachable from a wider network than
intended.

## Updates: report, don't auto-apply

**Renovate** (self-hosted, a scheduled GitHub Action) opens a pull request
per image bump against this repo. Nothing auto-applies — the `docker compose
up -d` that actually deploys an update is always a deliberate human action,
after the `validate` workflow passes and (for the flagged set) the release
notes are read. `:latest` images are digest-pinned by Renovate so there's a
concrete thing to bump; the weekly digest bumps land in one grouped PR.
Services with a fragile upgrade path — a stateful database, a pair that must
move together — get individual PRs labelled `review-release-notes` that are
never auto-merged.

(This replaced Watchtower on 2026-09-07 — the `containrrr/watchtower`
upstream is abandoned. Its leftover `com.centurylinklabs.watchtower.enable`
labels are now inert.)

## Self-healing, scoped deliberately

`autoheal` restarts any container labeled `autoheal=true` the moment Docker
reports it `unhealthy`. It is **not** applied blanket-wide:

- Databases are excluded — restarting mid-transaction does more harm than a
  human noticing and investigating.
- The identity provider is excluded — an auth outage is not something you
  want auto-remediated silently; you want to know about it immediately.
- The service that *delivers* alerts is excluded from the pattern where an
  unhealthy check would restart it — a mis-firing healthcheck plus autoheal
  on the alert-delivery path itself could loop or mask the very outage it's
  supposed to report. It's watched externally (by the uptime monitor)
  instead.

Everything else — stateless or easily-resumable services (dashboard,
`*arr` apps, the alert-routing bridge) — gets the automatic restart, because
for those a silent recovery beats a 2am page for something a container
restart would have fixed anyway.

## Database shutdown

Every Postgres container sets `stop_grace_period: 60s`, giving it time to
checkpoint cleanly on `docker compose down`/`stop` instead of being SIGKILLed
mid-write when the default 10-second grace period runs out under load.
