<p align="center">
  <a href="https://website-vw4l.vercel.app/">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://website-vw4l.vercel.app/brand/biga-logo-light.svg">
      <img src="https://website-vw4l.vercel.app/brand/biga-logo.svg" width="180" alt="biga">
    </picture>
  </a>
</p>

<h1 align="center">Self-host biga</h1>

<p align="center">
  Run the site, the viewer, the API server and PostgreSQL behind Caddy with one Compose file.
</p>

<p align="center">
  <a href="https://github.com/biga-sh/docker/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/biga-sh/docker/ci.yml?branch=main&style=flat-square&labelColor=0c0d10&label=ci" alt="CI status"></a>
  <a href="compose.yaml"><img src="https://img.shields.io/badge/docker%20compose-v2-63e197?style=flat-square&labelColor=0c0d10" alt="Docker Compose v2"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-63e197?style=flat-square&labelColor=0c0d10" alt="MIT license"></a>
</p>

<p align="center">
  <a href="https://website-vw4l.vercel.app/">Website</a> ·
  <a href="https://website-vw4l.vercel.app/docs">Documentation</a> ·
  <a href="docs/networking.md">Networking guide</a> ·
  <a href="https://github.com/biga-sh/docker/issues">Issues</a>
</p>

---

It works on a public server, on an office network or on one laptop. Caddy handles TLS and routing, PostgreSQL sits on a network with no route out, and only people holding an access key can broadcast.

## Get started

You need Docker Engine 24+ with Compose v2 (Linux for anything real; Docker Desktop is fine for trying it) and about 2 GB of RAM for the first build.

### Configure

```bash
git clone https://github.com/biga-sh/docker.git biga && cd biga
./scripts/setup.sh
```

`setup.sh` asks how people will reach the server, then writes `.env` with a generated database password and access key. It refuses to overwrite an existing `.env` unless you pass `--force`.

### Start the stack

```bash
docker compose up -d --build
docker compose ps
```

The first build takes a few minutes. Wait until every service reports `healthy`.

### Broadcast to it

`setup.sh` prints the exact command, for example:

```bash
BIGA_API_URL=https://biga.example.com BIGA_ACCESS_KEY=bgk_… biga start
```

Viewers only need the link the [CLI](https://github.com/biga-sh/cli) prints.

## Modes

| Mode | For | Setup |
| --- | --- | --- |
| `public` | A domain on the internet. Caddy gets and renews a Let's Encrypt certificate; ports 80 and 443 must be reachable. | `./scripts/setup.sh --mode public --domain biga.example.com` |
| `internal` | A private network, by name or IP. Caddy runs its own certificate authority; run `./scripts/trust-ca.sh` once per device. | `./scripts/setup.sh --mode internal --domain biga.internal` |
| `http` | A network you fully trust, or TLS added by something in front. Keys travel in clear text. | `./scripts/setup.sh --mode http --domain 192.168.1.20` |

IPv4, IPv6, intranets, VPNs and existing proxies are covered in the [networking guide](docs/networking.md).

## What runs

| Service | Role |
| --- | --- |
| `caddy` | TLS, HTTP/3 and routing: `/api/sessions/*` to the server, everything else to the site. The only published ports. |
| `server` | The API server, built from [biga-sh/server](https://github.com/biga-sh/server) |
| `web` | The site and viewer, built from [biga-sh/website](https://github.com/biga-sh/website) |
| `postgres` | Every session, in the `pgdata` volume |

Every container runs with `no-new-privileges`, Linux capabilities dropped, a read-only root filesystem and rotated logs. Secrets stay in `.env`, mode `600`, ignored by git.

## Day to day

```bash
docker compose logs -f server                                            # follow a service
docker compose pull --ignore-buildable && docker compose up -d --build   # update
./scripts/backup.sh                                                      # dump the database to backups/
./scripts/restore.sh backups/biga-….dump                                 # restore a dump
docker compose run --rm --no-deps server gen-key                         # another access key
docker compose down                                                      # stop; data stays in volumes
```

To revoke an access key, remove it from `BIGA_ACCESS_KEYS` in `.env` and run `docker compose up -d`. Ended sessions are deleted after `BIGA_RETENTION_DAYS` (default 30) by the server's own hourly sweep.

| Optional file | Adds |
| --- | --- |
| `compose.ipv6.yaml` | IPv6 inside Docker, so IPv6 visitors keep their addresses |
| `compose.scale.yaml` | Several API server instances sharing live events through Valkey |

Stop the stack before changing which files it uses, then start it with `docker compose -f compose.yaml -f compose.ipv6.yaml up -d`. `COMPOSE_FILE` in `.env` makes the choice stick.

## Development

To build from local checkouts instead of GitHub, set `BIGA_SERVER_SOURCE=../server` and `BIGA_WEB_SOURCE=../website` in `.env` and run `docker compose up -d --build`.

CI runs `shellcheck` on the scripts, validates every combination of Compose files and every Caddyfile mode, then starts the stack and broadcasts through it.

## Documentation

- [Docker](https://website-vw4l.vercel.app/docs/docker)
- [Self-hosting](https://website-vw4l.vercel.app/docs/self-hosting)
- [Configuration](https://website-vw4l.vercel.app/docs/configuration)
- [Networking guide](docs/networking.md)

## Repositories

| Repository | What it is |
| --- | --- |
| [cli](https://github.com/biga-sh/cli) | The `biga` command. Watches a folder and streams every save. |
| [server](https://github.com/biga-sh/server) | The Go API. Stores sessions and streams updates to viewers. |
| [website](https://github.com/biga-sh/website) | The site, the live viewer and the documentation. |
| [docker](https://github.com/biga-sh/docker) | Self-hosting: the whole stack with Docker Compose. |

## Contributing

Bug reports, focused fixes and pull requests are welcome. Read the [contributing guide](https://github.com/biga-sh/.github/blob/main/CONTRIBUTING.md) before you start, and report vulnerabilities privately as described in the [security policy](https://github.com/biga-sh/docker/security/policy), not in a public issue.

## License

biga is [MIT licensed](LICENSE).

---

<p align="center">
  <sub><a href="https://website-vw4l.vercel.app/">biga</a> · Made for people who teach, pair and build in public.</sub>
</p>
