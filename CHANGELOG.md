# Changelog

Notable changes to this repo. No version tags — entries grouped by date
(commit date), newest first. Format follows
[Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Fixed (2026-09-08 — documentation drift)
Docs that no longer matched the compose files, found in a review pass. No
config changed; only the prose describing it.
- **Uptime Kuma's port** in `docs/service-catalog.md` said `3001` (Grafana's
  host port). It's `3002` — `network_mode: host`, `UPTIME_KUMA_PORT=3002`.
- **The `frontend` network** was described as three containers across two
  stacks in the README, `docs/architecture.md`, and `networking/README.md`.
  It's eight containers across five: homepage, prometheus, grafana, gotify,
  alertmanager, umami, n8n, adguardhome. The **boot order** in the latter two
  also omitted `automation` and `analytics`, both of which now fail to start
  if the bootstrap hasn't run.
- **FlareSolverr** was still in `docs/architecture.md`'s media data flow;
  it was removed from `media/` on 2026-09-07.
- **UPS monitoring** (added 2026-09-06) never reached the reference docs:
  `nut-exporter` is now in `docs/service-catalog.md` and the
  `docs/monitoring-and-alerting.md` component list/diagram, and the `ups`
  rule group is in that doc's coverage table.
- **Stack/container counts** — "~30 containers across 7 stacks" is ~35 across
  9 Compose projects (README, `docs/architecture.md`,
  `docs/getting-started.md`).
- **`docs/getting-started.md`'s placeholder table** promised a complete
  find-and-replace list but omitted `10.0.0.9`, `10.0.0.0/24`, `myups`, and
  `ups-host`; a reader following it got a silently broken UPS scrape and a
  proxy ACL on the wrong subnet.
- **`docs/secrets.md`** was referenced by `docs/env-inventory.md` but has
  never existed; fixed in `tools/gen-env-examples.sh` so it survives
  regeneration.
- **`docs/renovate.md`, `docs/maintenance-calendar.md`, and
  `docs/resource-library.md`** are now linked from the README's Further
  reading; the latter two weren't reachable from anywhere.

### Changed (2026-09-07 — deprecated-image cleanup)
- **promtail → Grafana Alloy** in `monitoring/`. Grafana deprecated promtail
  (Feb 2025); Alloy is the successor. New `monitoring/alloy/config.alloy`
  (River) is a 1:1 port of the promtail docker-SD + relabel config. Alloy
  reads logs over the Docker API, so the `/var/lib/docker/containers` bind is
  gone; read offsets move to the `alloy_data` volume. Debug UI on
  `127.0.0.1:12345`. Loki/retention/Grafana datasource unchanged.
- **Removed flaresolverr** from `media/` — upstream abandoned (last release
  Nov 2023), no longer clears current Cloudflare challenges.
- **Pinned `komga` to `:latest`** so `docker:pinDigests` (Renovate) tracks
  it; it was previously an untagged `gotson/komga`.
- README, `docs/service-catalog.md`, `docs/monitoring-and-alerting.md` updated.

### Changed (2026-09-07 — Watchtower → Renovate)
- **Removed Watchtower** from `monitoring/` — its `containrrr/watchtower`
  upstream is abandoned. It was monitor-only here anyway (report to gotify,
  never apply).
- **Added Renovate** as the replacement: `renovate.json` +
  `.github/workflows/renovate.yml` (manual-trigger in this showcase copy —
  needs a `RENOVATE_TOKEN` secret on a fork; see `docs/renovate.md`). It
  opens a PR per image bump; `:latest` images digest-pinned + grouped weekly;
  immich / *arr grouped; authelia / vaultwarden / postgres+valkey majors get
  individual `review-release-notes` PRs. README, `docs/hardening-conventions.md`,
  `docs/getting-started.md`, `docs/service-catalog.md` updated;
  `WATCHTOWER_*` dropped from `monitoring/.env.example` + `docs/env-inventory.md`.

### Added (2026-09-06)
- **`docs/` expanded** — six new files, linked from the README's Further
  reading section:
  - `docs/service-catalog.md` — every service: port, how it's reached, auth
    posture, update policy (Watchtower report vs pinned/manual), and backup
    coverage.
  - `docs/monitoring-and-alerting.md` — the metrics → Alertmanager →
    Gotify/email pipeline in full, what each rule group watches, and the
    design choices worth stealing (alert on the fill-rate derivative,
    freshness metrics via the textfile collector, keeping black-box checks
    independent, one-problem-one-notification).
  - `docs/backup-strategy.md` — the protected tiers *and* an honest list of
    what the design does **not** cover: single physical failure domain / not
    3-2-1, a backup that runs but is wrong, state outside the compose tree,
    encryption-key loss, ransomware from a compromised host.
  - `docs/runbooks/add-a-service.md`, `docs/runbooks/add-a-vhost.md`,
    `docs/runbooks/rotate-a-secret.md` — proxy-neutral, sanitized
    step-by-steps for the recurring jobs, each cross-linking the relevant
    `lessons-learned.md` entry (notably the forward-auth-block vs
    authorization-rule two-step).

### Changed
- **`analytics/`** — Umami went from a LAN-only trial to a real public
  deployment: a dedicated reverse-proxy vhost now exposes the tracking
  script + collect endpoint (and Umami's own login-gated dashboard) to the
  internet, deliberately with no LAN-guard or SSO in front since anonymous
  visitors' browsers need to reach the tracking script. Added
  `TWO_FACTOR_ENCRYPTION_KEY` (same format requirement as `APP_SECRET` — a
  64-char hex string, not base64) now that 2FA on the admin account
  actually matters with the login internet-facing. `.env.example` +
  `docs/env-inventory.md` regenerated to match.

### Added
- **`monitoring/`** — UPS visibility via NUT: a `nut-exporter` container
  scrapes `upsd` on whichever host owns the UPS USB link, a `nut`
  Prometheus job ingests it, and `prometheus/rules/ups.yml` alerts on
  on-battery / low-battery / forced-shutdown / low-runtime / exporter-down.
  New `docs/lessons-learned.md` entry on why shutdown is usually the OS's
  job, not a per-VM NUT client.
- **`networking/`** — AdGuard Home: LAN DNS resolver with per-domain
  rewrites (the pattern you need if a service has a public DNS record but
  fails to resolve from inside your own LAN — the router usually can't
  hairpin-NAT a LAN client's request back in through its own WAN IP) plus
  network-wide ad/tracker blocking. Configured via AdGuard's own REST API
  rather than a hand-written config file — see the compose file's header
  comment for why. New `docs/lessons-learned.md` entry on the hairpin-NAT
  gotcha itself.

## 2026-09-05

### Added
- **Initial public commit** — sanitized Compose stacks (domains, IPs, and
  real secrets redacted/genericized) mirroring the private homelab:
  identity (Authelia), security (Vaultwarden), media, monitoring, frontend
  (Homepage), automation (n8n).
- `docs/getting-started.md` and `docs/lessons-learned.md` for anyone
  building something similar.
- `docs/` resource list expanded with per-category references.
- `automation/` — n8n examples: sanitized workflow JSON, generic toolkit
  scripts (placeholder repo lists, not the private originals), its own
  `docs/n8n-automation.md`.
- `monitoring/` — Loki + Promtail (log aggregation) and `analytics/` —
  Umami (self-hosted website analytics), plus 2 new lessons-learned
  entries (the Authelia two-step gotcha; multi-query Grafana panels
  needing unique `refId`s).
