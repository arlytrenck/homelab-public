# Architecture

One Proxmox host, one Ubuntu Server LTS VM, everything else in Docker
Compose. ~30 containers across 7 stacks (see the [README](../README.md) for
the full service list).

## Network topology

```
                       Internet
                          |
                    reverse proxy (TLS termination, DNS-01 certs)
                          |
              +-----------+-----------+
              |                       |
        forward-auth SSO         direct passthrough
      (admin UIs, dashboards)   (media clients, public pages)
              |                       |
        Docker containers on 127.0.0.1, reached by vhost
```

- Every admin UI (the `*arr` stack, Grafana, n8n, Vaultwarden, Authelia
  itself) publishes on `127.0.0.1` only. The reverse proxy is the only thing
  that can reach it, and forward-auth sits in front of the proxy for anything
  that isn't meant to be anonymous.
- A handful of services have no reverse-proxy vhost at all and instead
  publish straight on the LAN IP, because their client can't go through a
  browser-facing proxy (Emby's native apps/TVs) or because they're LAN-only
  tooling with no need for a public hostname (homepage, Uptime Kuma,
  Jellystat).
- Two Docker networks cross stack boundaries: `frontend` (external, created
  once by `networking/bootstrap.sh`) lets `homepage` reach `grafana` and
  `prometheus` by container name; `media_default` (auto-created by the
  `media/` project) lets `homepage`'s dashboard widgets reach Emby/`*arr` by
  name now that those services no longer publish on the LAN IP.

## Boot order

```
networking bootstrap  ->  media  ->  monitoring  ->  identity  ->  security
                      ->  media/immich  ->  frontend
```

`frontend` (the homepage dashboard) has to come up last — it depends on both
the `frontend` Docker network existing and the `media_default` network
already existing (created when `media/` first comes up).

## Data flow

- **Media**: Sonarr/Radarr manage the library, Prowlarr feeds them indexers
  (via FlareSolverr for Cloudflare-protected trackers), Bazarr attaches
  subtitles, Seerr is the request front-end, Tdarr transcodes in the
  background, Emby serves playback, Jellystat reads Emby's own playback
  history for watch-stats.
- **Photos**: Immich is close to the upstream reference compose file on
  purpose — server, ML (face/object recognition), Postgres, Redis — so
  upgrades stay a matter of pulling the latest upstream file and re-applying
  the same handful of local changes (loopback-only port, hardening
  anchors, health-gated startup order).
- **Monitoring**: see the alerting-pipeline diagram in the
  [README](../README.md#alerting-pipeline). node-exporter and cAdvisor feed
  host- and container-level metrics into Prometheus; Grafana visualizes both,
  fronted by the same forward-auth SSO as everything else, plus an anonymous
  read-only mode scoped so dashboard *panels* can be embedded on the homepage
  dashboard without exposing the interactive UI.
- **Backups**: covered at a narrative level on the
  [homelab page of my site](https://trenck.net/homelab/) — encrypted
  database dumps, a deduplicated `restic` repository, a mirrored off-host
  copy, and a monthly restore drill that reports pass/fail as a Prometheus
  metric (see `monitoring/prometheus/rules/backup.yml`). The backup scripts
  themselves aren't in this repo; the generic, reusable pieces of that
  toolkit (backup verification, restore drills, cert-expiry checks) are in
  [`sysadmin-linux`](https://github.com/arlytrenck/sysadmin-linux) instead.

## Why this structure

One Compose project per concern (media, monitoring, identity, …) rather than
one giant compose file, so a change to one stack's resource limits or a
`docker compose up -d` for one service doesn't risk touching every other
service's containers. The tradeoff is the two shared networks above — the
minimum needed to let a couple of services cross those boundaries by name
instead of by publishing more than necessary on the LAN IP.
