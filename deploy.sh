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
echo "(re)starting csss-site service..."
systemctl restart csss-site.service # restart backend

echo "----"
echo "clearing /var/www/html..."
rm -Rf /var/www/html/*

# selectively copy build files to /var/www/html
echo "----"
echo "copying from csss-site-frontend to /var/www/html..."
cp -Rf ./frontend/* /var/www/html
cp -Rf ./events/* /var/www/html

echo "----"
echo "all done!"
