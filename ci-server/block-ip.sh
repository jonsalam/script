#!/bin/bash

source ./init-helper.sh

check_directory /data/middleware/block-ip.sh
if [[ $? -eq 1 ]]; then
	echo "--- block-ip.sh has already been installed ---"
	exit 100
fi

mkdir -p /data/middleware
cp block-ip.txt /data/middleware/block-ip.sh
chmod +x /data/middleware/block-ip.sh

echo '*/1 * * * *  sh /data/middleware/block-ip.sh' >> /etc/crontab
assert_status
echo "--- block-ip.sh installed ---"