# Service catalog

Every service in this repo: what it's for, how it's reached, its auth
posture, and how it's updated and backed up. Hostnames are placeholders
(`example.com`); ports are the real ones from the compose files.

## Reachability legend

- **vhost + SSO** — reverse-proxy vhost, behind forward-auth
- **vhost only** — reverse-proxy vhost, service does its own auth
- **LAN IP** — published on the LAN address, no vhost
- **internal** — no published port; reached by other containers by name

## frontend

| Service | Port | Reach | Auth | Updates | State / backup |
|---------|------|-------|------|---------|----------------|
| homepage | 3000 | LAN IP + `home.example.com` | SSO (one-factor) | Renovate | config in-repo; no data |

## identity

| Service | Port | Reach | Auth | Updates | State / backup |
|---------|------|-------|------|---------|----------------|
| authelia | 9091 | `auth.example.com` | it *is* the auth | **manual** (pinned via label) | sqlite DB — nightly dump, extra-encrypted; config likewise |

## security

| Service | Port | Reach | Auth | Updates | State / backup |
|---------|------|-------|------|---------|----------------|
| vaultwarden | 8080→80 | `vault.example.com` | own login; `/api`,`/identity` bypass SSO | **manual** (pinned) | sqlite DB + `data/` — nightly dump, extra-encrypted |

## media

| Service | Port | Reach | Auth | Updates | State / backup |
|---------|------|-------|------|---------|----------------|
| emby | 8096 / 8920 | `mby.example.com` + LAN IP | own login | Renovate | metadata dir in `/docker` rsync; DB has its own scheduled export |
| sonarr | 8989 | `snr.example.com` | SSO (two-factor) | Renovate | app dir in `/docker` rsync |
| radarr | 7878 | `rdr.example.com` | SSO (two-factor) | Renovate | app dir in `/docker` rsync |
| prowlarr | 9696 | `prl.example.com` | SSO (two-factor) | Renovate | app dir in `/docker` rsync |
| bazarr | 6767 | `bzr.example.com` | SSO (two-factor) | Renovate | config in `/docker` rsync |
| seerr | 5055 | `srr.example.com` | own login (media-server SSO) | Renovate | config dir in `/docker` rsync |
| tdarr | 8265 / 8266 | `tdr.example.com` | own login | Renovate | `cpus`-capped; DB dir in `/docker` rsync |
| komga | 25600 | `kmg.example.com` | own login | Renovate | DB + `data/` in `/docker` rsync |
| tinymediamanager | 4000 (+ 5900 VNC) | `tmm.example.com` | own login | Renovate | config in `/docker` rsync; VNC bound host-only |
| jellystat | 3005→3000 | LAN IP | own login | Renovate | Postgres — nightly `pg_dumpall` (age) |
| jellystat-db | internal | — | — | Renovate | see jellystat |

## media/immich

| Service | Port | Reach | Auth | Updates | State / backup |
|---------|------|-------|------|---------|----------------|
| immich-server | internal | `immich.example.com` (`/api`,`/.well-known` bypass SSO for the mobile app) | own login + SSO on web | **manual** (pinned) | Postgres — nightly `pg_dumpall` (age); uploads on bulk storage |
| immich-machine-learning / redis / postgres | internal | — | — | pinned | see above |

## monitoring

| Service | Port | Reach | Auth | Updates | State / backup |
|---------|------|-------|------|---------|----------------|
| prometheus | 9090 | internal | — | Renovate | TSDB (not backed up — rebuildable); rules in-repo |
| grafana | 3001→3000 | `grf.example.com` | SSO (two-factor) | Renovate | `grafana.db` in `/docker` rsync |
| alertmanager | 9093 | internal (on `frontend`) | — | Renovate | config in-repo |
| alertmanager-gotify | internal | — | — | Renovate | stateless bridge |
| gotify | 8070→80 | LAN IP + `gotify.example.com` (no SSO — token auth) | app/client tokens | Renovate | messages volume (transient) |
| node-exporter / cadvisor | internal | — | — | Renovate (cadvisor digest-pinned) | stateless |
| nut-exporter | internal | — | — | Renovate | stateless; reads `upsd` on whichever host owns the UPS |
| loki | internal | — | — | Renovate | log store (transient) |
| alloy | 12345 | internal (`127.0.0.1` debug UI) | — | Renovate | ships container logs to loki; read offsets in a volume |
| uptime-kuma | 3002 | LAN IP (`network_mode: host`, binds the LAN IP only) | own login | Renovate | sqlite in `/docker` rsync |
| dozzle | 8087→8080 | `dzl.example.com` | SSO (one-factor) | Renovate | stateless (reads the Docker socket read-only) |
| autoheal | — | — | — | Renovate | restarts `autoheal=true` containers when unhealthy |

## automation / analytics / networking

| Service | Port | Reach | Auth | Updates | State / backup |
|---------|------|-------|------|---------|----------------|
| n8n | 5678 | `n8n.example.com` | SSO (two-factor) — webhooks need a path exception | Renovate | data dir in `/docker` rsync; encryption key in `.env` |
| umami | 3006→3000 | LAN IP + `stats.example.com` | own login (collect endpoint is public) | Renovate | Postgres |
| umami-db | internal | — | — | Renovate | see umami |
| adguard-home | 53 (+ 3007 UI) | LAN IP:53 + `adg.example.com` | SSO on the UI | Renovate | config via its REST API; conf dir in `/docker` rsync |

## Notes

- **"manual (pinned)"** = images pinned to a real version tag; bumped by hand
  after reading release notes (Renovate still opens the PR, it's just never
  auto-merged and carries a `review-release-notes` label). Everything else is
  on `:latest`, digest-pinned by Renovate and rolled up into one weekly PR.
  (Watchtower was removed 2026-09-07 — abandoned upstream; the leftover
  `com.centurylinklabs.watchtower.enable=false` labels are now inert.)
- **"`/docker` rsync"** = the plaintext part of the nightly backup — the
  compose tree minus secrets and live datadirs. Database *contents* get a
  separate `pg_dumpall` / sqlite `.backup`, age-encrypted.
- See [backup-strategy.md](backup-strategy.md) for what this does and
  doesn't protect against.
