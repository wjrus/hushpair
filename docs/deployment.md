# Deployment Guide

This is the recommended first production setup for `hushpair` on a small Linode VPS.

## Architecture

- Apache handles TLS and reverse proxying
- Puma runs the Rails app
- PostgreSQL stores the app, cache, queue, and cable databases
- Redis backs Action Cable
- Solid Queue runs inside Puma for a single-server deployment
- A cron job or systemd timer runs `hushpair:maintenance` every 5 minutes

## 1. Provision packages

Install:

- Ruby `3.4.9` via `rbenv`
- PostgreSQL
- Redis
- Apache with:
  - `proxy`
  - `proxy_http`
  - `proxy_wstunnel`
  - `headers`
  - `ssl`

## 2. Environment

Set these in the service environment:

```sh
RAILS_ENV=production
DATABASE_URL=postgresql://...
REDIS_URL=redis://127.0.0.1:6379/1
SECRET_KEY_BASE=...
HUSHPAIR_ALLOWED_HOSTS=hushpair.com,www.hushpair.com
HUSHPAIR_CABLE_ALLOWED_ORIGINS=https://hushpair.com,https://www.hushpair.com
HUSHPAIR_FORCE_SSL=true
HUSHPAIR_AR_ENCRYPTION_PRIMARY_KEY=...
HUSHPAIR_AR_ENCRYPTION_DETERMINISTIC_KEY=...
HUSHPAIR_AR_ENCRYPTION_KEY_DERIVATION_SALT=...
SOLID_QUEUE_IN_PUMA=true
RAILS_LOG_LEVEL=info
```

## 3. Boot the app

From the app directory:

```sh
eval "$(rbenv init - zsh)"
RBENV_VERSION=3.4.9 bundle install
RBENV_VERSION=3.4.9 bin/rails db:prepare
RBENV_VERSION=3.4.9 bundle exec puma -C config/puma.rb
```

For a systemd service, keep Puma bound to localhost and let Apache front it.

Example service shape:

```ini
[Unit]
Description=hushpair web
After=network.target postgresql.service redis.service

[Service]
Type=simple
User=deploy
WorkingDirectory=/srv/hushpair/current
Environment=RAILS_ENV=production
Environment=PORT=3000
Environment=SOLID_QUEUE_IN_PUMA=true
ExecStart=/bin/zsh -lc 'eval "$(rbenv init - zsh)" && RBENV_VERSION=3.4.9 bundle exec puma -C config/puma.rb'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## 4. Apache reverse proxy

The important part is supporting both normal HTTP traffic and websocket upgrades for `/cable`.

Example vhost:

```apache
<VirtualHost *:80>
  ServerName hushpair.com
  ServerAlias www.hushpair.com
  Redirect permanent / https://hushpair.com/
</VirtualHost>

<VirtualHost *:443>
  ServerName hushpair.com
  ServerAlias www.hushpair.com

  SSLEngine on
  SSLCertificateFile /etc/letsencrypt/live/hushpair.com/fullchain.pem
  SSLCertificateKeyFile /etc/letsencrypt/live/hushpair.com/privkey.pem

  ProxyPreserveHost On
  RequestHeader set X-Forwarded-Proto "https"

  ProxyPass /cable ws://127.0.0.1:3000/cable retry=0
  ProxyPassReverse /cable ws://127.0.0.1:3000/cable

  ProxyPass / http://127.0.0.1:3000/ retry=0
  ProxyPassReverse / http://127.0.0.1:3000/

  Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
</VirtualHost>
```

## 5. Maintenance job

Run every 5 minutes:

```sh
cd /srv/hushpair/current && /bin/zsh -lc 'eval "$(rbenv init - zsh)" && RBENV_VERSION=3.4.9 bin/rails hushpair:maintenance'
```

Recommended cron entry:

```cron
*/5 * * * * cd /srv/hushpair/current && /bin/zsh -lc 'eval "$(rbenv init - zsh)" && RBENV_VERSION=3.4.9 bin/rails hushpair:maintenance' >> log/maintenance.log 2>&1
```

## 6. Minimum operational checks

- `GET /up` returns success
- Rails boots with all encryption keys present
- `/cable` websocket upgrade works through Apache
- `hushpair:maintenance` runs cleanly
- Room expiry and purge behavior can be observed in logs without leaking message content

## 7. Logging posture

Keep logs minimal:

- no debug logging in production
- no plaintext message body logging
- no plaintext nickname logging
- health checks silenced where possible

## 8. Backups

Back up PostgreSQL and keep the retention short. This product is intentionally not optimized for long-lived archival.

At minimum:

- nightly PostgreSQL dump
- secure off-host storage
- periodic restore test on a staging instance

## 9. Later upgrades

If traffic grows:

- move Solid Queue to a dedicated worker process
- monitor Redis connection count and websocket load
- consider AnyCable once Action Cable becomes the bottleneck
