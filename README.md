# Excalidraw Deployment

A single Docker Compose stack with HTTPS Nginx, Excalidraw, collaboration,
persistent scene/image storage, PostgreSQL, and an optional Certbot service.
Supply your domain and an existing certificate, or obtain one with `make ssl`.
Nginx runs inside this stack and terminates TLS.

During normal operation, only Nginx publishes host ports 80 and 443. Frontend port 80, storage port
18474, and collaboration port 18475 are reachable through Docker networking.
PostgreSQL port 5432 is on a separate internal network shared only with storage.
The browser reaches collaboration and storage through the public HTTPS origin;
it does not need access to their container ports.

| Component | Pinned Image |
| --- | --- |
| Nginx | `nginx:1.30.4-alpine` |
| Frontend | `alswl/excalidraw:v0.18.1-fork-b2` |
| Storage | `ghcr.io/kitsteam/excalidraw-storage-backend:v0.2.3` |
| Collaboration | `ghcr.io/kitsteam/excalidraw-room:v0.2.3` |
| Database | `postgres:18.6-alpine` |
| Certificates (optional profile) | `certbot/certbot:v5.8.0` |

The frontend tag currently provides a Linux amd64 image. Deploy on an x86-64
Linux server with Docker Compose v2 or newer.

## Configure

The local `.env` already contains a generated 64-character hexadecimal database
password. Set `DOMAIN` to your hostname. For a fresh checkout, create `.env`
from `.env.example` and set a password using `openssl rand -hex 32`.

Set the certificate variables in `.env`:

```dotenv
DOMAIN=draw.example.com
CERTS_DIR=./certs
TLS_CERT_FILE=fullchain.pem
TLS_KEY_FILE=privkey.pem
```

Place the existing certificate and key in `certs/`, or set `CERTS_DIR` to an
absolute directory on the server. Certificate filenames are relative to that
directory. Nginx substitutes these settings into its template automatically;
you do not need to repeat the domain in the Nginx file.

For Let's Encrypt symlinks, mount the entire tree rather than just the `live`
directory so the links to `archive` resolve inside the container:

```dotenv
CERTS_DIR=/etc/letsencrypt
TLS_CERT_FILE=live/draw.example.com/fullchain.pem
TLS_KEY_FILE=live/draw.example.com/privkey.pem
```

DNS should point to the server. Host ports 80 and 443 must be available for this
stack's Nginx. An existing host Nginx occupying those ports needs a different
deployment topology. This configuration assumes clients connect directly to
the stack's Nginx.

## Create and Renew Certificates

The Makefile follows the `ssl` and `ssl-renew` naming in the
[Pomodoro deployment](https://github.com/dannythehumbleguy/pomodoro/blob/main/deployment/Makefile).
It uses Certbot's standalone HTTP challenge through the optional `ssl` profile
in the same Compose file. Run GNU Make on your Linux server; host Certbot is
not required.

For managed certificates, use these settings in `.env` (the local defaults
already select these certificate paths):

```dotenv
DOMAIN=draw.yourdomain.com
SSL_EMAIL=you@yourdomain.com
CERTS_DIR=./certs
TLS_CERT_FILE=live/${DOMAIN}/fullchain.pem
TLS_KEY_FILE=live/${DOMAIN}/privkey.pem
```

Set your real hostname and registration email, ensure its DNS resolves to this
server and inbound TCP port 80 is reachable, then run:

```sh
make ssl
make run
```

`make ssl` agrees to the Let's Encrypt terms and registers using `SSL_EMAIL`.
It keeps a still-valid certificate instead of forcing issuance on every run.
Certbot stores its account, renewal settings, certificate archive, and symlinks
inside `CERTS_DIR`; keep this entire directory for future renewals. For a
different directory, create it before running the target.

```sh
make ssl-renew
```

`make ssl` stops Nginx so Certbot can bind port 80; run `make run` afterward.
`make ssl-renew` stops Nginx, renews certificates in `CERTS_DIR` when due, and
starts Nginx again. If Certbot fails, Make stops at that command; run
`docker compose start nginx` to bring the proxy back up.

Run `make ssl-renew` periodically on the server, for example with a daily cron
entry (replace the absolute project path):

```cron
17 3 * * * cd /opt/excalidraw-config && /usr/bin/make ssl-renew >> /var/log/excalidraw-cert-renew.log 2>&1
```

The cron user needs permission to run Docker. This file does not install a
schedule automatically.

## Deploy

Run in this directory on the server after configuring `.env` and certificates:

```sh
docker compose config --quiet
docker compose pull
docker compose up -d --wait --wait-timeout 180
docker compose exec nginx nginx -t
docker compose ps
```

Visit `https://YOUR_DOMAIN`. HTTP redirects to the configured HTTPS hostname.
The proxy routes `/` to Excalidraw, `/storage/` to the storage API, and
`/socket.io/` to the collaboration server. Health checks gate startup, including
a storage check that writes to the database. Docker DNS resolution tracks
backend container address changes.

```sh
docker compose logs --tail=100 nginx excalidraw storage room postgres
```

After certificate renewal, reload Nginx:

```sh
docker compose exec nginx nginx -t
docker compose exec nginx nginx -s reload
```

After changing `.env`, run `docker compose up -d --wait` to recreate affected
services. Changing `POSTGRES_PASSWORD` does not change the password in an
already initialized database; rotate the database role password separately.

## Data and Features

Local drawings and preferences stay in browser storage. Shared scenes,
collaboration room snapshots, and uploaded images are persisted in the
`./data/postgres/` directory on the server, relative to `compose.yaml`.
Docker creates the directory on first startup. No storage TTL is configured, so records do not expire
automatically. Local `.excalidraw` import/export and PNG/SVG export remain
available. Keep share links and room links, including their URL fragments,
because the fragment contains the decryption key.

This stack has no user accounts or access control. Libraries retain the
frontend's public library endpoints. Excalidraw Plus and AI services are not
part of this deployment; the AI backend is disabled.

The pinned frontend uses legacy flat image IDs. Reusing the same image in
different rooms or exporting it under different share links can overwrite its
encrypted data and break older image links. KitsTeam supports namespaced file
routes, but this frontend does not use them. Use local exports for archival
copies containing images.

After deployment, check collaboration in two browser profiles, insert an image,
and open a share link in a fresh profile. Close both collaboration clients and
reopen the room to check persisted state. Check older image links after reusing
an image, in view of the frontend limitation above.

## Backups

Example on a Linux server:

```sh
mkdir -p backups
docker compose exec -T postgres pg_dump -U excalidraw -d excalidraw -Fc > backups/excalidraw.dump
```

Keep backups and `.env` outside Git. The database uses a bind mount, so both
`docker compose down` and `docker compose down -v` preserve `./data/postgres/`.
Deleting that server directory deletes the database. PostgreSQL 18 mounts it at
`/var/lib/postgresql`, with a versioned data directory beneath it. Future major
database upgrades require a migration or dump/restore.

If you already deployed using the former `excalidraw_postgres-data` Docker
volume, migrate its data before starting with this bind mount. An empty
`./data/postgres/` starts a new database; changing the mount does not copy data
from the old volume automatically.

## Frontend Choice

The earlier suggestion to configure only the official frontend's endpoint URLs
was incomplete: official Excalidraw still uses Firebase for room persistence
and image storage. This fork supplies the HTTP storage adapter and runtime
environment injection needed for this stack. Neither a URL-only rebuild nor
startup URL replacement adds that adapter to the official frontend.

References: [official frontend storage](https://github.com/excalidraw/excalidraw/blob/master/excalidraw-app/data/firebase.ts),
[fork runtime configuration](https://github.com/alswl/excalidraw/blob/v0.18.1-fork-b2/dynamic-env.Dockerfile),
[fork HTTP adapter](https://github.com/alswl/excalidraw/blob/v0.18.1-fork-b2/excalidraw-app/data/httpStorage.ts),
[KitsTeam storage release](https://github.com/kitsteam/excalidraw-storage-backend/releases/tag/v0.2.3),
and [KitsTeam collaboration release](https://github.com/kitsteam/excalidraw-room/releases/tag/v0.2.3).
