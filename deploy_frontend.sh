#!/bin/bash
set -euo pipefail

# Version 1.0 of the frontend deployment script
# This is for updating both the `build` and `test` folders.
# This will update the `csss-site-repo` based on what flag you use.
# This will not update the `backend` submodule.
# This will update both the `frontend` and `events` submodules.
BASE_WWW="/var/www"  # Where the hosted files live
GIT_USER="csss-site" # The Linux user that controls the git repo on the deployment VM
BACKUP_DIR=""        # Backup of the currently hosted files
branch=""            # Which csss-site-config branch to use
target=""            # The specific directory the hosted files will be moved to
frontend_target=""   # Where frontend files will be moved to

cleanup() {
  if [ -n "$BACKUP_DIR" ]; then
    rm -rf "$BACKUP_DIR"
    BACKUP_DIR=""
  fi
}
trap cleanup EXIT

restore_backup() {
  echo "Restoring backup files."
  rsync -a --delete "${BACKUP_DIR}/" "${target}/"
}

# TODO: Add flags to make deployments more granular so that updating subsites won't disturb other things
show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo "This is for updating both the 'build' and 'test' sites."
  echo "This will not update the 'backend' submodule."
  echo "This will update the 'csss-site-config' repo."
  echo ""
  echo "Options:"
  echo "  -h, --help  Display this message"
  echo "  -t, --test  Full deployment of the test site"
  echo "  -f, --full  Full deployment of the main site"
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
  -t | --test)
    branch="develop"
    target="${BASE_WWW}/test-sfucsss"
    break
    ;;
  -f | --full)
    branch="master"
    target="${BASE_WWW}/html"
    break
    ;;
  *)
    echo "Unknown option $1. Use $0 -h/--help for usage."
    exit 1
    ;;
  esac
done

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
frontend_target="${target}/main"
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
echo -ne "Updating frontend submodule..."
if ! git submodule update frontend; then
    echo -e "Updating frontend submodule...FAILED"
    echo "Failed to update frontend submodule."
    exit 1
fi
echo -e "Updating frontend submodule...SUCCESS"
echo -ne "Updating events submodule..."
if ! git submodule update events; then
    echo -e "Updating events submodule...FAILED"
    echo "Failed to update events submodule."
    exit 1
fi
echo -e "Updating events submodule...SUCCESS"
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
echo -ne "Backing up ${target}..."
BACKUP_DIR="$(mktemp -d)"
if ! rsync -a --delete "${target}/" "${BACKUP_DIR}/"; then
  echo -e "\rBacking up ${target}...FAILED"
  echo "Stopping here."
  exit 1
fi
echo -e "\rBacking up ${target}...SUCCESS"

echo -ne "Copying frontend files to ${frontend_target}..."
mkdir -p "$frontend_target"
if ! rsync -a --delete ./frontend/ "${frontend_target}/"; then
  echo -e "\rCopying updated files...FAILED"
  restore_backup
  echo "Stopping here."
  exit 1
fi
echo -e "\rCopying frontend files...SUCCESS"

echo -ne "Copying event sites and creating symlinks..."
EVENTS=("tech-fair" "fall-hacks" "madness" "frosh")
if ! rsync -a ./events/ "${target}/"; then
  echo -e "\rCopying event sites and creating symlinks...FAILED"
  restore_backup
  echo "Stopping here."
  exit 1
fi

for event in "${EVENTS[@]}"; do
  event_dir="${target}/${event}"

  if [ ! -d "$event_dir" ]; then
    echo "${event_dir} does not exist."
    continue
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

echo "Cleaning up backup files..."
cleanup

echo ""
echo "Deployment successful."
