#!/bin/bash

yum install -y git net-tools.x86_64 vim tree

if [[ "$(getenforce)" != "Disabled" ]]; then
	setenforce 0
fi
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

systemctl stop firewalld
systemctl disable firewalld