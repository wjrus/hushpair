# hushpair

Minimal anonymous 1:1 chat for two people. Private invite links, realtime text chat, short data retention, and a privacy-first Rails backend that can later support mobile clients.

## Stack

- Ruby `3.4.9`
- Rails `8.1.x`
- PostgreSQL
- Redis for Action Cable
- Solid Queue for jobs

## Local setup

```sh
eval "$(rbenv init - zsh)"
RBENV_VERSION=3.4.9 bundle install
RBENV_VERSION=3.4.9 bin/rails db:prepare
bin/dev
```

The app expects PostgreSQL locally. `bin/dev` starts the Rails server and asset watcher.

## Core behavior

- Invite-only room creation for two participants
- Invite interstitial before join, so link scanners do not silently enter the room
- Realtime messaging over Action Cable with a lightweight fallback sync path
- Private participant return links
- Room creator-controlled message retention
- Activity-based room expiry:
  - waiting rooms: `30 minutes`
  - active rooms: `24 hours`
  - new messages extend active rooms up to `30 days` from creation
- Encrypted-at-rest message bodies and nicknames
- Basic moderation and abuse throttles

## Privacy and retention

- Messages and nicknames are encrypted at rest
- Parameter logging filters hide message bodies, nicknames, and tokens
- Contact-info heuristics block obvious handles, emails, phone numbers, and URLs
- Closed rooms are purged after a short retention window

Operational cleanup runs through:

```sh
RBENV_VERSION=3.4.9 bin/rails hushpair:maintenance
```

That task:

- expires due rooms
- enforces message-retention policies even when no new messages are arriving
- purges old ended/expired rooms and their dependent data

Run it on a regular schedule in deployed environments.

## Test suite

```sh
RBENV_VERSION=3.4.9 bin/rails test
```

Focused lifecycle coverage includes:

- invite interstitial behavior
- join/send/end-chat flow
- expired-room access behavior
- room maintenance expiration/retention/purge behavior

## Key environment variables

Required:

- `DATABASE_URL`
- `REDIS_URL`
- `SECRET_KEY_BASE`
- `HUSHPAIR_AR_ENCRYPTION_PRIMARY_KEY`
- `HUSHPAIR_AR_ENCRYPTION_DETERMINISTIC_KEY`
- `HUSHPAIR_AR_ENCRYPTION_KEY_DERIVATION_SALT`

Recommended:

- `HUSHPAIR_ALLOWED_HOSTS`
- `HUSHPAIR_CABLE_ALLOWED_ORIGINS`
- `HUSHPAIR_FORCE_SSL=true`
- `RAILS_LOG_LEVEL=info`
- `HUSHPAIR_RELEASE`

Administrative features, if enabled, are protected separately and should be configured through deployment-specific environment.

## Deployment notes

hushpair is designed to run behind a normal HTTPS reverse proxy with PostgreSQL and Redis available
to the Rails process. Keep deployment-specific paths, hostnames, admin routes, OAuth settings, and
operational runbooks outside public documentation.

## Release stamping

For deployed builds, stamp the current commit into the environment before building:

```sh
./script/update-env
```

That updates `HUSHPAIR_RELEASE` so the footer can show the deployed build identifier.
