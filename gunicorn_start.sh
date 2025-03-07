#!/bin/bash

NAME=csss-site
DIR=/home/csss-site/csss-site-config/backend/src
USER=csss-site
GROUP=csss-site
WORKERS=2 # TODO: should we increase this?
WORKER_CLASS=uvicorn.workers.UvicornWorker
VENV=/home/csss-site/csss-site-config/.venv/bin/activate
BIND=unix:/var/www/gunicorn.sock
LOG_LEVEL=error

cd $DIR
source $VENV

gunicorn main:app \
  --name $NAME \
  --workers $WORKERS \
  --worker-class $WORKER_CLASS \
  --user=$USER \
  --group=$GROUP \
  --bind=$BIND \
  --log-level=$LOG_LEVEL \
  --log-file=-
