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
RAILS_LOG_LEVEL=info
RAILS_MAX_THREADS=3
HUSHPAIR_APP_PORT=5000
HUSHPAIR_APP_DIR=/home/hushpair/apps/hushpair

POSTGRES_USER=hushpair
POSTGRES_PASSWORD=use-a-strong-password
POSTGRES_DB=hushpair_production
DATABASE_URL=postgresql://hushpair:use-a-strong-password@db:5432/hushpair_production

REDIS_URL=redis://redis:6379/1

SECRET_KEY_BASE=generate-a-real-secret
HUSHPAIR_RELEASE=generated-by-script-update-env
HUSHPAIR_ALLOWED_HOSTS=hushpair.com
HUSHPAIR_CABLE_ALLOWED_ORIGINS=https://hushpair.com
HUSHPAIR_FORCE_SSL=true

GOOGLE_OAUTH_CLIENT_ID=optional-google-client-id
GOOGLE_OAUTH_CLIENT_SECRET=optional-google-client-secret
ADMIN_USER=wjr@wjr.us

HUSHPAIR_AR_ENCRYPTION_PRIMARY_KEY=generate-a-real-key
HUSHPAIR_AR_ENCRYPTION_DETERMINISTIC_KEY=generate-a-real-key
HUSHPAIR_AR_ENCRYPTION_KEY_DERIVATION_SALT=generate-a-real-salt

HUSHPAIR_DEPLOY_HOST=hushpair.com
HUSHPAIR_BACKUP_DIR=/home/hushpair/backups/hushpair
HUSHPAIR_BACKUP_RETENTION_DAYS=14

HUSHPAIR_MATCH_MESSAGE_RETENTION_MODE=line_count
HUSHPAIR_MATCH_MESSAGE_RETENTION_LINE_LIMIT=250
HUSHPAIR_MATCH_MESSAGE_RETENTION_HOURS=24
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

## 4. Nginx reverse proxy

Proxy HTTPS traffic on the host to `127.0.0.1:5000`, including websocket traffic for `/cable`.

Example site config:

```nginx
server {
  listen 80;
  listen [::]:80;
  server_name hushpair.com;

  location /.well-known/acme-challenge/ {
    root /var/www/html;
  }

  location / {
    return 301 https://hushpair.com$request_uri;
  }
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name hushpair.com;

  ssl_certificate /etc/letsencrypt/live/hushpair.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/hushpair.com/privkey.pem;

  add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;

  location /cable {
    proxy_pass http://127.0.0.1:5000/cable;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    proxy_buffering off;
  }

  location / {
    proxy_pass http://127.0.0.1:5000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}
```

Reload after editing:

```sh
sudo nginx -t
sudo systemctl reload nginx
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

Or use the repo helper:

```sh
cd /home/wjr/apps/hushpair
./script/deploy
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
