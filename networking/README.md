# networking — shared Docker networks

Some stacks attach to a Docker network they don't own, declared in their compose
as `external: true`. Those networks must exist before those stacks come up
(and must be recreated after `docker network prune`).

## `frontend`  (bridge)

Cross-stack network so `homepage` can reach `grafana` / `prometheus` by name.

- **Created by:** this file's `bootstrap.sh` (or `docker network create frontend`).
- **Attached by:** `frontend/` (homepage), `monitoring/` (prometheus, grafana) —
  each declares it `external: true`.

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
networking bootstrap  ->  media  ->  monitoring  ->  identity  ->  security
                      ->  media/immich  ->  frontend
```
`frontend` last: it depends on both the `frontend` network and `media_default`.
