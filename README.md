# hushpair

Minimal anonymous 1:1 chat for two people. Private invite links, realtime text chat, short data retention, and a privacy-first Rails backend that can later support mobile clients.

## Stack

- Ruby `3.4.9`
- Rails `8.1.x`
- PostgreSQL
- Redis for Action Cable
- Solid Queue for jobs
- Apache or another reverse proxy in front of Puma

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

Operational cleanup now runs through:

```sh
RBENV_VERSION=3.4.9 bin/rails hushpair:maintenance
```

That task:

- expires due rooms
- enforces message-retention policies even when no new messages are arriving
- purges old ended/expired rooms and their dependent data

Run it every 5 minutes in production.

## Test suite

```sh
RBENV_VERSION=3.4.9 bin/rails test
```

Focused lifecycle coverage includes:

- invite interstitial behavior
- join/send/end-chat flow
- expired-room access behavior
- room maintenance expiration/retention/purge behavior

## Production checklist

See:

- [Deployment guide](/Users/wjr/dev/hushpair/docs/deployment.md)
- [Manual QA checklist](/Users/wjr/dev/hushpair/docs/manual-qa.md)

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
- `SOLID_QUEUE_IN_PUMA=true`

## Deploy shape

Recommended first production shape on a Linode VPS:

- Apache terminates TLS and proxies HTTP + `/cable`
- Puma serves Rails
- PostgreSQL stores app data
- Redis backs Action Cable
- `hushpair:maintenance` runs from cron or a systemd timer every 5 minutes

That keeps the first deployment simple and conventional. If websocket scale becomes a real problem later, the likely next step is swapping the realtime layer to AnyCable rather than redesigning the app.
