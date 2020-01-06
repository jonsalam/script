#!/bin/bash

source ./init-helper.sh

check_directory /data/app/block-ip.sh
if [[ $? -eq 1 ]]; then
	echo "--- block-ip.sh has already been installed ---"
	exit 100
fi

mkdir -p /data/app
cp block-ip.txt /data/app/block-ip.sh
chmod +x /data/app/block-ip.sh

echo '*/1 * * * *  sh /data/app/block-ip.sh' >> /etc/crontab
assert_status