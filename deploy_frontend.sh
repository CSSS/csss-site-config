#!/bin/bash

# Version 1.0 of the frontend deployment script
# This is for updating both the `build` and `test` folders.
# This will update the `csss-site-repo` based on what flag you use.
# This will not update the `backend` submodule.

# TODO: Add flags to make deployments more granular so that updating subsites won't disturb other things
show_help() {
    echo "Usage: "$0" [OPTIONS]"
    echo "This is for updating both the $(build) and $(test) folders."
    echo "This will not update the $(backend) submodule."
    echo "This will update the $(csss-site-repo) based on what flag you use."
    echo ""
    echo "Options:"
    echo "  -h, --help  Display this message"
    echo "  -t, --test  Full deployment of the test site"
    echo "  -f, --full  Full deployment of the main site"
}

base_www="/var/www"  # Where the hosted files live
backup="/tmp/backup" # Backup of the currently hosted files
branch=""            # Which csss-site-config branch to use
build=""             # Which branch the built site is on
target=""            # The specific directory the hosted files will be moved to
git_user="csss-site" # The Linux user that controls the git repo on the deployment VM

# Parse the options
while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        show_help
        exit 0
        ;;
    -t | --test)
        branch="develop"
        build="build"
        target="${base_www}/html"
        break
        ;;
    -f | --full)
        branch="master"
        build="test"
        target="${base_www}/test-sfucsss"
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
if [ $(whoami) != 'root' ]; then
    echo "Run this script as the root user"
    echo "Stopping here."
    exit 1
fi
echo -e "\rChecking current user...SUCCESS"

# Check that the deployment folder exists
echo -ne "Checking target directory exists..."
if [ ! -d "$target" ]; then
    echo -e "\rChecking target directory exists...FAILED"
    echo "Directory $($target) doesn't exist"
    echo "Stopping here."
    exit 1
fi
echo -e "\rChecking target directory exists...SUCCESS"
echo "All checks passed."

# Move to site config folder to deploy
echo ""
echo "Moving into 'csss-site-config'..."
cd /home/csss-site/csss-site-config
if [ $? -ne 0 ]; then
    echo "Couldn't enter directory '/home/csss-site/csss-site-config'."
    echo "Stopping here."
    exit 1
fi

# Update the csss-site-config repo as the Git user
echo ""
echo "Updating Git modules..."
# Run all the git stuff as the Git user
su - $git_user <<EOF
echo "Running commands as '$(whoami)'..."
echo -ne "Checking out '${branch}'..."
git checkout ${branch}
if [ $? -ne 0 ]; then
    echo -e "\rChecking out '${branch}'...FAILED"
    echo "Failed to check out '${branch}'."
    exit 1
fi
echo -e "\rChecking out '${branch}'...SUCCESS"
echo -ne "Updating 'csss-site-config'..."
git pull origin ${branch}
if [ $? -ne 0 ]; then
    echo -e "Updating 'csss-site-config'...FAILED"
    echo "Failed to pull from ${branch}."
    exit 1
fi
echo -e "Updating 'csss-site-config'...SUCCESS"
echo -ne "Updating frontend submodule..."
git submodule update frontend
if [ $? -ne 0 ]; then
    echo -e "Updating frontend submodule...FAILED"
    echo "Failed to update frontend submodule."
    exit 1
fi
echo -e "Updating frontend submodule...SUCCESS"
EOF
if [ $? -ne 0 ]; then
    echo "Problem with running Git commands."
    echo "Stopping here."
    exit 1
fi
echo "Updating Git modules done."

echo ""
echo "Replacing deployed files..."
echo "Running commands as '$(whoami)'..."
echo -ne "Backing up '${target}'..."
cp -r ${target} ${backup}
if [ ! -d "$backup" ]; then
    echo -e "\rBacking up '${target}'...FAILED"
    echo "Stopping here."
    exit 1
fi
echo -e "\rBacking up '${target}'...SUCCESS"

echo "Removing current files..."
rm -rf ${target}/*
echo -ne "Copying updated files..."
cp -rf ./frontend/* ${target}
if [ ! -d "$target" ]; then
    echo -e "\rCopying updated files...FAILED"
    echo "Moving backup files."
    mv ${backup} ${target}
    echo "Stopping here."
    exit 1
fi
echo -e "\rCopying updated files...SUCCESS"

echo ""
echo "Deployment successful."
