#!/bin/bash
set -e

echo "=== OPD Pre-Consultation POC — Railway Startup ==="

# Detect working directory (railpack puts files at /app or project root)
APP_DIR="${APP_DIR:-/app}"
if [ -f "$APP_DIR/deploy/start.sh" ]; then
  BASE="$APP_DIR"
elif [ -f "/app/deploy/start.sh" ]; then
  BASE="/app"
elif [ -f "$(pwd)/deploy/start.sh" ]; then
  BASE="$(pwd)"
else
  BASE="/app"
fi

echo "[startup] Base directory: $BASE"

# -------------------------------------------------------
# 1. Run DB migrations
# -------------------------------------------------------
if [ -n "$POSTGRES_HOST" ] || [ -n "$DATABASE_URL" ]; then
  echo "[startup] Running database migrations..."

  for i in $(seq 1 30); do
    if python3 -c "
import psycopg2, os
db_url = os.getenv('DATABASE_URL')
if db_url:
  psycopg2.connect(db_url).close()
else:
  psycopg2.connect(
    host=os.environ['POSTGRES_HOST'],
    port=os.environ.get('POSTGRES_PORT','5432'),
    dbname=os.environ.get('POSTGRES_DB','opd_preconsult'),
    user=os.environ.get('POSTGRES_USER','opd_user'),
    password=os.environ.get('POSTGRES_PASSWORD',''),
  ).close()
print('connected')
" 2>/dev/null; then
      echo "[startup] PostgreSQL is ready"
      break
    fi
    echo "[startup] Waiting for PostgreSQL... ($i/30)"
    sleep 2
  done

  MIGRATION_DIR="$BASE/db/migrations"
  if [ ! -d "$MIGRATION_DIR" ]; then
    MIGRATION_DIR="/app/db/migrations"
  fi

  for f in $MIGRATION_DIR/*.sql; do
    [ -f "$f" ] || continue
    echo "[startup] Running migration: $(basename $f)"
    python3 -c "
import psycopg2, os, sys
db_url = os.getenv('DATABASE_URL')
if db_url:
  conn = psycopg2.connect(db_url)
else:
  conn = psycopg2.connect(
    host=os.environ['POSTGRES_HOST'],
    port=os.environ.get('POSTGRES_PORT','5432'),
    dbname=os.environ.get('POSTGRES_DB','opd_preconsult'),
    user=os.environ.get('POSTGRES_USER','opd_user'),
    password=os.environ.get('POSTGRES_PASSWORD',''),
  )
conn.autocommit = True
with open(sys.argv[1]) as f:
  conn.cursor().execute(f.read())
conn.close()
print(f'  OK: {sys.argv[1]}')
" "$f" 2>&1 || echo "  (migration may already be applied)"
  done
  echo "[startup] Migrations complete"
else
  echo "[startup] WARNING: POSTGRES_HOST / DATABASE_URL not set, skipping migrations"
fi

# -------------------------------------------------------
# 2. Configure nginx
# -------------------------------------------------------
NGINX_CONF="$BASE/deploy/nginx.conf"
if [ ! -f "$NGINX_CONF" ]; then
  NGINX_CONF="/app/deploy/nginx.conf"
fi

# Railway sets $PORT — update nginx to listen on it
RAILWAY_PORT=${PORT:-8080}
sed "s/listen 8080/listen $RAILWAY_PORT/" "$NGINX_CONF" > /etc/nginx/sites-available/default
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

echo "[startup] Nginx will listen on port $RAILWAY_PORT"

# -------------------------------------------------------
# 3. Write supervisord config (dynamic paths)
# -------------------------------------------------------
# Detect paths
NODE_BACKEND="$BASE/services/node-backend"
PYTHON_BACKEND="$BASE/services/python-backend"
FRONTEND="$BASE/frontend/.next/standalone"

# Fallback to /app layout (Dockerfile)
[ -d "$NODE_BACKEND/src" ] || NODE_BACKEND="/app/node-backend"
[ -d "$PYTHON_BACKEND/src" ] || PYTHON_BACKEND="/app/python-backend"
[ -d "$FRONTEND" ] || FRONTEND="/app/frontend"

cat > /tmp/supervisord.conf <<HEREDOC
[supervisord]
nodaemon=true
logfile=/dev/stdout
logfile_maxbytes=0
loglevel=info

[program:nginx]
command=nginx -g "daemon off;"
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:node-backend]
command=node ${NODE_BACKEND}/src/index.js
directory=${NODE_BACKEND}
autostart=true
autorestart=true
environment=PORT="4001",NODE_ENV="production"
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:python-backend]
command=uvicorn src.main:app --host 0.0.0.0 --port 4002
directory=${PYTHON_BACKEND}
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:frontend]
command=node ${FRONTEND}/server.js
directory=${FRONTEND}
autostart=true
autorestart=true
environment=PORT="3000",HOSTNAME="0.0.0.0"
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
HEREDOC

echo "[startup] Starting all services via supervisord..."
exec /usr/bin/supervisord -c /tmp/supervisord.conf
