#!/usr/bin/env bash

set -euo pipefail

# make sure user is root
user=$(whoami)
if [ $user != 'root' ]; then
  echo "this script must be run as the superuser."
  exit 1
fi

APP_DIR=/home/csss-site/csss-site-config/backend

cd /home/csss-site/csss-site-config
if [ $? -ne 0 ]; then
  echo "Couldn't enter directory /home/csss-site/csss-site-config."
  echo "Stopping here."
  exit 1
fi

echo "----"
echo "(re)starting csss-site service..."
# Sync dependencies
sudo -u csss-site -H /usr/local/bin/uv sync \
  --project "$APP_DIR" \
  --locked
# Restart backend service
systemctl restart csss-site.service

echo "----"
echo "All done!"
