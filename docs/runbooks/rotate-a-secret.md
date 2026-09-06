# Runbook: rotate a secret

A repeatable way to change a credential — leaked, overdue, or a departing
admin — with minimal downtime. Generic; the environment-specific per-secret
detail lives in the private repo.

## When

- **Now:** the value showed up in git history, a log, a screenshot, a chat,
  a backup that left your control, or a machine you no longer trust. Rotate
  first, investigate second. Also check the provider's audit log for misuse
  before and after.
- **Scheduled:** long-lived tokens on a calendar; after an audit finding.

## Inventory first

A secret is rarely in one place. Check: every stack `.env`, the reverse-proxy
config, the auth-provider config, helper scripts, cron job environments, CI
variables, your password manager, mobile apps, and any `*_FILE` /
`LoadCredential` references.

```sh
grep -rIl 'SECRET_NAME\|<known-prefix>' /path/to/configs 2>/dev/null
```

Know how each consumer reloads:

- Value in a compose `env_file` → needs `docker compose up -d` (a plain
  `restart` does **not** re-read it).
- Value in a systemd unit / drop-in → `daemon-reload` + `restart`.
- File the app watches → maybe hot; often still needs a `reload`/`SIGHUP`.

## Procedure (with an overlap window — preferred)

```
1. Issue a NEW credential alongside the old one (both valid).
2. Update every consumer's config to the new value.
3. Reload / recreate each consumer; verify it works on the new value.
4. Confirm the old value has had zero use for a full cycle (provider logs).
5. Revoke / delete the old credential at the provider.
6. Keep the ability to re-issue for a few days.
```

If the provider only allows one value at a time: stage every consumer's
config with the new value first, change it at the provider, then recreate
all consumers as close together as possible, with the old value + restart as
your rollback.

## Storing the new value

- Into the stack's `chmod 600` `.env` (git-ignored), referenced as `${VAR}`.
  Never inline in compose, never in a tracked file.
- Don't `export SECRET=...` in a shell — it lands in shell history. Use
  `read -s`, or write the file directly.
- Put a **pointer** in your secrets inventory ("rotated 2026-05, stored in
  the password manager at path X"), never the value itself.

## Verify

```sh
# API token: a cheap authenticated call
curl -fsS -H "Authorization: Bearer $NEW" https://api.example.com/whoami

# service came back healthy on the new value
docker compose -f <stack>/docker-compose.yaml up -d <svc>
docker inspect -f '{{.State.Health.Status}}' <svc>
docker logs --since 2m <svc> | grep -i 'auth\|denied\|forbidden'
```

Check the **provider's** log to confirm the new credential is in use and the
old one has gone quiet, then revoke the old one.

## After

- Revoke (don't just stop using) the old value.
- Purge it from anywhere it was stored insecurely: git history, old
  backups, logs, chat.
- If it was ever in git: rotation moots the exposure; also add the pattern
  to `.gitignore` + a pre-commit secret scanner (this repo uses
  [gitleaks](https://github.com/gitleaks/gitleaks)) so it can't recur.
- Update the secrets inventory: what, where, when rotated, next due.
- If incident-driven, write the short postmortem: how it leaked, what
  caught it, what prevents the next one.

## Cascades to watch

One credential is often reused downstream. Media-manager API keys in
particular get copied into an indexer manager, a subtitle tool, a request
front-end, and a stats app — rotating the source key breaks all of them
until each is updated. Map the consumers *before* you rotate.
