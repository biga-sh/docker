<div align="center">

# biga, self-hosted

**Run your own [biga](https://github.com/biga-sh/cli) with Docker.**

The site and viewer, the API server, Postgres and Caddy, in one Compose file.<br>
On the internet, on your office network, or on one machine.

</div>

## Quick start

You need Docker Engine 24+ with Compose v2 (Linux for anything real; Docker
Desktop works for trying it out) and about 2 GB of RAM for the first build.

```sh
git clone https://github.com/biga-sh/docker.git biga && cd biga
./scripts/setup.sh                # asks a few questions, writes .env
docker compose up -d --build      # the first build takes a few minutes
docker compose ps                 # wait until every service is healthy
```

`setup.sh` prints the command your team runs to broadcast, something like:

```sh
BIGA_API_URL=https://biga.example.com BIGA_ACCESS_KEY=bgk_… biga start
```

Viewers only need the link the CLI prints.

## Choose how people reach it

`setup.sh` asks; you can also pass flags.

| Mode | For | Command |
| --- | --- | --- |
| `public` | A domain on the internet. HTTPS from Let's Encrypt, automatic. | `./scripts/setup.sh --mode public --domain biga.example.com` |
| `internal` | An office LAN, homelab or VPN, by name or IP. HTTPS from a local CA each device trusts once. | `./scripts/setup.sh --mode internal --domain biga.internal` |
| `http` | A network you fully trust, or something in front that adds TLS. | `./scripts/setup.sh --mode http --domain 192.168.1.20` |

IPv4, IPv6, intranets, VPNs, firewalls and existing reverse proxies are covered
step by step in **[docs/networking.md](docs/networking.md)** (also on the
website at [biga.sh/docs/networking](https://biga.sh/docs/networking)).

## What runs

```text
            TCP 80/443, UDP 443
                   │
                 caddy ───── /api/sessions/* ───▶ server ───▶ postgres
                   └──────── everything else ───▶ web          (internal network)
```

| Service | Image | Role |
| --- | --- | --- |
| `caddy` | `caddy:2-alpine` | TLS, HTTP/3, routing. The only published ports. |
| `server` | built from [biga-sh/server](https://github.com/biga-sh/server) | The API: sessions, uploads, live streams. |
| `web` | built from [biga-sh/website](https://github.com/biga-sh/website) | The site and the session viewer. |
| `postgres` | `postgres:17-alpine` | Every session's data, in the `pgdata` volume. |

### Secure by default

- **Writes need the session's owner token.** Only the CLI that created a
  session can change or end it; a link lets people watch, nothing more.
- **Broadcasting needs an access key** (setup generates one). Anyone can view;
  only key holders can broadcast through your server. Run `setup.sh
  --no-access-key` for an open server.
- **Nothing but Caddy is exposed.** Postgres is on an internal network with no
  route out and no published port.
- **Every container** runs with `no-new-privileges`, all Linux capabilities
  dropped (Caddy keeps only `NET_BIND_SERVICE`; Postgres only what its
  entrypoint needs), a read-only root filesystem, and log rotation.
- **Real client addresses** reach the server's rate limits: it trusts only
  Caddy, and Caddy trusts only the proxies you list in
  `BIGA_UPSTREAM_PROXIES`.
- **Secrets stay in `.env`**, written with mode `600` and ignored by git.
- **Images are built from source** by default and never pulled under a
  lookalike name (`BIGA_PULL_POLICY=never`).

## Operations

```sh
docker compose logs -f server               # follow a service's logs
docker compose pull --ignore-buildable && docker compose up -d --build   # update
./scripts/backup.sh                         # dump the database to backups/
./scripts/restore.sh backups/biga-….dump    # restore one
docker compose run --rm --no-deps server gen-key   # another access key
./scripts/trust-ca.sh                       # internal mode: export the CA certificate
docker compose down                         # stop (data stays in volumes)
```

To revoke an access key, remove it from `BIGA_ACCESS_KEYS` in `.env` and run
`docker compose up -d`. Broadcasts using it stop at their next request.

Ended sessions are deleted after `BIGA_RETENTION_DAYS` (30) by the server's
own hourly sweep; nothing needs scheduling.

### Optional overrides

| File | Adds |
| --- | --- |
| `compose.ipv6.yaml` | IPv6 inside Docker, so IPv6 visitors keep their real addresses. Use it whenever the host has IPv6. |
| `compose.scale.yaml` | Several API server instances sharing live events through Valkey. |

```sh
docker compose down                                       # when changing overrides
docker compose -f compose.yaml -f compose.ipv6.yaml up -d
```

Changing the set of files on a running stack can change its networks, so stop
it first (volumes are kept). Set `COMPOSE_FILE=compose.yaml:compose.ipv6.yaml`
in `.env` to make the choice stick for every `docker compose` command.

### Building from your own checkouts

```sh
# in .env
BIGA_SERVER_SOURCE=../server
BIGA_WEB_SOURCE=../website
```

Then `docker compose up -d --build`.

## Configuration

`.env` holds everything; [.env.example](.env.example) documents each setting.
The server reads more options than this file sets (body limits, stream caps,
log format and so on); add any of them to the `server` service's
`environment`. They are listed in the
[server README](https://github.com/biga-sh/server#configuration).

## License

[MIT](LICENSE)
