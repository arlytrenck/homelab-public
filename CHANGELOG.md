# Changelog

Notable changes to this repo. No version tags — entries grouped by date
(commit date), newest first. Format follows
[Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
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
