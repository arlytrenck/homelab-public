# n8n: replacing cron with visible automation

`automation/` runs n8n as a drop-in upgrade path for scheduled maintenance
scripts — the same scripts, the same schedules, but with real per-run
history (success, failure, output) instead of a crontab that only tells you
something happened by staying silent about it.

n8n doesn't replace your scripts. Every workflow here is just a Schedule
Trigger feeding an SSH node that runs an existing script on the host, as an
unprivileged user. If a script already works from cron, it works from n8n —
the only thing that changes is where you go to see whether it ran.

## The pattern

1. **Write the script first**, as a normal standalone tool you can run and
   test from a terminal. Don't design scripts *for* n8n — design them to be
   callable by anything, and n8n is one caller among others (cron, a
   terminal, another script).
2. **One SSH credential, reused everywhere.** A dedicated keypair
   (no passphrase) whose public half sits in the target user's
   `authorized_keys`, referenced by n8n's own SSH credential type. n8n is,
   in effect, SSHing back into the same host it runs on — this gives it a
   clean, revocable credential boundary instead of mounting host SSH keys
   into the container directly.
3. **Root-requiring scripts need a scoped `sudoers.d` entry**, not a
   passwordless account. Grant `NOPASSWD` on the exact script paths that
   need it, nothing broader:
   ```
   someuser ALL=(root) NOPASSWD: /path/to/backup.sh, /path/to/sync.sh
   ```
4. **Import as JSON, don't hand-build in the UI**, if you're scripting the
   setup (see `automation/n8n-workflows/*.json` here — sanitized exports of
   the actual workflows this repo's author runs). n8n's REST API can create
   credentials, but wiring a *workflow* whose nodes execute `sudo` commands
   over SSH is exactly the kind of action an automation tool's own safety
   layer should be cautious about — expect to do that step by hand in the
   UI (Import → From file) even if everything else was scripted.
5. **Build inactive, activate deliberately.** A freshly-imported workflow
   isn't running yet — nothing double-executes against your existing cron
   while you're still testing it. Flip it on, watch it for a few real runs,
   *then* remove the matching cron line. Don't cut over all at once.

## Workflows in this repo (sanitized examples)

`automation/n8n-workflows/` has real, working examples — schedules, SSH
commands, node wiring — with only the credential references stripped (they
point at nothing outside the original install anyway). They're a reasonable
starting set if you're deciding what to automate first:

- **Nightly backup orchestration** — chain a config/DB backup script into a
  storage-mirror script into a config-snapshot script, one Schedule Trigger,
  three SSH nodes in sequence.
- **Backup + restore drill** — a daily backup run, and separately a monthly
  *deeper* run that also proves the backup actually restores. Two different
  cadences in one workflow, using two separate Schedule Trigger nodes.
- **Cert + update reporting** — a cheap daily check (TLS expiry) and a
  pricier weekly one (registry digest comparison across every running
  container), kept apart because they don't need the same frequency.
- **GitHub repo sync** — commit-drift + push across multiple git repos, each
  independent so one bad remote doesn't block the others.
- **Weekly health digest** — wraps a couple of read-only checks into one
  combined push notification instead of scripts nobody remembers to run.
- **GitHub CI watch** — a daily check that stays silent unless something's
  actually red; a "still fine" message every day would just train you to
  ignore it.
- **LAN DNS health** — every 20 minutes: does the local resolver answer at
  all, do the split-horizon rewrites still hand back the internal address
  rather than the public one, and does external recursion still work. A
  resolver that quits breaks every internal name at once, and the host's own
  fallbacks mean nothing else notices.
- **Hypervisor node health** — a read-only SSH check of the virtualization
  host from inside the guest. Swap pressure, a failed unit or a degraded pool
  on the hypervisor is invisible to monitoring that runs inside the VM it
  would take down with it.
- **Mirror watchdog** — checks that the nightly storage mirror is tracking,
  not merely exiting. A truncated read over a network share can convince
  rsync that thousands of files vanished, trip its delete guard, and abort
  the run, leaving the mirror frozen while blocked deletions pile up out of
  sight.
- **Pending-request reminder** — an example of automating around a known
  gap (here: a media-request tool with nothing downstream to fulfill
  requests) rather than only automating the happy path.

## Toolkit scripts behind them

`tools/notify.sh`, `tools/push-github-repos.sh`, `tools/weekly-health-digest.sh`,
`tools/github-ci-watch.sh`, `tools/seerr-pending-reminder.sh`,
`tools/export-n8n-workflows.sh` — all read/execute as a normal user, all
runnable standalone outside of n8n. `export-n8n-workflows.sh` is the one
that produced the JSON files above: n8n's workflow definitions live only in
its own database, so nothing else backs them up unless you export them
somewhere durable yourself.
