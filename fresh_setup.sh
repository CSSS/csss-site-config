#!/usr/bin/env bash

set -euo pipefail

# this is a script for seting up the website from a fresh install

# NOTE: it should be downloaded directly onto the machine to be set-up with:
# - wget https://raw.githubusercontent.com/CSSS/csss-site-config/refs/heads/master/fresh_setup.sh

# TODO:
# - look into `apt install unattended-upgrades`
# - look into activating fail2ban for ssh protection (I doubt we'll need this unless we get too much random traffic)

# make sure user is root
user=$(whoami)
if [ $user != 'root' ]; then
	echo "this script must be run as the superuser."
	exit 1
fi

echo "hi sysadmin!"
echo "this script will install (almost) everything needed to run the csss website"
echo "(make sure you are running on a Debian 12 Linux machine as the superuser!)"

echo "(P)roceed, (c)ancel?"
read choice

# if choice isn't (P)roceed, just cancel
if [ "$choice" != "P" ]; then
	echo "OK, cancelling."
	exit 0
fi

MAIN_NGINX_CONFIG=/etc/nginx/conf.d/csss-site.conf

# Configure 1GB swapfile
echo "----"
echo "configure swapfile..."
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
sysctl vm.swappiness=10
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf

echo "----"
echo "configure apt sources..."
echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" >/etc/apt/sources.list.d/pgdg.list
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

echo "Adding nginx"
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor |
	sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
https://nginx.org/packages/debian $(lsb_release -cs) nginx" |
	sudo tee /etc/apt/sources.list.d/nginx.list
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" |
	sudo tee /etc/apt/preferences.d/99nginx

echo "----"
echo "update and upgrade apt..."
apt update && apt upgrade -y

echo "----"
echo "install packages..."
apt install \
	git \
	software-properties-common \
	python3 \
	python3-venv \
	libaugeas0 \
	nginx \
	postgresql-15 \
	postgresql-contrib \
	rsync -y

echo "----"
echo "install uv..."
curl -LsSf https://astral.sh/uv/install.sh |
	env UV_UNMANAGED_INSTALL=/usr/local/bin sh

# install certbot
python3 -m venv /opt/certbot
/opt/certbot/bin/pip install --upgrade pip
/opt/certbot/bin/pip install certbot certbot-nginx
ln -s /opt/certbot/bin/certbot /usr/bin/certbot
# NEW: add certbot (pip) as a cronjob
echo "0 0,12 * * * root /opt/certbot/bin/python -c 'import random; import time; time.sleep(random.random() * 3600)' && sudo certbot renew -q" | sudo tee -a /etc/crontab >/dev/null

echo "----"
echo "add user csss_site..."
useradd csss-site -m            # -m: has home /home/csss-site
usermod -L csss-site            # -L: cannot login
chsh -s /usr/bin/bash csss-site # make user csss-site use the bash shell
cd /home/csss-site

echo "----"
echo "clone repository csss-site-config..."
sudo -u csss-site git clone https://github.com/CSSS/csss-site-config --recurse-submodules
cd csss-site-config

echo "----"
echo "configure sudo..."
cp ./sudoers.conf /etc/sudoers.d/csss-site

echo "----"
echo "configure nginx..."
# www-data and /var/www stuff
usermod -aG www-data csss-site
mkdir /var/www/logs
mkdir /var/www/logs/csss-site-backend
mkdir -p /var/www/html/main   # Main site files
mkdir -p /var/www/html/events # Events
chown -R www-data:www-data /var/www
chmod -R ug=rwx,o=rx /var/www

# shared media files
groupadd csss-media
usermod -aG csss-media csss-site # Server will upload media
usermod -aG csss-media nginx     # Nginx will read media
mkdir -p /srv/csss/media
chown -R csss-site:csss-media /srv/csss/media
chmod 2750 /srv/csss/media

# nginx config files
install -m 0644 ./nginx.conf "$MAIN_NGINX_CONFIG"
# remove default configuration to prevent funky certbot behaviour
rm /etc/nginx/sites-enabled/default

# prompt user to modify the nginx configuration if they so please
echo "Do you want to modify the nginx configuration file?"
while true; do
	echo "(M)odify, (c)ontinue?"
	read choice

	if [ $choice = 'M' ]; then
		vim /etc/nginx/sites-available/csss-site
		break
	elif [ $choice = 'c' ]; then
		break
	else
		echo "Not sure what you mean..."
	fi
done

echo "You'll need to fill out the certbot configuration manually."
echo "Use csss-sysadmin@sfu.ca for contact email."
certbot --nginx
nginx -t

echo "----"
echo "starting nginx..."
systemctl enable nginx && systemctl start nginx

echo "----"
echo "configure postgres..."
# see https://towardsdatascience.com/setting-up-postgresql-in-debian-based-linux-e4985b0b766f for more details
# NOTE: the installation of postgresql-15 creates the postgres user, which has special privileges
sudo -u postgres createdb --no-password main
sudo -u postgres createuser --no-password csss-site
sudo -u postgres psql --command='GRANT ALL PRIVILEGES ON DATABASE main TO "csss-site"'
sudo -u postgres psql main --command='GRANT ALL ON SCHEMA public TO "csss-site"'

echo "----"
echo "install uv-managed Python 3.13, and backend dependencies..."
sudo -u csss-site -H env \
	/usr/local/bin/uv sync \
	--project /home/csss-site/csss-site-config/backend \
	--locked \
	--python 3.13 \
	--managed-python

echo "----"
echo "configure csss-site service..."
cp ./csss-site.service /etc/systemd/system/csss-site.service
systemctl enable csss-site

echo "----"
echo "deploy csss-site..."
./deploy.sh
