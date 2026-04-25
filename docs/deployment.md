# Docker Compose Deployment

This is the recommended first production deployment for `hushpair` on your existing Ubuntu Docker host.

## Target shape

- Docker Compose runs:
  - `web` for Rails + Puma
  - `db` for PostgreSQL
  - `redis` for Action Cable
- Apache stays on the host and reverse proxies to the app container
- Host cron runs the maintenance task every 5 minutes

For your current host, the app should bind to `127.0.0.1:5000` so it does not collide with Grafana on port `3000`.

## 1. Prepare the app directory

Clone the repo to a stable location, for example:

```sh
mkdir -p ~/apps
cd ~/apps
git clone <your-repo-url> hushpair
cd hushpair
```

Copy the environment template:

```sh
cp .env.example .env
```

Then edit `.env` with real values.

Before each production build, stamp the current commit into `.env`:

```sh
./script/update-env
```

## 2. Required `.env` values

At minimum, set:

```dotenv
RAILS_ENV=production
HUSHPAIR_APP_PORT=5000

POSTGRES_USER=hushpair
POSTGRES_PASSWORD=use-a-strong-password
POSTGRES_DB=hushpair_production
DATABASE_URL=postgresql://hushpair:use-a-strong-password@db:5432/hushpair_production

REDIS_URL=redis://redis:6379/1

SECRET_KEY_BASE=generate-a-real-secret
HUSHPAIR_ALLOWED_HOSTS=hushpair.com,www.hushpair.com
HUSHPAIR_CABLE_ALLOWED_ORIGINS=https://hushpair.com,https://www.hushpair.com
HUSHPAIR_FORCE_SSL=true

HUSHPAIR_AR_ENCRYPTION_PRIMARY_KEY=generate-a-real-key
HUSHPAIR_AR_ENCRYPTION_DETERMINISTIC_KEY=generate-a-real-key
HUSHPAIR_AR_ENCRYPTION_KEY_DERIVATION_SALT=generate-a-real-salt
```

Generate secure values with commands like:

```sh
openssl rand -hex 64
```

## 3. Build and boot

From the app directory:

```sh
./script/update-env
docker-compose build
docker-compose up -d
```

Check status:

```sh
docker-compose ps
docker-compose logs --tail=200 web
```

The container entrypoint waits for PostgreSQL and runs `bin/rails db:prepare` automatically before Puma starts.

## 4. Apache reverse proxy

Proxy HTTPS traffic on the host to `127.0.0.1:5000`, including websocket traffic for `/cable`.

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

  ProxyPass /cable ws://127.0.0.1:5000/cable retry=0
  ProxyPassReverse /cable ws://127.0.0.1:5000/cable

  ProxyPass / http://127.0.0.1:5000/ retry=0
  ProxyPassReverse / http://127.0.0.1:5000/

  Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
</VirtualHost>
```

Required Apache modules:

```sh
sudo a2enmod proxy proxy_http proxy_wstunnel headers ssl rewrite
sudo systemctl reload apache2
```

## 5. Host cron for maintenance

Use host cron instead of trying to make Compose schedule things.

Edit crontab:

```sh
crontab -e
```

Add this line, adjusting the path if you deploy somewhere else:

```cron
*/5 * * * * cd /home/wjr/apps/hushpair && /usr/bin/docker-compose exec -T web bin/rails hushpair:maintenance >> /home/wjr/apps/hushpair/log/maintenance.log 2>&1
```

Notes:

- `-T` is important for cron so it does not expect a TTY
- the maintenance task expires rooms, trims retained messages, and purges old closed rooms
- `docker-compose` version `1.29.2` on your host is fine for this setup

## 6. Basic deploy/update flow

When you push new code:

```sh
cd /home/wjr/apps/hushpair
git pull
./script/update-env
docker-compose build web
docker-compose up -d web
```

If dependencies or config changed more broadly:

```sh
docker-compose up -d
```

## 7. Health checks

After boot:

```sh
curl -I http://127.0.0.1:5000/up
docker-compose logs --tail=200 web
docker-compose logs --tail=100 db
docker-compose logs --tail=100 redis
```

Once Apache is in front:

```sh
curl -I https://hushpair.com/up
```

## 8. Backups

At minimum:

- back up the `hushpair_postgres` volume or run regular `pg_dump`
- keep off-host copies
- test restores at least once before trusting the backup plan

Because Hushpair is privacy-first and short-retention by design, this should stay operationally light.
