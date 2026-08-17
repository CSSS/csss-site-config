#!/usr/bin/env bash

# Used to install all the services within this repository.
# Run this as root
#   sudo bash /path/to/install-services.sh
set -euo pipefail

if ((EUID != 0)); then
  echo "This script must be run as root."
  exit 1
fi

SERVICES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SYSTEMD_DIR=/etc/systemd/system

shopt -s nullglob

units=(
  "$SERVICES_DIR"/*/*.service
  "$SERVICES_DIR"/*/*.timer
)

timers=(
  "$SERVICES_DIR"/*/*.timer
)

if ((${#units[@]} == 0)); then
  echo "No systemd units found in $SERVICES_DIR. Exiting."
  exit 1
fi

echo "Validating systemd units..."
systemd-analyze verify "${units[@]}"

echo "Installing systemd units..."
for unit in "${units[@]}"; do
  unit_name="$(basename "$unit")"
  install -m 0644 "$unit" "$SYSTEMD_DIR/$unit_name"
  echo "Installed $unit_name"
done

systemctl daemon-reload

echo "Enabling timers..."
for timer_file in "${timers[@]}"; do
  timer_name="$(basename "$timer_file")"

  systemctl enable "$timer_name"
  systemctl restart "$timer_name"

  echo "Enabled and started $timer_name"
done
