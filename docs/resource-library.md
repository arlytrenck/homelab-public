# Resource library

Upstream documentation for the tools this repo wires together — the place to
check when you need current vendor behavior rather than this repo's opinion
of it. Everything here is maintained by the project or vendor that owns the
thing it documents.

This is the *look it up* list.
[`getting-started.md`](getting-started.md#where-to-learn-each-piece) has the
*learn it* list — community guides, per-app tutorials, and the forums worth
searching before you assume a problem is unique to you. A handful of links
appear on both, which is fine: you reach for them for different reasons.

## Containers and Compose

- [Docker Compose](https://docs.docker.com/compose/) — the file format
  every stack here is written in. The `services`/`networks`/`volumes`
  reference is the one you'll actually keep open.
- [Docker Compose CLI](https://docs.docker.com/reference/cli/docker/compose/)
  — exact behavior of `config`, `pull`, `up`, and `logs`, which is what the
  runbooks and `tools/check-compose.sh` lean on.
- [Docker Engine security](https://docs.docker.com/engine/security/) —
  namespaces, capabilities, and daemon attack surface. Read this before
  deciding a container "needs" `privileged` or the Docker socket.

## Reverse proxy and identity

- [Caddy](https://caddyserver.com/docs/) — configuration and operations
  reference for the proxy the vhost runbook's examples are written against.
- [Caddy getting started](https://caddyserver.com/docs/getting-started) —
  specifically the validate-and-reload workflow, so a bad config never
  becomes a dead proxy.
- [Authelia + Caddy integration](https://www.authelia.com/integration/proxies/caddy/)
  — the forward-auth wiring. Worth reading in full: the
  [two-step gotcha](lessons-learned.md#a-forward-auth-block-and-an-authorization-rule-are-two-separate-steps)
  that costs everyone an afternoon lives in the gap between this page and
  Authelia's own access-control rules.

## Monitoring, logs, and alerts

- [Prometheus](https://prometheus.io/docs/introduction/overview/) — the
  metric model and PromQL. The rules in `monitoring/prometheus/rules/`
  assume you've met `rate()` and `absent()` at least once.
- [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) —
  grouping, routing, inhibition, silencing. The inhibition section explains
  the one-problem-one-notification behavior described in
  [monitoring-and-alerting.md](monitoring-and-alerting.md).
- [Grafana](https://grafana.com/docs/grafana/latest/) — dashboards,
  provisioning, and the anonymous-access settings that let panels embed on
  the homepage dashboard without exposing the interactive UI.
- [Loki](https://grafana.com/docs/loki/latest/) — log aggregation concepts,
  LogQL, and retention.

## Backup, recovery, and remote access

- [restic](https://restic.readthedocs.io/en/stable/) — repository format,
  retention, `check`, and restore. Its design page is the one to read if
  you want to know *why* it dedupes and encrypts the way it does.
- [Tailscale](https://tailscale.com/kb) — device identity, ACLs, subnet
  routing, MagicDNS. The usual way to reach the LAN-only admin UIs
  (Uptime Kuma, homepage) without publishing them.
- [CISA ransomware guide](https://www.cisa.gov/stopransomware/ransomware-guide)
  — recovery planning and what a resilient backup design actually requires.
  Read it against gap #6 in
  [backup-strategy.md](backup-strategy.md#what-this-does-not-protect-against):
  a host that can write to its own backups is the exposure it describes.

## Security baselines

- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
  — practical container hardening. Most of
  [hardening-conventions.md](hardening-conventions.md) is this list applied
  to these stacks.
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
  — storage, rotation, and access control for secrets. Pairs with
  [runbooks/rotate-a-secret.md](runbooks/rotate-a-secret.md).
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks) — consensus
  hardening baselines. Use the version matching your platform, and treat it
  as a menu rather than a mandate; plenty of it is aimed at multi-tenant
  environments a single-operator homelab isn't.

## How to use this list

Start with this repo's own docs — [getting-started](getting-started.md),
[hardening-conventions](hardening-conventions.md),
[monitoring-and-alerting](monitoring-and-alerting.md),
[backup-strategy](backup-strategy.md). They tell you what this setup does
and why. Come here when you need to know what a tool *actually* does in the
version you're running, or when something here looks wrong and you want the
authoritative answer.

Don't copy configuration wholesale from any of them, this repo included.
Map every setting to your own ports, identities, storage, failure
boundaries, and recovery plan first — the same warning
[getting-started.md](getting-started.md) opens with, and for the same
reason.
