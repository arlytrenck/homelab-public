# Backup strategy

What gets backed up, how, where to, and — the part most write-ups skip —
what this design still does **not** protect against. Hostnames/paths are
placeholders.

## What's protected

| Tier | Contents | Mechanism | Encryption |
|------|----------|-----------|------------|
| **Config** | the whole compose tree (compose files + non-secret service config) | nightly `rsync -a --delete` to NAS, minus secrets + live datadirs | plaintext (secrets excluded) |
| **Databases** | Postgres (`pg_dumpall`), sqlite (`.backup`) for each stateful service | nightly dump, `KEEP=N` rotation, `SHA256SUMS` | age (recipient pubkey on host; private key offline) |
| **Secrets** | forward-auth config, the immich `.env`, other secret files | nightly, bundled into one tar | age |
| **History** | everything above + a couple of extra paths | `restic` repo, `forget --keep-daily 7 --keep-weekly 8 --keep-monthly 12`, `restic check` every run | restic native (repo password on host, offline copy) |
| **Off-box copy** | the NAS is mirrored to a second NAS nightly | guarded `rsync --delete` with a `--max-delete` circuit breaker + a trash dir | inherits the above |

Config-as-code repos (this one and its private twin) are also pushed to
git nightly — a third location for the parts that live in git.

## Restore verification

- A monthly **restore drill** restic-restores a canary set, decrypts the
  newest database dump, loads it into a throwaway Postgres container, and
  counts rows — a real "does it restore", not just "does the file exist".
  Result is pushed as a notification.
- Backup **freshness** is a Prometheus metric (a cron script writes a
  node-exporter textfile); an alert fires if any job's last-success
  timestamp goes stale. See [monitoring-and-alerting.md](monitoring-and-alerting.md).

## What this does NOT protect against

Be honest about the gaps:

1. **One physical failure domain.** Both NAS units are in the same rack, on
   the same power, and (in this build) both are RAID 0. A fire, a flood, a
   theft, a bad PDU, or a controller failure that corrupts a write can take
   *both* copies. The nightly mirror also faithfully replicates a deletion
   or corruption within ~24h. **This is not 3-2-1** — it's 2 copies, 1
   location. A real off-site target (an object-storage bucket, a friend's
   box, rsync.net) is the missing leg. The restic repo makes adding one
   cheap — it just needs a second `restic` destination.
2. **A backup that runs but is wrong.** Covered *only* by the restore drill.
   If the drill breaks silently, you're back to hoping. Alert on the drill's
   own freshness/result, not just the backup jobs'.
3. **Application data not under the compose tree.** Only what's inside
   `/docker/<stack>/` is in the config rsync. Large state in named volumes
   or bind mounts elsewhere needs to be explicitly added to the backup
   scope or bind-mounted into the tree. Audit this whenever you add a
   service — see [runbooks/add-a-service.md](runbooks/add-a-service.md).
4. **The encryption keys.** The age private key and the restic repo password
   are **not** in any automated backup (by design — that would defeat the
   encryption). If you lose them, every encrypted backup is unrecoverable.
   Keep an offline copy (paper, a hardware token, a separate encrypted
   volume you control) and test that it decrypts, quarterly.
5. **Media / bulk data.** The library itself lives on the NAS and is not in
   this backup — it's treated as replaceable. Decide consciously whether
   that's acceptable for *your* library.
6. **Ransomware / a compromised host.** The host can write to the NAS mount,
   so malware on the host can encrypt the backups too. Mitigations:
   restic's append-only mode on a remote repo, NAS snapshots the host
   can't delete, a pull-based backup from a machine the host can't reach.

## If you're copying this

Minimum viable version:

1. `pg_dumpall` / sqlite `.backup` every stateful container, nightly, to a
   second machine. Encrypt if it leaves your control.
2. `rsync` the compose tree (minus secrets/data) somewhere else.
3. One restore test, by hand, before you trust any of it — then automate
   that test.
4. Add an off-site copy before you call it done. `restic` to a cheap bucket
   is a few lines.
5. Alert on backup-job freshness, or you won't notice when it stops.
