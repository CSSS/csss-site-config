#!/bin/bash
set -euo pipefail

# Version 2.0 of the frontend deployment script
# This is for updating frontend and event static files.
# This will update the `csss-site-config` repo.
# This will not update the `backend` submodule.
# This will update the `frontend` or `events` submodule based on what flag you use.
BASE_WWW="/var/www"  # Where the hosted files live
GIT_USER="csss-site" # The Linux user that controls the git repo on the deployment VM
BACKUP_DIR=""        # Backup of the currently hosted files
branch="master"      # Which csss-site-config branch to use
target="${BASE_WWW}/html"
frontend_target="${target}/main"
deploy_mode=""       # Which static files to deploy
EVENTS=("tech-fair" "fall-hacks" "madness" "frosh")

cleanup() {
  if [ -n "$BACKUP_DIR" ]; then
    rm -rf "$BACKUP_DIR"
    BACKUP_DIR=""
  fi
}
trap cleanup EXIT

restore_backup() {
  echo "Restoring backup files."
  if [ "$deploy_mode" = "main" ]; then
    rsync -a --delete "${BACKUP_DIR}/main/" "${frontend_target}/"
    return
  fi

  for event in "${EVENTS[@]}"; do
    if [ -d "${BACKUP_DIR}/${event}" ]; then
      mkdir -p "${target}/${event}"
      rsync -a --delete "${BACKUP_DIR}/${event}/" "${target}/${event}/"
    else
      rm -rf "${target:?}/${event}"
    fi
  done
}

show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo "This is for updating the main frontend or event sites."
  echo "This will not update the 'backend' submodule."
  echo "This will update the 'csss-site-config' repo."
  echo ""
  echo "Options:"
  echo "  -h, --help    Display this message"
  echo "  -m, --main    Deploy ./frontend/ to /var/www/html/main"
  echo "  -e, --events  Deploy ./events/ event directories to /var/www/html"
}

# If no args are passed show help and fail
if [[ $# -eq 0 ]]; then
  show_help
  exit 1
fi

# Parse the options
while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help)
    show_help
    exit 0
    ;;
  -m | --main)
    deploy_mode="main"
    break
    ;;
  -e | --events)
    deploy_mode="events"
    break
    ;;
  *)
    echo "Unknown option $1. Use $0 -h/--help for usage."
    exit 1
    ;;
  esac
done

if [ -z "$deploy_mode" ]; then
  echo "No deployment mode selected. Use $0 -h/--help for usage."
  exit 1
fi

echo "Running checks..."
# Check that you're the root user first when running the script.
echo -ne "Checking current user..."
if [ "$(whoami)" != "root" ]; then
  echo -e "\rChecking current user...FAILED"
  echo "Run this script as the root user"
  echo "Stopping here."
  exit 1
fi
echo -e "\rChecking current user...SUCCESS"

# Check that the deployment folder exists
echo -ne "Checking target directory exists..."
if [ ! -d "$target" ]; then
  echo -e "\rChecking target directory exists...FAILED"
  echo "Directory ${target} doesn't exist"
  echo "Stopping here."
  exit 1
fi
echo -e "\rChecking target directory exists...SUCCESS"
echo -ne "Checking rsync exists..."
if ! command -v rsync >/dev/null 2>&1; then
  echo -e "\rChecking rsync exists...FAILED"
  echo "Install rsync before running this script."
  echo "Stopping here."
  exit 1
fi
echo -e "\rChecking rsync exists...SUCCESS"
echo "All checks passed."

echo ""
# Move to the config repo
echo "Moving into csss-site-config..."
if ! cd /home/csss-site/csss-site-config; then
  echo "Couldn't enter directory /home/csss-site/csss-site-config."
  echo "Stopping here."
  exit 1
fi
# Update the csss-site-config repo as the Git user
echo ""
echo "Updating Git submodules..."
# Run all the git stuff as the Git user
if ! sudo -u "$GIT_USER" bash <<EOF
set -euo pipefail
echo "Running commands as \$(whoami)..."
echo "Checking current branch"
current_branch=\$(git branch --show-current)
if [ "${branch}" != "\$current_branch" ]; then
    echo -n "Switching to ${branch}..."
    if ! git switch "${branch}"; then
        echo -e "\rSwitching to ${branch}...FAILED"
        echo "Failed to check out ${branch}."
        exit 1
    fi
    echo -e "\rSwitching to ${branch}...SUCCESS"
fi
echo -ne "Updating csss-site-config..."
if ! git pull origin "${branch}"; then
    echo -e "Updating csss-site-config...FAILED"
    echo "Failed to pull from ${branch}."
    exit 1
fi
echo -e "Updating csss-site-config...SUCCESS"
if [ "${deploy_mode}" = "main" ]; then
    echo -ne "Updating frontend submodule..."
    if ! git submodule update frontend; then
        echo -e "Updating frontend submodule...FAILED"
        echo "Failed to update frontend submodule."
        exit 1
    fi
    echo -e "Updating frontend submodule...SUCCESS"
fi
if [ "${deploy_mode}" = "events" ]; then
    echo -ne "Updating events submodule..."
    if ! git submodule update events; then
        echo -e "Updating events submodule...FAILED"
        echo "Failed to update events submodule."
        exit 1
    fi
    echo -e "Updating events submodule...SUCCESS"
fi
EOF
then
  echo "Problem updating Git submodules."
  echo "Stopping here."
  exit 1
fi

chown -R "${GIT_USER}:" /home/csss-site/csss-site-config/.git
echo "Updating Git submodules done."

echo ""
echo "Replacing deployed files..."
echo "Running commands as $(whoami)..."
BACKUP_DIR="$(mktemp -d)"

if [ "$deploy_mode" = "main" ]; then
  echo -ne "Backing up ${frontend_target}..."
  mkdir -p "$frontend_target"
  mkdir -p "${BACKUP_DIR}/main"
  if ! rsync -a --delete "${frontend_target}/" "${BACKUP_DIR}/main/"; then
    echo -e "\rBacking up ${frontend_target}...FAILED"
    echo "Stopping here."
    exit 1
  fi
  echo -e "\rBacking up ${frontend_target}...SUCCESS"

  echo -ne "Copying frontend files to ${frontend_target}..."
  if ! rsync -a --delete ./frontend/ "${frontend_target}/"; then
    echo -e "\rCopying frontend files...FAILED"
    restore_backup
    echo "Stopping here."
    exit 1
  fi
  echo -e "\rCopying frontend files...SUCCESS"
else
  echo -ne "Backing up event sites..."
  for event in "${EVENTS[@]}"; do
    if [ -d "${target}/${event}" ]; then
      rsync -a --delete "${target}/${event}/" "${BACKUP_DIR}/${event}/"
    fi
  done
  echo -e "\rBacking up event sites...SUCCESS"

  echo -ne "Copying event sites and creating symlinks..."
  for event in "${EVENTS[@]}"; do
    source_dir="./events/${event}"
    event_dir="${target}/${event}"

    if [ ! -d "$source_dir" ]; then
      echo "${source_dir} does not exist."
      continue
    fi

    mkdir -p "$event_dir"
    if ! rsync -a --delete "${source_dir}/" "${event_dir}/"; then
      echo -e "\rCopying ${event}...FAILED"
      restore_backup
      echo "Stopping here."
      exit 1
    fi

    latest_year=""
    for year_dir in "$event_dir"/*/; do
      if [ ! -d "$year_dir" ]; then
        continue
      fi

      year="$(basename "$year_dir")"
      if [[ "$year" =~ ^[0-9]{4}$ ]] && [[ -z "$latest_year" || "$year" > "$latest_year" ]]; then
        latest_year="$year"
      fi
    done

    if [ -z "$latest_year" ]; then
      echo "No years found in ${event_dir}"
      continue
    fi

    if ! ln -sfn "$latest_year" "${event_dir}/latest"; then
      echo "Failed to update latest symlink in ${event_dir}."
      restore_backup
      echo "Stopping here."
      exit 1
    fi
    echo "Updated latest symlink in ${event_dir} -> ${latest_year}"
  done
  echo -e "\rCopying event sites and creating symlinks...SUCCESS"
fi

echo "Cleaning up backup files..."
cleanup

echo ""
echo "Deployment successful."
