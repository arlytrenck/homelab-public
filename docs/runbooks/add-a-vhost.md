# Runbook: add a reverse-proxy vhost

Exposing a locally-bound service at `https://<name>.example.com`, optionally
behind forward-auth SSO. The reverse proxy lives **outside** this repo (see
[getting-started.md](../getting-started.md)); the steps are the same shape
whatever proxy you use.

## 1. DNS

Point `<name>.example.com` at the host. For a homelab that's usually an
internal `A` record on your LAN resolver (or a public `A` record if the
service is meant to be internet-reachable). If you use split-horizon DNS,
add the internal answer too, or the name will resolve to an address the LAN
can't reach (the NAT-hairpin problem).

Newly-created public records can take a while to propagate — the ACME cert
won't issue until the name resolves. Check with `dig +short <name>.example.com`
against the authoritative nameserver.

## 2. Proxy block

The shape, in proxy-neutral terms:

```
host  <name>.example.com  (TLS via ACME / your cert)
  optional:  allow only source IPs in your LAN CIDR, else 403
  optional:  forward-auth  ->  http://<auth-provider>:<port>/<forward-auth-path>
             copy the identity headers it returns (user, groups, email, name)
  reverse_proxy  ->  127.0.0.1:<service-port>
```

Caddy example (adapt for Traefik labels / nginx `location` as needed):

```caddy
name.example.com {
    @denied not remote_ip 10.0.0.0/24
    respond @denied 403

    forward_auth 127.0.0.1:9091 {
        uri /api/authz/forward-auth
        copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
    }

    reverse_proxy 127.0.0.1:<port>
}
```

Public service that does its own auth (a status page, a webhook receiver, an
app with token auth like Gotify): omit the `@denied` and `forward_auth`
lines. Validate and reload the proxy.

## 3. Authorization rule in the auth provider

**This is the step that gets skipped.** A forward-auth block only tells the
proxy to *ask* the provider. The provider has its own policy, and its
default is almost always **deny**. Add a matching rule:

```yaml
# forward-auth provider config, access-control rules:
- domain: name.example.com
  policy: one_factor      # or two_factor for anything sensitive
```

Reload/restart the provider. Without this, every request to the new vhost
gets a 403 from the provider — and because the proxy config is fine, it
looks like a firewall or network fault, not an auth one. Confirm from the
provider's own logs (`"access ... is forbidden to user '<anonymous>'"`), not
the proxy's.

Policy guidance: `two_factor` for anything with write access to data or
infra (password manager, media managers, dashboards with admin, automation
tools); `one_factor` for read-mostly internal dashboards; a scoped `bypass`
only for specific API paths a mobile app or webhook needs.

## 4. Verify

```sh
curl -sko /dev/null -w '%{http_code}\n' https://name.example.com/
```

| Code | Meaning |
|------|---------|
| 200 / 302 | working (302 → redirect to the SSO login) |
| 403 | authorization rule missing (step 3), or your source IP is outside the allowed CIDR |
| 000 | DNS not resolving or cert not issued yet — wait for propagation, then restart the proxy to reset its ACME backoff |
| 502 | proxy up, but nothing is listening on `127.0.0.1:<port>` |

## 5. Finish

- Remove any temporary LAN-IP port binding from the service's compose now
  that the vhost is the entry point; `up -d`.
- Add a black-box uptime check for the new URL.
- Update [service-catalog.md](../service-catalog.md) and the `CHANGELOG.md`.
- Make sure your reverse-proxy config is itself backed up / in version
  control — it's infrastructure state that lives outside this repo.
