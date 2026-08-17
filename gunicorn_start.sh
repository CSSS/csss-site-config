#!/usr/bin/env bash

set -euo pipefail

DIR=/home/csss-site/csss-site-config/backend/src
GUNICORN=/home/csss-site/csss-site-config/backend/.venv/bin/gunicorn
NAME=csss-site
WORKERS=1
WORKER_CLASS=uvicorn.workers.UvicornWorker
BIND=unix:/var/www/gunicorn.sock
LOG_LEVEL=error

cd "$DIR"

# Use exec so we don't spawn a new process and instead replace the shell
exec "$GUNICORN" main:app \
  --name $NAME \
  --workers $WORKERS \
  --worker-class $WORKER_CLASS \
  --bind=$BIND \
  --log-level=$LOG_LEVEL \
  --log-file=-
