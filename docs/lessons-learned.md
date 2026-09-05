# Lessons learned

Mistakes made and fixed while building this, kept here so you don't have to
repeat them. Every one of these was a real problem on this exact setup, not a
theoretical concern.

## Almost everything defaults to `0.0.0.0` — go check yours

The single most common mistake across this whole setup, found repeatedly
across an audit pass: a service publishes on `0.0.0.0` (all interfaces) by
default, and it's easy to never notice because `127.0.0.1` and `0.0.0.0` both
"just work" from the machine itself. The difference only shows up when
something on the LAN — or worse, a VPN/mesh network, or a misconfigured
router — can reach a port you thought was local-only.

The worst instance of this here: a media-library manager's **VNC port**
(used for its remote-desktop UI) was sitting on `0.0.0.0:5900`, completely
unauthenticated, reachable from anywhere on the LAN. Nothing exploited it,
but it sat that way for a while before an audit pass caught it.

**The fix**, applied to every service in this repo (see the
[hardening conventions](hardening-conventions.md#port-publishing) doc):
publish on `127.0.0.1` if a reverse proxy fronts it, or the specific LAN IP
if it doesn't — `0.0.0.0` is never the right default. Run `ss -tlnp` (or
`docker port <container>`) periodically and actually look at what's bound to
`*` versus a specific address; it's easy for one new service to slip back
into the bad default and go unnoticed for months.

## Don't put I/O-heavy scratch space on network storage

A transcoding job was writing every partial frame of every job to a NAS
share over the network (CIFS/SMB), then reading it back — because the
media library itself lives there, and it was the path of least resistance to
point the scratch directory at the same mount. The share had spare local
disk sitting almost empty the entire time.

This doesn't just add latency — it makes an unrelated failure mode (a
network hiccup, the NAS being briefly unreachable) able to corrupt or stall
a job that has nothing to do with the network. The library (source data)
belongs on shared/network storage; a job's *working* directory belongs on
the fastest local disk you have, moved back to shared storage only once the
job finishes.

## A clustering feature can be worse than none, for a single node

Alertmanager supports a gossip-protocol cluster for high-availability pairs.
Left on by default with only one Alertmanager instance running, it wedged
the notification dispatcher after a batch of failed deliveries and silently
stopped delivering *any* alert until the container was restarted — which is
exactly the failure mode alerting exists to catch you *not* noticing.
`--cluster.listen-address=` (empty) disables it. If you're not running an HA
pair, don't leave HA features on "in case" — verify what they actually do
when a peer never shows up.

## A stale `:latest` tag can quietly stop moving

One image's `:latest` tag on its registry hadn't moved in a long time —
newer builds existed, just not tagged `latest` on that particular registry
mirror. An automatic-update tool had nothing to compare against and would
never have caught it. The fix isn't automatable: pin that one image to a
content digest, and bump it by hand from the project's own release page on
a schedule you set, rather than assuming "checks for updates" catches every
image equally.

## Plaintext credential files outside git are still a problem

Secrets never went into this git repo — but an audit pass still found two
plaintext credential files sitting on disk *outside* version control,
created early on as a quick note-to-self and never cleaned up. Not tracked
by git doesn't mean not a real exposure — anything on disk in plaintext is
one misconfigured backup, one wrong `tar`, one compromised account away from
leaking. If you write a password down while setting something up, put it in
a password manager immediately and delete the scratch file — don't let
"I'll clean it up later" become a permanent state.

## Resist reaching for a second tool when the first one already does the job

A dedicated job-scheduling tool (Rundeck) was deployed specifically to give
some cron-driven backup scripts real run-history and a UI, instead of a
silent crontab. It was removed the same day: the workflow-automation tool
already running here (n8n) could do the exact same job — trigger a script
over SSH on a schedule, log the result, alert on failure — via one workflow
using a feature it already had, at zero additional memory footprint. The
dedicated tool's actual advantages (multi-user RBAC, audit policies) matter
for a team, not a single-operator homelab. Before adding a new service,
check whether something you're already running can do 90% of the job first.

## A forward-auth block and an authorization rule are two separate steps

Wiring a new subdomain up to forward-auth-based SSO has two halves: the
reverse proxy config that says "ask the auth service before letting this
through," and the auth service's own policy that says what the answer
should be for that specific domain. Adding only the first half looks
completely correct in the proxy config — the directive is right there,
pointed at the right auth endpoint — and still 403s every request,
including from the person who configured it, because the auth service's
default policy for anything it doesn't recognize is deny. The failure mode
looks like a network/firewall problem (a wrong IP allowlist, a NAT
oddity) long before it looks like "I forgot the other half," because
nothing about the proxy config is actually wrong. If a new forward-auth
vhost 403s everyone regardless of source, check the auth service's own
access-control rules before anything else.

## A dashboard panel with more than one query needs a unique ID per query

A handful of dashboard panels that plotted multiple series (memory used +
cached, three load averages, network rx/tx) all silently showed "No data,"
while every single-series panel on the same dashboard worked fine. The
cause: every query *within one panel* needs its own unique reference ID —
copy-pasting a query as a starting point for a second one, without also
changing its ID to something unique, produces a dashboard that loads
without error and just quietly drops the results. Single-query panels
never hit this because there's nothing to collide with. If a multi-series
panel renders blank next to working single-series ones, check for
duplicate query IDs before assuming the underlying metrics are missing.

## A service with a public DNS record can still fail to resolve on your own LAN

Some services want a real public-facing DNS record (a password manager, a
photo library, an auth portal) so they're reachable from outside the house.
Once that record points at the public/WAN IP, clients *inside* the LAN often
can't reach it at all, even though the exact same record works fine from a
phone on cellular. The cause is NAT hairpinning: a LAN client's request has
to go out to the router's WAN IP and back in, and a lot of consumer routers
simply don't support routing a packet back to where it came from. The fix
isn't on the service side — it's a local DNS resolver (AdGuard Home, Pi-hole,
plain dnsmasq, whatever you're comfortable with) that overrides just those
specific domains to the LAN IP for internal clients, while everything else
still resolves normally through the real upstream. If a public-facing service
works from outside the house but times out or fails from inside it, check
whether you're hairpinning before assuming it's a firewall or DNS
misconfiguration.
