 <p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://website-vw4l.vercel.app/brand/biga-logo-light.svg">
    <img src="https://website-vw4l.vercel.app/brand/biga-logo.svg" width="180" alt="biga">
  </picture>
</p>

<h1 align="center">Self-host biga.</h1>

<p align="center">
  Deployment tooling for running biga with Docker.
</p>

<p align="center">
  <a href="https://website-vw4l.vercel.app/">Website</a> ·
  <a href="https://website-vw4l.vercel.app/docs">Documentation</a> ·
  <a href="https://github.com/biga-sh/server">Server</a> ·
  <a href="https://github.com/biga-sh/cli">CLI</a>
</p>

---

This repository contains the Docker deployment setup for **biga**, including the services and operational scripts needed to run a self-hosted instance.

Use this repository when you want to operate your own deployment rather than rely on the hosted service.

## Get started

### Requirements

- Docker Engine
- Docker Compose
- The host resources and network configuration required by your chosen deployment

### Clone the repository

```bash
git clone https://github.com/biga-sh/docker.git
cd docker
```

Follow the repository's setup instructions and environment configuration before starting services.

```bash
docker compose up -d --build
```

The command above is the standard Docker Compose startup pattern. If the repository's setup script generates configuration or specifies a different startup command, follow that workflow instead.

## Operations

Use the scripts and instructions provided in this repository for:

- Initial setup and configuration
- Starting and updating services
- Backing up and restoring data
- Network configuration and deployment hardening

See the [biga documentation](https://website-vw4l.vercel.app/docs) for product-level setup guidance and the [server repository](https://github.com/biga-sh/server) for backend details.

## Before deploying publicly

- Configure secrets and access controls securely.
- Restrict database access to trusted services.
- Configure HTTPS and the required network rules.
- Establish and test a backup and restore process.
- Review retention, logging, and update procedures.

Never commit production credentials or populated environment files.

## Contributing

Report deployment issues through the [issue tracker](https://github.com/biga-sh/docker/issues). Contributions and improvements are welcome.

---

<p align="center">
  <a href="https://website-vw4l.vercel.app/">biga</a> · Stream your saves, not your screen.
</p>
