# networking — shared Docker networks

Some stacks attach to a Docker network they don't own, declared in their compose
as `external: true`. Those networks must exist before those stacks come up
(and must be recreated after `docker network prune`).

## `frontend`  (bridge)

Cross-stack network so services in different Compose projects can reach each
other by container name instead of publishing a port on the LAN IP.

- **Created by:** this file's `bootstrap.sh` (or `docker network create frontend`).
- **Attached by:** five stacks, each declaring it `external: true` —
  `frontend/` (homepage), `monitoring/` (prometheus, grafana, gotify,
  alertmanager), `analytics/` (umami), `automation/` (n8n), and
  `networking/` (adguardhome).

All five fail to start if the network doesn't exist, so `bootstrap.sh` runs
before any of them — including this directory's own compose file.

```sh
bash networking/bootstrap.sh
```

## `media_default`  (bridge)

Auto-created by the `media/` compose project (`<name>_default`). `homepage`
attaches to it as `external` so the Emby / *arr widgets can use container DNS
names now that those services publish on `127.0.0.1` only. Nothing to create
here — just bring `media/` up before `frontend/`.

## Boot order

```
networking bootstrap          (creates the external `frontend` network)
  ->  networking  ->  media  ->  monitoring  ->  identity  ->  security
  ->  media/immich  ->  automation  ->  analytics  ->  frontend
```
Bootstrap first: five stacks won't start without the `frontend` network.
`frontend` last: it needs both `frontend` and `media_default`.
