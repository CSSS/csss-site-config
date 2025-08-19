#!/bin/bash

# Version 1.0 of the frontend deployment script
# This is for updating both the `build` and `test` folders.
# This will update the `csss-site-repo` based on what flag you use.
# This will not update the `backend` submodule.

BASE_WWW="/var/www"      # Where the hosted files live
BACKUP_DIR="/tmp/backup" # Backup of the currently hosted files
GIT_USER="csss-site"     # The Linux user that controls the git repo on the deployment VM
branch=""                # Which csss-site-config branch to use
target=""                # The specific directory the hosted files will be moved to

# TODO: Add flags to make deployments more granular so that updating subsites won't disturb other things
show_help() {
  echo "Usage: "$0" [OPTIONS]"
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
    echo "Unknown option $($1). Use $($0) -h/--help for usage."
    exit 1
    ;;
  esac
done

echo "Running checks..."
# Check that you're the root user first when running the script.
echo -ne "Checking current user..."
if [ $(whoami) != "root" ]; then
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
echo "All checks passed."

echo ""
# Move to the config repo
echo "Moving into csss-site-config..."
cd /home/csss-site/csss-site-config
if [ $? -ne 0 ]; then
  echo "Couldn't enter directory /home/csss-site/csss-site-config."
  echo "Stopping here."
  exit 1
fi
# Update the csss-site-config repo as the Git user
echo ""
echo "Updating Git modules..."
# Run all the git stuff as the Git user
sudo -u $GIT_USER bash <<EOF
echo "Running commands as \$(whoami)..."
echo "Checking current branch"
current_branch=\$(git branch --show-current)
if [ ${branch} -ne \$current_branch ]; then
    echo -n "Switching to ${branch}..."
    git switch ${branch}
    if [ $? -ne 0 ]; then
        echo -e "\rSwitching to ${branch}...FAILED"
        echo "Failed to check out ${branch}."
        exit 1
    fi
    echo -e "\Switching to ${branch}...SUCCESS"
fi
echo -ne "Updating csss-site-config..."
git pull origin ${branch}
if [ $? -ne 0 ]; then
    echo -e "Updating csss-site-config...FAILED"
    echo "Failed to pull from ${branch}."
    exit 1
fi
echo -e "Updating csss-site-config...SUCCESS"
echo -ne "Updating frontend submodule..."
git submodule update frontend
if [ $? -ne 0 ]; then
    echo -e "Updating frontend submodule...FAILED"
    echo "Failed to update frontend submodule."
    exit 1
fi
echo -e "Updating frontend submodule...SUCCESS"
echo "Returning to master branch"
git switch master
EOF
if [ $? -ne 0 ]; then
  echo "Problem with running Git commands."
  echo "Stopping here."
  exit 1
fi
echo "Updating Git modules done."

echo ""
echo "Replacing deployed files..."
echo "Running commands as $(whoami)..."
echo -ne "Backing up ${target}..."
cp -r ${target} ${BACKUP_DIR}
if [ ! -d "$BACKUP_DIR" ]; then
  echo -e "\rBacking up ${target}...FAILED"
  echo "Stopping here."
  exit 1
fi
echo -e "\rBacking up ${target}...SUCCESS"

echo "Removing current files..."
rm -rf ${target}/*
echo -ne "Copying updated files..."
cp -rf ./frontend/* ${target}
if [ ! -d "$target" ]; then
  echo -e "\rCopying updated files...FAILED"
  echo "Moving backup files."
  mv ${BACKUP_DIR} ${target}
  echo "Stopping here."
  exit 1
fi
echo -e "\rCopying updated files...SUCCESS"

EVENTS=("tech-fair" "fall-hacks" "madness" "frosh")
echo "Creating symlinks to the latest year"
for event in "${EVENTS[@]}"; do
  event_dir="${target}/${event}"

  if [ ! -d "$event_dir" ]; then
    echo "${event_dir} does not exist."
    continue
  fi

  latest_year=$(ls -1d "$event_dir"/*/ 2>/dev/null | sort -r | head -n1 | xargs -n1 basename)

  if [ -z "$latest_year" ]; then
    echo "No years found in ${event_dir}"
    continue
  fi

  ln -sfn "$latest_year" "${event_dir}/latest"
  echo "Updated latest symlink in ${event_dir} -> ${latest_year}"
done

echo "Cleaning up backup files..."
rm -rf ${BACKUP_DIR}

echo ""
echo "Deployment successful."
