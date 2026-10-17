# Networking

How to make your biga reachable: on the internet over IPv4 and IPv6, on an
office or home network, over a VPN, or behind a proxy you already run. The
same guide is on the website at [biga.sh/docs/networking](https://biga.sh/docs/networking).

## How traffic flows

```text
 browsers and the biga CLI
          │  TCP 80, TCP 443, UDP 443 (HTTP/3)
          ▼
 ┌──────────── host ────────────────────────────────────────┐
 │  caddy ── /api/sessions/* ──▶ server:8080 ──▶ postgres   │
 │    │                              (edge + backend nets)   │
 │    └──── everything else ────▶ web:3000                  │
 └──────────────────────────────────────────────────────────┘
```

- **Caddy is the only container with published ports.** It terminates TLS and
  routes requests. The site, the API server and Postgres are never exposed.
- **Postgres sits on an internal network**: no route out, and unreachable
  from the host or the LAN.
- **The API server trusts only Caddy** for the client's address, and Caddy
  sends exactly one: the real client, after its own `BIGA_UPSTREAM_PROXIES`.
  That address drives rate limits, and IPv6 clients are counted per /64.

The CLI and the viewer both use one URL, `BIGA_PUBLIC_URL`. The CLI uploads
to `/api/sessions/...` on it and prints `BIGA_PUBLIC_URL/session/<id>`.

## Pick a mode

| Mode | Use it for | Certificates | Clients need |
| --- | --- | --- | --- |
| `public` | A domain on the internet | Let's Encrypt, automatic | Nothing |
| `internal` | Office LAN, homelab, VPN, a bare IP | Caddy's local CA | To trust the CA once |
| `http` | A network you fully trust, or TLS terminated in front | None | Nothing |

`./scripts/setup.sh` asks for the mode and the name or address, and writes
everything else. The rest of this guide is what to set around it.

## IPv4 on the internet

1. **DNS.** Create an `A` record for your domain pointing at the host's public
   IPv4 address.
2. **Ports.** Allow inbound TCP 80 and 443, and UDP 443 for HTTP/3, in the
   cloud provider's security group and the host firewall. Port 80 is needed:
   Let's Encrypt validates through it, and Caddy redirects it to HTTPS.
3. **Behind a home router**, forward TCP 80 and 443 (and UDP 443) to the
   host's LAN address, and give the host a fixed LAN address (a DHCP
   reservation).
4. **Check** from outside your network:

   ```sh
   curl -4 -sI https://biga.example.com/ | head -1
   ```

If your ISP puts you behind carrier-grade NAT (your router's WAN address is in
`100.64.0.0/10`, or differs from what `curl -4 ifconfig.co` reports), inbound
IPv4 cannot reach you. Use IPv6, a VPN such as Tailscale, a tunnel such as
Cloudflare Tunnel, or a small VPS.

### Docker and ufw

Docker publishes ports by writing its own iptables rules, which run before
ufw's. A `ufw deny 443` does **not** close a port Docker published. To limit
exposure, either bind Caddy to one address with `BIGA_BIND_ADDRESS`, or add
rules to the `DOCKER-USER` chain, which Docker evaluates first:

```sh
# Allow only the office network to reach published ports on eth0.
sudo iptables -I DOCKER-USER -i eth0 ! -s 203.0.113.0/24 -j DROP
```

firewalld users get the same effect with a `docker` zone; see Docker's
"Packet filtering and firewalls" page.

## IPv6

biga works over IPv6 end to end: Caddy, the server and the CLI all handle it,
and Let's Encrypt validates over IPv6.

1. **DNS.** Add an `AAAA` record for the host's stable global address. On Linux
   `ip -6 addr show scope global` lists them; skip ones marked `temporary`,
   which rotate.
2. **Open the firewall.** IPv6 has no NAT, so "port forwarding" is just
   allowing inbound TCP 80/443 and UDP 443 to the host, on the host firewall
   and on the router. Many routers block unsolicited inbound IPv6 by default.
3. **Turn on IPv6 inside Docker**, so visitors keep their addresses:

   ```sh
   docker compose down
   docker compose -f compose.yaml -f compose.ipv6.yaml up -d
   ```

   Stop the stack first when adding the file to a running one: the network is
   recreated, and containers Compose merely reattaches lose their service
   names. Add `COMPOSE_FILE=compose.yaml:compose.ipv6.yaml` to `.env` so every
   later `docker compose` command includes it.

   Docker publishes ports on `[::]` regardless, but on an IPv4-only network it
   relays IPv6 connections through a userland proxy. Caddy then sees every IPv6
   visitor as the Docker gateway: one shared rate-limit budget, and logs that
   say nothing. With IPv6 on the edge network, connections are routed natively.
   Docker Engine 27 or newer picks a unique local /64 by itself; on older
   engines set `"ipv6": true` and `"ip6tables": true` in
   `/etc/docker/daemon.json` and choose a subnet in `compose.ipv6.yaml`.
4. **Check** both families:

   ```sh
   curl -6 -sI https://biga.example.com/ | head -1
   curl -4 -sI https://biga.example.com/ | head -1
   ```

Bare IPv6 addresses go in brackets wherever a URL or a port binding is
involved: `BIGA_PUBLIC_URL=https://[2001:db8::10]`,
`BIGA_BIND_ADDRESS=[2001:db8::10]`, `BIGA_API_URL=https://[2001:db8::10]`.
`setup.sh` adds them for you.

An IPv6-only host serves IPv6-only clients. Offer both families if your
viewers might be on IPv4-only networks, which is still common on mobile and in
offices. Building the images also needs to reach the source and package
registries; if your host is IPv6-only, check that they resolve (or build the
images on another machine and `docker save` / `docker load` them).

## An office or home network (intranet)

1. **Choose a name.** Any of these work:
   - A record on your local DNS server, router, Pi-hole or dnsmasq:
     `biga.internal → 192.168.1.20`. Prefer `.internal` (reserved for private
     networks) or `home.arpa`; avoid `.local`, which belongs to mDNS.
   - The host's mDNS name, such as `studio.local`, which macOS, most Linux
     desktops (Avahi) and Windows 10+ resolve without any DNS server.
   - A bare address: `192.168.1.20`, or `[fd00::20]` for IPv6.
2. **Run setup in internal mode**:

   ```sh
   ./scripts/setup.sh --mode internal --domain biga.internal
   docker compose up -d --build
   ./scripts/trust-ca.sh
   ```

   `trust-ca.sh` exports the root certificate of Caddy's local CA. Install it
   once on every device that opens the site or runs the CLI (the script prints
   the command for each OS). After that, HTTPS works with no warnings, and the
   CLI connects like it would to any public server.
3. **Listen only on the LAN** when the host has other interfaces (a public
   NIC, a VPN):

   ```sh
   BIGA_BIND_ADDRESS=192.168.1.20
   ```

4. **Rate limits.** Every device on a LAN has its own address, so the defaults
   are fine. If many people reach the server through one NAT address, raise
   `BIGA_READ_RATE_LIMIT`, or set it to `0`.
5. **Keep access keys on.** Anyone on the network can reach the server; a key
   decides who may broadcast through it.

Plain `http` mode is simpler (no CA to install) but sends owner tokens and
access keys in clear text. Use it only on a network you would trust with those.

### No internet at all (air-gapped)

Build the images on a connected machine, then move them across:

```sh
docker compose build
docker save biga/server:local biga/web:local postgres:17-alpine caddy:2-alpine | gzip > biga-images.tar.gz
# on the air-gapped host:
gunzip -c biga-images.tar.gz | docker load
docker compose up -d
```

`BIGA_PULL_POLICY` defaults to `never`, so nothing is fetched. Use `internal`
or `http` mode: Let's Encrypt needs the internet.

## A VPN (Tailscale, WireGuard, ZeroTier)

Treat the VPN like an intranet. Bind to the host's VPN address so the server
is reachable only through the VPN, and use internal mode with that address or
the VPN's DNS name:

```sh
./scripts/setup.sh --mode internal --domain 100.101.102.103 --bind 100.101.102.103
```

With Tailscale, the MagicDNS name (`studio.tail1234.ts.net`) works as the
domain too.

## Behind a proxy you already run

If nginx, Traefik or a cloud load balancer already owns ports 80 and 443, run
this stack in `http` mode on a loopback port and proxy to it:

```sh
./scripts/setup.sh --mode http --domain biga.example.com --bind 127.0.0.1 --http-port 8088
```

Then set `BIGA_PUBLIC_URL` to the public `https://` address, and tell Caddy to
believe your proxy's `X-Forwarded-For` by setting `BIGA_UPSTREAM_PROXIES` to
the address Caddy sees it from. Through a loopback port that is the Docker
bridge gateway (`docker network inspect biga_edge` shows it, typically in
`172.16.0.0/12`).

Your proxy must stream server-sent events and allow large uploads. For nginx:

```nginx
location / {
    proxy_pass http://127.0.0.1:8088;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_buffering off;          # live updates
    proxy_read_timeout 1h;        # long-lived streams
    client_max_body_size 64m;     # snapshot uploads
}
```

Behind Cloudflare's proxy, use public mode as usual and set
`BIGA_UPSTREAM_PROXIES` to Cloudflare's published IP ranges, or Caddy will see
every visitor as Cloudflare.

## Docker Desktop (macOS, Windows)

Fine for trying biga out. Docker Desktop runs containers in a VM, so Caddy
sees every client as the VM's gateway, and inbound IPv6 is limited. Run a real
deployment on Linux.

## Ports

| Port | Protocol | Purpose |
| --- | --- | --- |
| 80 | TCP | HTTP: redirects to HTTPS; Let's Encrypt validation in public mode; everything in http mode |
| 443 | TCP | HTTPS |
| 443 | UDP | HTTP/3 (optional; clients fall back to TCP) |

Nothing else needs to be reachable. `BIGA_HTTP_PORT` and `BIGA_HTTPS_PORT`
change the host side; public mode needs the defaults, because Let's Encrypt
validates on port 80.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| Caddy logs `obtaining certificate` errors | DNS does not point here yet, or port 80 is blocked or forwarded elsewhere. `docker compose logs caddy` has the details. |
| `certificate signed by unknown authority` from the CLI or a browser | Internal mode without the CA installed on that device. Run `./scripts/trust-ca.sh`. |
| `cannot reach https://…` from the CLI | Firewall, a missing port forward, or the wrong `BIGA_API_URL`. Try `curl -v` with the same URL from the same machine. |
| `401 access_key_required` | Set `BIGA_ACCESS_KEY` to one of the keys in the server's `.env`. |
| Viewers stuck on "Reconnecting" | A proxy in front is buffering the event stream. Turn buffering off for `/api/sessions/*/stream`. |
| Every client shows the same address in the server logs | IPv6 visitors without `compose.ipv6.yaml`, Docker Desktop, or a proxy in front that is not in `BIGA_UPSTREAM_PROXIES`. |
| Caddy answers 502 after adding an override file | The stack was not recreated. Run `docker compose down`, then `up` again. |
| Works on IPv4, not IPv6 | A missing `AAAA` record, or the router or host firewall dropping inbound IPv6. |
