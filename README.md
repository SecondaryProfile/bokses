# Bokses

Tidy up your life. Just put it in a box. Deal with it later or reorganize now.

Bokses is a **self-hosted web app**. There are no mobile or desktop build
targets for now. You run your own instance with Docker, everyone in your
household signs in to it from a browser, and everyone shares the same boxes.

## Self-hosting with Docker

Requirements: Docker with Compose v2.

```sh
( Go to where you want the app to live )
mkdir -p bokses
git clone https://github.com/SecondaryProfile/bokses.git
cd bokses
cp .env.example .env
# edit .env and set POSTGRES_PASSWORD to something long and random,
# e.g. the output of: openssl rand -base64 24
docker compose up -d --build
```

The first build downloads Flutter and takes several minutes; later builds are
cached.

Open [http://localhost:6692](http://localhost:6692) on the machine running
Bokses. From other devices on your network, use that machine's IP address
instead of `localhost`, for example `http://192.168.1.50:6692`. The first
screen asks you to create the
**root account**, which manages everyone else's accounts. After that, people
can create their own accounts from the sign-in screen (root can turn sign-ups
off under **Settings → Account**).

What's running:

| Container  | What it does | Reachable from |
|------------|--------------|----------------|
| `bokses`   | nginx serving the web app on port 8080 (published as 6692), proxying `/api` to the Dart API server inside the same container | your network, on port 6692 |
| `postgres` | PostgreSQL 17; data in the `bokses-db` volume | only the `bokses` container |

- **Updating:** `git pull && docker compose up -d --build`. Database changes
  are applied automatically when the API starts.
- **Backups:** use **Settings → Export** in the app, or dump the database:
  `docker compose exec postgres pg_dump -U bokses bokses > bokses.sql`.
- **Changing the port:** set `BOKSES_PORT` in `.env`.
- **Don't expose it to the internet as-is.** It speaks plain HTTP. If you want
  remote access, put it behind a VPN (e.g. Tailscale) or an HTTPS reverse proxy
  that sets `X-Forwarded-Proto: https`. Bokses then marks the session cookie
  `Secure`.

## Accounts and security

- **Passwords are never stored.** Each one is hashed with **Argon2id** (OWASP's
  recommended settings: 19 MiB memory, 2 iterations) with its own random salt.
  A copy of the database doesn't reveal anyone's password.
- **Sessions** are random 256-bit tokens in an `HttpOnly`, `SameSite=Strict`
  cookie that page scripts can't read. The database stores only a SHA-256 of
  each token, so a stolen database can't be used to sign in. Sessions last 30
  days; signing out ends them on the server.
- **Brute force:** failed sign-ins are rate-limited per IP and per username, and
  a wrong username takes as long to reject as a wrong password, so response
  times don't reveal which accounts exist.
- **Root** can add accounts, reset passwords (which signs that person out),
  delete accounts, and turn sign-ups on or off. Root itself can't be deleted,
  and the database guarantees there is only ever one.
- Changing your own password signs out your other devices.
- Postgres has no published port and sits on a Docker network with no outside
  access. The API server listens only inside the `bokses` container. Both
  containers run with `no-new-privileges`, and the `bokses` container runs as a
  non-root user with a read-only filesystem.

## Where data lives

- **Boxes, items and accounts:** Postgres, shared by everyone on the instance.
  Each box and item records who created and last changed it.
- **Photos:** stored in the database as `data:` URIs, except web-search results,
  which are kept as remote URLs.
- **Per-browser settings** (theme, background, AutoBoks options):
  `SharedPreferences`, backed by `localStorage`.
- **AI provider API keys:** `flutter_secure_storage`, which on web is
  AES-encrypted `localStorage`. They never reach the Bokses server, but they are
  only as private as the browser profile: a shared machine is a shared key.
- **Debug log:** an in-memory rolling buffer for the current tab only.

## AI image recognition

Image-recognition requests go straight from the browser to whichever provider
you configured (Gemini, Claude, or ChatGPT) using your own API key. The Bokses
server is not involved. These requests are subject to the provider's CORS
policy, and the key is exposed to the browser, so use a key scoped to this
purpose.

## Project layout

```
lib/            Flutter web app
server/         Dart API server (shelf + Postgres) — its own Dart package
docker/         nginx config and container entrypoint
Dockerfile      builds the single bokses image
docker-compose.yml
```

