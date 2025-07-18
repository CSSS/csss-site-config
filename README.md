# csss-site-config

This repository contains the server configuration files and deployment scripts necessary for https://new.sfucsss.org.

## SysAdmin / Webmaster

### Fresh Setup

On a fresh machine, preferably running Debian 12, get the `fresh_setup.sh` script with the following:

`wget https://raw.githubusercontent.com/CSSS/csss-site-config/refs/heads/master/fresh_setup.sh`

`chmod +x fresh_setup.sh`

`./fresh_setup.sh`

And run it as the superuser. (The server will be completely prepared and deployed.)

### Cloning With Submodules

This repository makes use of git submodules. To clone it, please run:

`git clone git@github.com:CSSS/csss-site-config --recurse-submodules`

If already cloned and you'd like to make changes to the submodules, cd into either backend/frontend and pull, checkout, etc. to set the current state of the submodule, then add the backend/frontend folder via `git add` to update the submodule in the csss-site-config repository.

Alternatively, if you have just pulled recent changes to csss-site-config which has also changed either submodule, run the following to update the submodules' contents:

`git submodule update`

Alternatively, if you would like to update a submodule to the most recent commit from their main/build branch, run the following:

`git submodule update --remote`

And promptly `git add` either backend/frontend folder to update the submodules in the csss-site-config repository.

### Deploying

(Please read the above section for how git submodules work before deploying - don't mess up please.)
#### Full deployment
The following process should be followed to make a deployment to https://new.sfucsss.org:

- Ensure the changes to be deployed are on the `main` branch of csss-site-backend and the `build` branch of csss-site-frontend.
- Clone the csss-site-config repository on your local development machine (see the above section on Cloning With Submodules).
- Run: `git submodule update --remote` from inside the csss-site-config repository to pull the to be deployed changes from csss-site-backend and csss-site-frontend.
  - also `cd frontend; git pull origin build` and `cd backend; git pull origin main`.
- Run: `git add backend frontend` to make csss-site-config acknowledge the new commits to either submodule.
- Run: `git commit -m "(your-commit-message)" && git push origin master` to update the csss-site-config repository.
- SSH into the https://new.sfucsss.org server as the root user.
- Run: `cd /home/csss-site/csss-site-config` to enter the csss-site-config repository.
- Run: `su csss-site` to log into the csss-site user, which is used to deploy.
- Run: `git pull origin master` to pull new commits.
- Run: `git submodule update` to make sure either submodule is up-to-date as set in the repository.
- Run: `./deploy.sh` as the root user to deploy the backend and frontend.

When this script is finished executing, confirm that the deployment was successful by checking the site.

#### Frontend deployment
To update just the frontend, you can run:
```
./deploy_frontend.sh [OPTIONS]
```

This script will avoid restarting the `csss-site.service` and will allow you to update the test site as well.

| Option | Description |
|-----------|-------------|
| -h/--help | Display this message |
| -t/--test | Fully deploy the test site |
| -f/--full | Fully deploy the main site |


### Update Configs / Update HTTPS Certificates

To update any configuration files including the HTTPS certificates:

- SSH into the https://new.sfucsss.org server as the root user.
- Run: `cd /home/csss-site/csss-site-config` to enter the csss-site-config repository.
- Run: `git pull origin master` to pull new commits.
- Run: `git submodule update` to make sure either submodule is up-to-date.
- Run: `./update_config.sh` as the root user to update all configuration files.

When this script is finished executing, confirm that the update was successful by checking the site.

Certbot is run as one of the steps, so interact with certbot as necessary to update the HTTPS certificates.

If you are updating other configuration files and don't need to request new HTTPS certificates, simply choose the option to reinstall the existing certificates instead of requesting new ones.
