# Resource library

These are the primary references behind the patterns shown in this repository. They are selected for being maintained by the project or vendor; treat community examples as inspiration, then validate them against the authoritative documentation before deploying.

## Containers and Compose

- [Docker Compose documentation](https://docs.docker.com/compose/) — service, network, volume, lifecycle, and Compose-file reference.
- [Docker Compose CLI reference](https://docs.docker.com/reference/cli/docker/compose/) — exact behavior of validation, pull, up, logs, and config commands used in runbooks.
- [Docker Engine security](https://docs.docker.com/engine/security/) — daemon attack surface, namespaces, capabilities, and hardening context.

## Reverse proxy and identity

- [Caddy documentation](https://caddyserver.com/docs/) — official configuration and operational reference.
- [Caddy getting started](https://caddyserver.com/docs/getting-started) — configuration testing and graceful reload workflow.
- [Authelia documentation](https://www.authelia.com/integration/proxies/caddy/) — current forward-auth integration patterns for Caddy.

## Monitoring, logs, and alerts

- [Prometheus documentation](https://prometheus.io/docs/introduction/overview/) — metric model, configuration, and alerting fundamentals.
- [Alertmanager documentation](https://prometheus.io/docs/alerting/latest/alertmanager/) — grouping, routing, inhibition, and silencing behavior.
- [Grafana documentation](https://grafana.com/docs/grafana/latest/) — dashboards, alerting, and provisioning.
- [Loki documentation](https://grafana.com/docs/loki/latest/) — log aggregation concepts and operational guidance.

## Backup, recovery, and remote access

- [Restic documentation](https://restic.readthedocs.io/en/stable/) — encrypted backup repositories, retention, verification, and restore.
- [Tailscale documentation](https://tailscale.com/kb) — device identity, ACLs, routing, and DNS.
- [CISA ransomware guidance](https://www.cisa.gov/stopransomware/ransomware-guide) — recovery planning and resilient backup design.

## Security baselines

- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html) — practical container-hardening guidance.
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) — secret storage, rotation, and access-control principles.
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks) — consensus hardening baselines; use the version that matches your platform.

## How to use this list

Start with the repository's own getting-started, hardening, monitoring, and backup documents. Use these external resources when you need the current vendor behavior, release notes, or a deeper explanation. Do not copy configuration wholesale: map every setting to your own ports, identities, storage, failure boundaries, and recovery plan first.
