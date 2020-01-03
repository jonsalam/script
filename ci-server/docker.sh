#! /bin/sh

source ./init-helper.sh
assert_command_exist docker -v

yum install -y yum-utils device-mapper-persistent-data lvm2
assert_status
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
assert_status
yum install -y docker-ce docker-ce-cli containerd.io
assert_status
systemctl start docker
assert_status
systemctl enable docker
assert_status