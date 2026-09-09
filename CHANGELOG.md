# Changelog

Notable changes to this repo, grouped by date (commit date), newest first.
There are no version tags — this is a continuously-updated mirror rather
than a released artifact, so there's nothing to cut a release around and no
`[Unreleased]` section. Entry types follow
[Keep a Changelog](https://keepachangelog.com/): Added, Changed, Deprecated,
Removed, Fixed, Security.

## 2026-09-09

### Fixed

- `networking/adguardhome` was the one service missing a `healthcheck` and
  `TZ`, both of which the README and `docs/hardening-conventions.md` say
  every service has. Added a web-UI `wget` healthcheck (deliberately not a
  DNS query, and deliberately not `autoheal`-labelled: see the inline
  comment) and `TZ=America/New_York`.

## 2026-09-08

### Added
- **Three missing n8n workflow exports** — `homelab-lan-dns-health`,
  `homelab-pve-node-health`, and `homelab-sync-mirror-watchdog` were running
  but had never been exported, so `automation/n8n-workflows/` didn't match
  what was actually scheduled. `N8N_API_KEY` and `N8N_EXPORT_REWRITES` are
  now documented in `automation/.env.example.extra`; neither appears in the
  compose file (both are read by `tools/export-n8n-workflows.sh`), so the
  generator can't discover them on its own. The exporter refuses to write a
  workflow still containing a real mount path, home path, private address,
  or token — an unconfigured run exports nothing rather than leaking.

### Changed
- **Editorial pass on `docs/maintenance-calendar.md` and
  `docs/resource-library.md`** — the two stylistic outliers in `docs/`:
  unwrapped 290- and 345-column lines against ~76 everywhere else, tight
  em-dashes, and generic advisory prose that could have described any
  homelab. Rewritten to the repo's own conventions and grounded in what's
  actually here. No described behavior changed.
  - `maintenance-calendar.md` — the daily list now names the Prometheus rule
    groups that answer each question (`host`, `containers`, `backup`,
    `certs`, `ups`); weekly review covers Alertmanager silences, `autoheal`
    masking a recurring failure, and open Renovate PRs; quarterly adds
    verifying the offline age/restic keys (backup-strategy gap #4 — the one
    failure that makes every other backup worthless) and an `ss -tlnp`
    exposure re-audit.
  - `resource-library.md` — each entry says *when you'd reach for it* rather
    than restating its subtitle, and the doc states its relationship to
    `getting-started.md`'s reading list: this is the look-it-up list, that
    is the learn-it list.
- **`CHANGELOG.md` restructured** to match its own stated convention. The
  header claimed "grouped by date, newest first" and Keep a Changelog, but
  an `[Unreleased]` bucket held dated `###` subsections above a bare
  `## 2026-09-05`, and two sections carried no date at all. Now `## <date>`
  per day with `### Added/Changed/Removed/Fixed` underneath. The undated
  sections were dated from git history rather than from the section above
  them — AdGuard Home and the Umami public deployment turned out to be
  2026-09-05, not 09-06.
- **Dropped filler "actually"** from `docs/getting-started.md` and
  `docs/hardening-conventions.md`.

### Fixed
- **Documentation drift** found in a review pass against the compose files,
  `prometheus.yml`, and the rules directory. Prose only, apart from the CI
  fix below.
  - **Uptime Kuma's port** in `docs/service-catalog.md` said `3001`
    (Grafana's host port). It's `3002` — `network_mode: host`,
    `UPTIME_KUMA_PORT=3002`.
  - **The `frontend` network** was described as three containers across two
    stacks in the README, `docs/architecture.md`, and `networking/README.md`.
    It's eight across five: homepage, prometheus, grafana, gotify,
    alertmanager, umami, n8n, adguardhome. The **boot order** in the latter
    two also omitted `automation` and `analytics`, both of which fail to
    start if the bootstrap hasn't run.
  - **FlareSolverr** was still in `docs/architecture.md`'s media data flow;
    it was removed from `media/` on 2026-09-07.
  - **UPS monitoring** (added 2026-09-06) never reached the reference docs:
    `nut-exporter` is now in `docs/service-catalog.md` and the
    `docs/monitoring-and-alerting.md` component list/diagram, and the `ups`
    rule group is in that doc's coverage table.
  - **Stack/container counts** — "~30 containers across 7 stacks" is ~35
    across 9 Compose projects (README, `docs/architecture.md`,
    `docs/getting-started.md`).
  - **`docs/getting-started.md`'s placeholder table** promised a complete
    find-and-replace list but omitted `10.0.0.9`, `10.0.0.0/24`, `myups`,
    and `ups-host`; following it left a silently broken UPS scrape and a
    proxy ACL on the wrong subnet.
  - **`docs/secrets.md`** was referenced by `docs/env-inventory.md` but has
    never existed; fixed in `tools/gen-env-examples.sh` so it survives
    regeneration.
  - **`docs/maintenance-calendar.md`** still described the "monitor-only
    update policy/report" — the Watchtower posture, replaced by Renovate on
    2026-09-07. The weekly review step now triages open Renovate PRs.
  - **`docs/renovate.md`, `docs/maintenance-calendar.md`, and
    `docs/resource-library.md`** are now linked from the README's Further
    reading; the latter two weren't reachable from anywhere.
- **`.github/workflows/validate.yml`** — the gitleaks job needs
  `GITHUB_TOKEN` on `pull_request` events (a gitleaks-action v2
  requirement); without it the job errored out before scanning anything.
  Push events were unaffected, which is why this only surfaced on the repo's
  first PR. PR comments are disabled so the token stays read-only.

## 2026-09-07

### Added
- **Renovate** as the image-update mechanism: `renovate.json` +
  `.github/workflows/renovate.yml` (manual-trigger in this showcase copy —
  needs a `RENOVATE_TOKEN` secret on a fork; see `docs/renovate.md`). It
  opens a PR per image bump; `:latest` images digest-pinned and grouped
  weekly; immich / *arr grouped; authelia / vaultwarden / postgres+valkey
  majors get individual `review-release-notes` PRs. README,
  `docs/hardening-conventions.md`, `docs/getting-started.md`, and
  `docs/service-catalog.md` updated; `WATCHTOWER_*` dropped from
  `monitoring/.env.example` + `docs/env-inventory.md`.
- **Alloy self-monitoring** — an `alloy` scrape job in
  `monitoring/prometheus/prometheus.yml` plus three rules in
  `rules/monitoring.yml`: `AlloyDown`, `AlloyNotShippingLogs` (the pipeline
  is up but no lines are moving), and `AlloyLogDeliveryFailing` (Loki is
  dropping writes). A log shipper that dies quietly takes your logs with it
  and nothing else notices.

### Changed
- **CI action versions** — `actions/checkout` v4 → v5 and
  `renovatebot/github-action` v40 → v46, ahead of the GitHub Actions Node 20
  deprecation.
- **Renovate scheduling consolidated** — the per-rule `schedule:` entries on
  the digest and GitHub Actions groups were redundant with the top-level
  weekly window and have been dropped; the top-level schedule now gates both.
  Added a **`forceNow`** toggle to the Run workflow dialog to ignore the
  window and open all due PRs immediately (see `docs/renovate.md`).
- **promtail → Grafana Alloy** in `monitoring/`. Grafana deprecated promtail
  (Feb 2025); Alloy is the successor. New `monitoring/alloy/config.alloy`
  (River) is a 1:1 port of the promtail docker-SD + relabel config. Alloy
  reads logs over the Docker API, so the `/var/lib/docker/containers` bind is
  gone; read offsets move to the `alloy_data` volume. Debug UI on
  `127.0.0.1:12345`. Loki/retention/Grafana datasource unchanged.
- **Pinned `komga` to `:latest`** so `docker:pinDigests` (Renovate) tracks
  it; it was previously an untagged `gotson/komga`.
- README, `docs/service-catalog.md`, `docs/monitoring-and-alerting.md`
  updated for both of the above.

### Removed
- **Watchtower** from `monitoring/` — its `containrrr/watchtower` upstream is
  abandoned. It was monitor-only here anyway (report to gotify, never
  apply). Its leftover `com.centurylinklabs.watchtower.enable` labels are
  now inert.
- **flaresolverr** from `media/` — upstream abandoned (last release
  Nov 2023), no longer clears current Cloudflare challenges.

### Fixed
- **`UMAMI_TWO_FACTOR_ENCRYPTION_KEY` had no placeholder** in
  `analytics/.env.example`, so the `.env.example` drift check failed. Given
  a placeholder value and recorded in `analytics/.env.example.extra` +
  `docs/env-inventory.md`.

## 2026-09-06

### Added
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
- **`monitoring/`** — UPS visibility via NUT: a `nut-exporter` container
  scrapes `upsd` on whichever host owns the UPS USB link, a `nut`
  Prometheus job ingests it, and `prometheus/rules/ups.yml` alerts on
  on-battery / low-battery / forced-shutdown / low-runtime / exporter-down.
  New `docs/lessons-learned.md` entry on why shutdown is usually the OS's
  job, not a per-VM NUT client.
- **`docs/maintenance-calendar.md`** and **`docs/resource-library.md`** —
  an operating rhythm for the routines above, and a per-category list of
  upstream references.

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
- **`networking/`** — AdGuard Home: LAN DNS resolver with per-domain
  rewrites (the pattern you need if a service has a public DNS record but
  fails to resolve from inside your own LAN — the router usually can't
  hairpin-NAT a LAN client's request back in through its own WAN IP) plus
  network-wide ad/tracker blocking. Configured via AdGuard's own REST API
  rather than a hand-written config file — see the compose file's header
  comment for why. New `docs/lessons-learned.md` entry on the hairpin-NAT
  gotcha itself.

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
