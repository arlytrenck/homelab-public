# Monitoring & alerting

How the monitoring stack fits together, what's watched, and how an alert
becomes a phone notification. The rule files themselves are included verbatim
under [`monitoring/prometheus/rules/`](../monitoring/prometheus/rules/).

## Components

```
node-exporter ─┐
cadvisor ──────┤
nut-exporter ──┤
app /metrics ──┤──►  Prometheus  ──►  Alertmanager  ──►  alertmanager-gotify  ──►  Gotify (phone push)
textfile .prom ┘         │                   └──────────────────────────────────►  email
                         └──►  Grafana (dashboards, the query UI)

alloy     ──►  Loki  ──►  Grafana (logs, same pane)
Uptime Kuma  (independent black-box HTTP checks + its own status page)
Dozzle       (live container logs in a browser, no storage)
```

- **Prometheus** scrapes node-exporter (host), cadvisor (per-container),
  nut-exporter (UPS), any app that exposes `/metrics`, and a **textfile
  collector** directory that cron scripts write `.prom` files into (backup
  freshness, cert expiry, snapshot status — things that aren't a live
  endpoint).
- **nut-exporter** reads `upsd` over the network from whichever host has the
  UPS on USB — usually the hypervisor or the NAS, not the Docker host. It
  needs no NUT credentials for a read-only variable listing. See the
  [lessons-learned entry](lessons-learned.md#monitor-the-ups-from-a-container-but-let-the-os-handle-shutdown)
  on why shutdown stays the OS's job.
- **Grafana** is the query/dashboard UI for both Prometheus and Loki. Behind
  forward-auth SSO.
- **Loki + alloy** ship container logs so you can grep across all of them
  in Grafana without `docker logs` on the box. (Alloy replaced the
  now-deprecated promtail on 2026-09-07.)
- **Uptime Kuma** is deliberately *separate* — a black-box "can I actually
  reach this URL" check with its own notifications, so it still works if
  Prometheus itself is down. It also publishes a public status page.
- **Dozzle** is just live log tailing in a browser; no persistence.

## Alert path

1. A rule in `monitoring/prometheus/rules/*.yml` fires. Each rule sets:
   - a `severity` label (`warning` / `critical`) — drives grouping and
     inhibition
   - a `priority` annotation (1–10) — mapped to the Gotify push priority
2. **Alertmanager** groups related alerts, applies inhibition (a `warning`
   for an alert+instance is suppressed while a `critical` for it is
   firing — so one problem = one notification), and routes every alert to
   **both** receivers.
3. **alertmanager-gotify** is a small bridge (Alertmanager has no native
   Gotify receiver). It reads the `priority` annotation and posts to Gotify.
4. **Gotify** delivers the push to the phone app. Email is the parallel
   channel with a longer repeat interval, shorter for `severity=critical`.

## What's covered by rules

| Group | Watches |
|-------|---------|
| `host` | disk almost/critically full, disk *fill rate* (projected full in Nh), OOM risk, swap, load, clock desync, read-only fs, reboot-required, node-exporter down |
| `containers` | a critical-set container down, restart loops, sustained high memory, hard CPU throttling (excludes the ones deliberately capped) |
| `monitoring` | a scrape target missing, Prometheus config-reload failed, Alertmanager down or failing to notify, cadvisor down |
| `backup` | any backup job's last-success timestamp stale, the config-snapshot pipeline failing, `restic check` failing, the monthly restore drill stale or failed |
| `certs` | TLS leaf cert expiring soon / very soon / expired (fed by a cron script that probes each vhost) |
| `ups` | on battery, low battery, forced shutdown, low charge / runtime, replace-battery flag, overload, exporter down |

Rules are validated in CI (`promtool check rules`).

## Design choices worth stealing

- **Alert on the derivative, not just the threshold.** "Disk will be full in
  6 hours at the current fill rate" catches a runaway log *before* the
  90%-full page at 3am.
- **Freshness metrics for anything that isn't a live endpoint.** A cron job
  that writes `job_last_success_timestamp <unixtime>` to a textfile, plus a
  `time() - metric > max_age` alert, turns "did the backup run?" into a
  monitored fact.
- **Keep black-box checks independent.** Uptime Kuma doesn't share code or a
  process with Prometheus, so "everything looks green" can't be a lie told
  by a broken monitoring stack.
- **One problem, one notification.** Inhibition + grouping matter more than
  they seem — an unactionable flood trains you to ignore the channel.
- **Two channels, different urgency.** Push for "now", email for "today",
  with repeat intervals to match.

## Extending it

- New scrape target: add a job to `monitoring/prometheus/prometheus.yml`,
  `curl -X POST http://prometheus:9090/-/reload`.
- New alert: add to the appropriate `rules/*.yml` with `severity` +
  `priority`; `promtool check rules` locally; commit (CI re-checks).
- New dashboard: build in Grafana, export the JSON into the repo so it's
  version-controlled, not just live state.
