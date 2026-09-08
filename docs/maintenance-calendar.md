# Maintenance calendar

A homelab stays reliable through small, observable routines—not heroic catch-up sessions. This calendar turns the repository's health checks, backup jobs, and review-before-apply update policy into a repeatable operating rhythm. Adapt the dates, service names, and ownership to your environment.

## Operating principles

- Prefer a short maintenance window with a rollback plan over unattended upgrades of stateful services.
- Treat a green dashboard as a starting signal, not proof that recovery works. Verify a restore path regularly.
- Record exceptions: a skipped patch window, a failing backup, or a temporary firewall rule should have an owner and an expiry date.
- Change one failure domain at a time. Avoid combining host upgrades, Docker changes, DNS changes, and application upgrades in one window.

## Daily: automated checks

The monitoring stack should answer these questions without manual logins:

1. Are all expected containers healthy and restarting normally?
2. Is host disk, memory, CPU pressure, and inode use within the alert thresholds?
3. Did the previous backup job complete, and is its freshness metric current?
4. Are TLS certificates comfortably ahead of expiry?
5. Is the external endpoint independently reachable, not merely healthy from inside Docker?

When an alert fires, acknowledge the notification, preserve the relevant logs, and decide whether it is an incident, a noisy rule, or a stale metric. Do not silently lower a threshold to make an alert disappear.

## Weekly: 20-minute service review

Pick a low-traffic time and review:

- Uptime Kuma history, Alertmanager silences, and any containers with repeated restarts.
- Backup artifacts: confirm a recent encrypted archive or database dump exists, has a plausible size, and matches the intended retention policy.
- Disk growth in Docker volumes, application databases, media scratch space, and logs.
- The open Renovate pull requests. Classify each as security, routine, breaking-risk, or deferred with a reason; merge the ones you have read, and say why the rest are waiting. See [renovate.md](renovate.md).
- Open infrastructure issues. Convert vague observations into a small, testable next action.

A useful weekly note records what changed, what was checked, and what was deliberately deferred. It makes an outage far easier to reconstruct.

## Monthly: controlled patch window

### Before

- Read release notes for every image or package you intend to change. Flag schema migrations, minimum database versions, deprecated settings, and rollback limits.
- Confirm backups are fresh and that credentials, compose files, and the prior image digest are available for rollback.
- Take a database dump before an application release that may migrate data.
- Check that no other high-risk maintenance is in progress.

### During

1. Update one stack at a time, beginning with low-dependency, stateless services.
2. Pull the intended image, recreate only the affected service, and wait for its health check.
3. Verify its direct health endpoint, reverse-proxy route, authentication path, and one core user journey.
4. Watch logs and resource use for at least one normal polling interval before moving on.
5. Record the old and new versions in the change log.

Stateful services deserve their own window. If migration or rollback behavior is unclear, defer the upgrade until it is understood.

## Quarterly: recovery and security exercise

Run one focused exercise rather than attempting a full disaster simulation every time:

- Restore a non-production copy of one database and validate application-level data.
- Rebuild one disposable service from the tracked compose files and environment-example documentation.
- Rotate one low-blast-radius credential using the secret-rotation runbook.
- Test an access-loss scenario: a lost device, expired VPN key, or unavailable identity provider.
- Review exposed ports, reverse-proxy routes, Docker socket mounts, and privileged containers.

Document the result, elapsed time, missing information, and the next improvement. A failed exercise is valuable only if it changes the procedure.

## Annual: resilience review

Review the design, not just its current health:

- Does a backup cross a real failure boundary—host, storage device, account, and location?
- Can the host be rebuilt from a clean OS without relying on untracked configuration?
- Are recovery keys, domain/DNS access, and emergency contacts accessible when the password manager or primary host is unavailable?
- Do retention, restore-time, and downtime expectations still match the services people rely on?

## Change record template

For any non-trivial change, capture: purpose; affected services; risk and rollback; backup or snapshot reference; validation steps; actual outcome; and follow-up work. Keep the entry next to the relevant compose/config change or issue so future maintainers can find it.

## When to stop

Stop and roll back when a health check fails, authentication changes unexpectedly, a database migration is not reversible, or a change expands beyond the written plan. Availability is not the only success criterion: preserve a known-good, supportable state first.
