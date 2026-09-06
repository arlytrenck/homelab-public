# Runbook: add a service

A checklist for adding a container so it ends up monitored, backed up, and
reachable — not orphaned. Generic; adapt paths/hostnames.

## 1. Compose

- Add the service to the right stack's compose file using that file's
  `x-common` / `x-hardening` anchor, so it inherits
  `no-new-privileges`, a `restart:` policy, log rotation, and `TZ`.
- Set explicitly: `container_name`, `image`, `healthcheck`, `mem_limit`,
  `pids_limit` (~3–4× expected use), and `autoheal=true` **unless** a
  mid-flight restart is harmful (databases, the identity provider).
- **Publish ports narrowly:**
  - fronted by the reverse proxy → bind `127.0.0.1:<port>` only
  - direct LAN client, no vhost → bind the **LAN IP**, never `0.0.0.0`
  - internal only → no `ports:` at all
- Attach the shared `frontend` network (`external: true`) only if another
  stack must reach it by container name.

```sh
docker compose -f <stack>/docker-compose.yaml config -q
docker compose -f <stack>/docker-compose.yaml up -d
docker compose -f <stack>/docker-compose.yaml logs -f <service>
```

## 2. Secrets

- Any secret goes in the stack's `chmod 600` `.env` (git-ignored), as
  `${VAR}` in compose — never inline, never in a tracked file.
- Regenerate the examples so CI's drift check passes:
  `bash tools/gen-env-examples.sh`.
- A var read by a helper script rather than compose → add it to
  `<stack>/.env.example.extra`.

## 3. Reverse proxy + auth (if it gets a hostname)

Follow [add-a-vhost.md](add-a-vhost.md). The key point: a forward-auth block
in the proxy and an **authorization rule** in the auth provider are two
separate steps — do both, or the provider's default-deny returns 403 for
everything and it looks like a proxy bug. (See
[lessons-learned.md](../lessons-learned.md#a-forward-auth-block-and-an-authorization-rule-are-two-separate-steps).)

## 4. Dashboard

- Add a tile (and a widget + its `*_KEY` in the dashboard stack's `.env`
  if supported).
- Recreate the dashboard container with `up -d`, not `restart` — `restart`
  doesn't re-read `env_file`.

## 5. Monitoring

- Exposes `/metrics`? Add a Prometheus scrape job and reload.
- Belongs in the "critical set"? Add it to the `ContainerDown` rule.
- Add a black-box check (Uptime Kuma or equivalent) for its URL.

## 6. Backups

- Has a database? Add a dump step to the backup script (mirror the existing
  Postgres/sqlite pattern; encrypt; rotate; checksum) and a restore path.
- Has state in a named volume or a path **outside** the compose tree? It
  is **not** in the config rsync — bind it into the tree or add it to the
  backup scope. See [backup-strategy.md](../backup-strategy.md) gap #3.

## 7. Document + commit

- Row in [service-catalog.md](../service-catalog.md).
- Stack list in the README; dated `CHANGELOG.md` entry.
- New stack? README layout table + [architecture.md](../architecture.md)
  boot order + the network bootstrap script.

```sh
git add -A && git commit -m "<stack>: add <service>"
```

## 8. Verify end to end

```sh
docker ps --filter name=<service>                              # healthy
curl -sko /dev/null -w '%{http_code}\n' https://<host>/        # 200/302, not 403/000
```
403 → authorization rule missing (step 3). 000 → DNS/cert not ready. 502 →
proxy up, backend port wrong.
