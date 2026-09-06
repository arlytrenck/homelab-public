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
| homepage | 3000 | LAN IP + `home.example.com` | SSO (one-factor) | Watchtower (report) | config in-repo; no data |

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
| emby | 8096 / 8920 | `mby.example.com` + LAN IP | own login | Watchtower | metadata dir in `/docker` rsync; DB has its own scheduled export |
| sonarr | 8989 | `snr.example.com` | SSO (two-factor) | Watchtower | app dir in `/docker` rsync |
| radarr | 7878 | `rdr.example.com` | SSO (two-factor) | Watchtower | app dir in `/docker` rsync |
| prowlarr | 9696 | `prl.example.com` | SSO (two-factor) | Watchtower | app dir in `/docker` rsync |
| bazarr | 6767 | `bzr.example.com` | SSO (two-factor) | Watchtower | config in `/docker` rsync |
| flaresolverr | 8191 | internal | none (Prowlarr calls it) | Watchtower | stateless |
| seerr | 5055 | `srr.example.com` | own login (media-server SSO) | Watchtower | config dir in `/docker` rsync |
| tdarr | 8265 / 8266 | `tdr.example.com` | own login | Watchtower | `cpus`-capped; DB dir in `/docker` rsync |
| komga | 25600 | `kmg.example.com` | own login | Watchtower | DB + `data/` in `/docker` rsync |
| tinymediamanager | 4000 (+ 5900 VNC) | `tmm.example.com` | own login | Watchtower | config in `/docker` rsync; VNC bound host-only |
| jellystat | 3005→3000 | LAN IP | own login | Watchtower | Postgres — nightly `pg_dumpall` (age) |
| jellystat-db | internal | — | — | Watchtower | see jellystat |

## media/immich

| Service | Port | Reach | Auth | Updates | State / backup |
|---------|------|-------|------|---------|----------------|
| immich-server | internal | `immich.example.com` (`/api`,`/.well-known` bypass SSO for the mobile app) | own login + SSO on web | **manual** (pinned) | Postgres — nightly `pg_dumpall` (age); uploads on bulk storage |
| immich-machine-learning / redis / postgres | internal | — | — | pinned | see above |

## monitoring

| Service | Port | Reach | Auth | Updates | State / backup |
|---------|------|-------|------|---------|----------------|
| prometheus | 9090 | internal | — | Watchtower | TSDB (not backed up — rebuildable); rules in-repo |
| grafana | 3001→3000 | `grf.example.com` | SSO (two-factor) | Watchtower | `grafana.db` in `/docker` rsync |
| alertmanager | 9093 | internal (on `frontend`) | — | Watchtower | config in-repo |
| alertmanager-gotify | internal | — | — | Watchtower | stateless bridge |
| gotify | 8070→80 | LAN IP + `gotify.example.com` (no SSO — token auth) | app/client tokens | Watchtower | messages volume (transient) |
| node-exporter / cadvisor | internal | — | — | Watchtower (cadvisor digest-pinned) | stateless |
| loki / promtail | internal | — | — | Watchtower | log store (transient) |
| uptime-kuma | 3001 | LAN IP | own login | Watchtower | sqlite in `/docker` rsync |
| dozzle | 8087→8080 | `dzl.example.com` | SSO (one-factor) | Watchtower | stateless (reads the Docker socket read-only) |
| watchtower | — | — | — | self | monitor-only: reports, never applies |
| autoheal | — | — | — | Watchtower | restarts `autoheal=true` containers when unhealthy |

## automation / analytics / networking

| Service | Port | Reach | Auth | Updates | State / backup |
|---------|------|-------|------|---------|----------------|
| n8n | 5678 | `n8n.example.com` | SSO (two-factor) — webhooks need a path exception | Watchtower | data dir in `/docker` rsync; encryption key in `.env` |
| umami | 3006→3000 | LAN IP + `stats.example.com` | own login (collect endpoint is public) | Watchtower | Postgres |
| umami-db | internal | — | — | Watchtower | see umami |
| adguard-home | 53 (+ 3007 UI) | LAN IP:53 + `adg.example.com` | SSO on the UI | Watchtower | config via its REST API; conf dir in `/docker` rsync |

## Notes

- **"manual (pinned)"** = carries `com.centurylinklabs.watchtower.enable=false`;
  bumped by hand after reading release notes. Everything else follows
  `:latest` and Watchtower reports (never applies) new digests nightly.
- **"`/docker` rsync"** = the plaintext part of the nightly backup — the
  compose tree minus secrets and live datadirs. Database *contents* get a
  separate `pg_dumpall` / sqlite `.backup`, age-encrypted.
- See [backup-strategy.md](backup-strategy.md) for what this does and
  doesn't protect against.
