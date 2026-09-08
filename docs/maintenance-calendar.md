# Maintenance calendar

A homelab stays reliable through small, observable routines, not heroic
catch-up sessions. This is the operating rhythm the rest of this repo
assumes: what the monitoring should be answering for you daily, what's worth
20 minutes a week, and what only gets checked if you put it on a calendar.

Adapt the cadences to how much the setup matters to you. The one piece worth
keeping regardless is the quarterly restore exercise — everything else here
degrades gracefully when you skip it, and that one doesn't.

## Operating principles

- **Prefer a short window with a rollback plan** over unattended upgrades of
  stateful services. This is why image updates arrive as Renovate PRs you
  merge rather than something that applies itself — see
  [renovate.md](renovate.md).
- **A green dashboard is a starting signal, not proof that recovery works.**
  Uptime Kuma being all-green tells you services answer HTTP. It says
  nothing about whether last night's backup would restore.
- **Record exceptions with an owner and an expiry.** A skipped patch window,
  a failing backup job, a temporary firewall rule "just for today" — write
  down when it goes away, or it doesn't.
- **Change one failure domain at a time.** Don't combine a host upgrade, a
  Docker version bump, a DNS change, and an application upgrade in one
  window. When it breaks you'll have four suspects and no bisect.

## Daily — automated, no logins

The monitoring stack should answer these without you opening anything. If
you find yourself checking a dashboard daily out of anxiety, that's a
missing alert, not a routine.

1. Are all expected containers healthy, and is anything restart-looping?
   (`containers` rule group)
2. Are host disk, memory, CPU, and inode pressure inside thresholds — and is
   disk *fill rate* projecting a problem before the threshold hits?
   (`host`)
3. Did every backup job complete, and is its freshness metric current?
   (`backup`)
4. Are TLS certs comfortably ahead of expiry? (`certs`)
5. Is the UPS on mains, charged, and is its exporter up? (`ups`)
6. Is each external endpoint reachable from outside Docker? (Uptime Kuma,
   deliberately independent of Prometheus)

When an alert fires: acknowledge it, preserve the logs before anything
restarts and rotates them away, then decide whether it's an incident, a
noisy rule, or a stale metric. **Don't quietly lower a threshold to make an
alert go away** — either the threshold was wrong, in which case say so in
the commit message, or you just deleted your own warning.

## Weekly — 20 minutes

Pick a low-traffic time and look at:

- **Uptime Kuma history and Alertmanager silences.** Any silence still in
  place from last week is either a forgotten problem or a rule that needs
  fixing.
- **Containers with repeated restarts.** `autoheal` restarting something
  nightly is a masked failure, not a fix.
- **Backup artifacts.** A recent encrypted dump exists, its size is
  plausible, and retention matches what you intended. A dump that suddenly
  halves is a corrupt database or a failed dump that still exited 0.
- **Disk growth** in Docker volumes, application databases, media scratch
  space, and logs.
- **Open Renovate PRs.** Classify each as security, routine, breaking-risk,
  or deferred. Merge the ones you've read; say why the rest are waiting.
  The `review-release-notes` label exists so you don't merge a database
  major on autopilot.
- **Open infrastructure issues.** Turn vague observations into one small,
  testable next action.

A short weekly note — what changed, what you checked, what you deliberately
deferred — makes an outage far easier to reconstruct later.

## Monthly — controlled patch window

### Before

- Read release notes for everything you intend to change. Flag schema
  migrations, minimum database versions, deprecated settings, and anything
  that says the upgrade is one-way.
- Confirm backups are fresh, and that compose files, credentials, and the
  previous image digest are all available for a rollback.
- Take a database dump before any application release that might migrate
  data. Renovate's digest for the old image is your rollback target.
- Check no other high-risk maintenance is in flight.

### During

1. One stack at a time, starting with low-dependency stateless services.
2. Pull the intended image, recreate only the affected service, wait for its
   healthcheck to go green.
3. Verify its direct health endpoint, its reverse-proxy route, its auth
   path, and one real user journey. All four — a service can be healthy,
   proxied, and still 403 every request.
4. Watch logs and resource use for at least one polling interval before
   moving on.
5. Record old and new versions in `CHANGELOG.md`.

Stateful services get their own window. If migration or rollback behavior
isn't clear from the release notes, defer until it is.

## Quarterly — recovery and security exercise

One focused exercise beats a full disaster simulation you never actually
run. Rotate through these:

- **Restore a database** into a throwaway container and validate at the
  application level, not just "the file decrypted."
- **Rebuild one disposable service** from only the tracked compose file and
  its `.env.example`. This is the real test of whether
  [env-inventory.md](env-inventory.md) is complete.
- **Rotate one low-blast-radius credential** using
  [runbooks/rotate-a-secret.md](runbooks/rotate-a-secret.md).
- **Test an access-loss scenario** — a lost device, an expired VPN key, an
  identity provider that won't start. Can you still get in?
- **Verify the encryption keys.** The age private key and restic password
  are deliberately not in any backup
  ([gap #4](backup-strategy.md#what-this-does-not-protect-against)). Confirm
  your offline copy still decrypts something. This is the single failure
  that makes every other backup worthless.
- **Re-audit exposure:** `ss -tlnp` on the host, published ports, proxy
  routes, Docker socket mounts, privileged containers. Almost every real
  problem in this repo's history
  ([lessons-learned.md](lessons-learned.md#almost-everything-defaults-to-0000--go-check-yours))
  started with something bound where it shouldn't have been.

Write down the result, how long it took, what information you were missing,
and the one thing to improve. A failed exercise is only valuable if it
changes the procedure.

## Annually — resilience review

Review the design, not its current health:

- Does a backup cross a *real* failure boundary — different host, different
  storage, different account, different building? Be honest here;
  [backup-strategy.md](backup-strategy.md) is blunt that this setup is two
  copies in one location.
- Can the host be rebuilt from a clean OS using only what's in version
  control?
- Are recovery keys, DNS/registrar access, and emergency contacts reachable
  when the password manager or the primary host is the thing that's down?
- Do retention, restore time, and downtime expectations still match what
  people actually rely on? Services quietly graduate from "toy" to
  "everyone in the house uses this."

## Change record

For any non-trivial change, capture: purpose, affected services, risk and
rollback, the backup or snapshot reference, validation steps, actual
outcome, and follow-up work. Keep it next to the change — a `CHANGELOG.md`
entry or the commit message — not in a separate document that drifts.

## When to stop

Roll back when a healthcheck fails, authentication behaves unexpectedly, a
database migration turns out not to be reversible, or the change grows
beyond what you wrote down before starting.

Availability isn't the only success criterion. A service that's up but in a
state you don't understand and can't reproduce is worse than one that's
down and known-good — you can restart the second one.
