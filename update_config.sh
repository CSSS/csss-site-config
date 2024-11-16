#!/bin/bash

# make sure user is root
user=$(whoami)
if [ $user != 'root' ]; then
	echo "this script must be run as the superuser."
	exit 1
fi

cd /home/csss-site/csss-site-config
if [ $? -ne 0 ]; then
    echo "couldn't enter directory /home/csss-site/csss-site-config."
    echo "stopping here."
    exit 1
fi

echo "----"
echo "update sudo..."
cp ./sudoers.conf /etc/sudoers.d/csss-site

echo "----"
echo "update nginx..."
cp ./nginx.conf /etc/nginx/sites-available/csss-site
certbot --nginx # reconfigure the server with SSL certificates
nginx -t
# only restart nginx if config is valid
if [ $? -eq 0 ]; then
	systemctl restart nginx
fi

echo "----"
echo "update csss-site service..."
systemd-analyze verify ./csss-site.service
# only use new service if it is valid
if [ $? -eq 0 ]; then
	cp ./csss-site.service /etc/systemd/system/csss-site.service
	systemctl daemon-reload
	systemctl restart csss-site.service
fi
