#!/bin/bash

function delete {
	iptables -D PRE_DOCKER -s 172.21.0.0/24 -j ACCEPT
	iptables -D PRE_DOCKER -s 10.10.1.0/24 -j ACCEPT

	lines=$(iptables -nL FORWARD --line |grep PRE_DOCKER |awk '{print $1}' |sort -r)
	for line in $lines; do
		iptables -D FORWARD $line
	done
	iptables -F PRE_DOCKER
	iptables -X PRE_DOCKER
}

function add {
	iptables -N PRE_DOCKER
	iptables -I FORWARD -o docker0 -j PRE_DOCKER
	iptables -A PRE_DOCKER -i docker0 ! -o docker0 -j ACCEPT
	iptables -A PRE_DOCKER -i docker0 -o docker0 -j ACCEPT
	iptables -A PRE_DOCKER -j REJECT

	iptables -I PRE_DOCKER -s 172.21.0.0/24 -j ACCEPT
	iptables -I PRE_DOCKER -s 10.10.1.0/24 -j ACCEPT
}

iptables -L|grep PRE_DOCKER -qa
if [[ $? -eq 0 ]]; then
	delete
	add
	echo "update PRE_DOCKER chain to iptables"
else
	add
	echo "insert PRE_DOCKER chain to iptables"
fi