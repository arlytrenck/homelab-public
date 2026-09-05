# Getting started, if you're building your own

This repo is a reference, not a one-command installer — every stack assumes
you'll read it, adjust it for your own hardware/domain/network, and bring it
up deliberately. That's a deliberate choice: copy-pasting someone else's
infrastructure without understanding it is how you end up debugging a
stranger's decisions at 2am. This doc is the path through it.

## What you need before any of this is useful

- **A Linux host** with Docker + the Compose plugin. A single VM or a spare
  machine is plenty to start — this whole setup runs on one 16-core/54 GB VM.
- **A domain you control**, if you want anything reachable by name instead of
  a bare IP. You don't need one on day one.
- **A reverse proxy** (Caddy, Traefik, nginx, nginx-proxy-manager — pick one).
  **This repo does not include one.** The compose files here assume a
  reverse proxy exists on the host and forwards `subdomain.yourdomain.com`
  to `127.0.0.1:<port>` for whichever service — that piece lives outside
  Docker, in whatever the proxy's own config format is, and is genuinely
  a separate decision from anything in this repo. Caddy's automatic HTTPS
  is the lowest-friction option if you've never set one up.
- **A forward-auth provider**, only once you want single sign-on across
  multiple admin UIs instead of each one having its own login (Authelia,
  Authentik, or your proxy's built-in basic auth for a quick start).

## Don't start with all of this at once

Bringing up all 7 stacks on day one is the wrong way to learn this. A
reasonable order, each step small enough to actually understand before
moving on:

1. **One service, no proxy, no auth.** Pick something simple (a `*arr` app,
   or Vaultwarden) and run just its `docker-compose.yaml`, reached by
   `http://your-host-ip:port`. Confirm `docker compose logs` and
   `docker compose ps` make sense to you before adding anything else.
2. **Add the reverse proxy**, front that one service with a real subdomain
   and TLS. This is usually the step with the steepest learning curve
   (DNS records, cert issuance, proxy config syntax) — get comfortable here
   before stacking more services behind it.
3. **Add forward-auth**, once you have more than one admin UI you don't want
   a separate login for. `identity/` here is a minimal Authelia example.
4. **Add monitoring last**, once you have enough running that "is everything
   still up" stops being a question you can answer by just looking. Trying
   to set up Prometheus/Alertmanager/alerting rules before you have anything
   worth alerting on is a lot of upfront complexity for no payoff yet.

Once each step makes sense on its own, `docs/architecture.md`'s
[boot order](architecture.md#boot-order) is how these stacks actually depend
on each other here.

## Adapting this to your own setup

Every placeholder in this repo is deliberately obvious rather than realistic,
so a find-and-replace catches all of it:

| Placeholder | Replace with |
|---|---|
| `example.com` | your actual domain |
| `10.0.0.10` | your host's actual LAN IP |
| `alerts@example.com` | an email you actually read |
| `homelab-01` | whatever you want your Prometheus `instance` label to say |

Then, stack by stack:

1. Copy the stack directory you want.
2. Run `tools/gen-env-examples.sh` — it reads the compose file's `${VAR}`
   references and writes a fresh `.env.example` for it.
3. Copy that to `.env`, fill in real values, `chmod 600` it. **Never commit
   `.env`** — the `.gitignore` and pre-commit hook here both block it, but
   the discipline matters more than the tooling.
4. `tools/check-compose.sh` before you `up -d`, so a typo or a missing
   required variable shows up as a clear error instead of a container that
   won't start.

## Before you copy a pattern, understand why it's there

[`docs/hardening-conventions.md`](hardening-conventions.md) explains the
reasoning behind every convention here (why `no-new-privileges`, why
`mem_limit` sized the way it is, why Watchtower only reports instead of
auto-applying updates). [`docs/lessons-learned.md`](lessons-learned.md) is
the mistakes that shaped those conventions — read it before you repeat them.
The single most valuable habit either doc can hand you: after adding any new
service, run `ss -tlnp` and actually look at what it bound to. Almost every
real problem in this repo's history started with a service quietly
listening somewhere it shouldn't have.

## Where to actually learn each piece

This repo shows *how the pieces fit together*, not how each tool works on
its own. Each project's own docs do that better than a README ever could:

- [Docker Compose](https://docs.docker.com/compose/) — the file format and
  CLI everything here is written in.
- [Caddy](https://caddyserver.com/docs/) — the lowest-friction reverse proxy
  with automatic HTTPS, if you don't already have a preference.
- [Authelia](https://www.authelia.com/overview/prologue/introduction/) — the
  forward-auth pattern `identity/` demonstrates.
- [Prometheus](https://prometheus.io/docs/introduction/overview/) +
  [Alertmanager](https://prometheus.io/docs/alerting/latest/overview/) —
  the metrics and alerting model behind `monitoring/`.
- [r/selfhosted](https://www.reddit.com/r/selfhosted/) and
  [r/homelab](https://www.reddit.com/r/homelab/) — for "has anyone else hit
  this" before you assume a problem is unique to your setup.
