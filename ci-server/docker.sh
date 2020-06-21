#!/bin/bash

source ./init-helper.sh
assert_command_exist docker -v

yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io
mkdir -p /etc/docker
cat <<EOF > /etc/docker/daemon.json
{
   "registry-mirrors": [
       "https://mirror.ccs.tencentyun.com"
  ]
}
EOF
systemctl start docker
systemctl enable docker