#!/bin/bash

function assert_command_exist {
	source /etc/profile
	if command -v $1 > /dev/null; then
		echo "$1 has already been installed"
		$1 $2
		exit 100
	fi
}

function assert_status {
    if [[ $? -ne 0 ]]; then
		echo ">>> error <<<"
        exit -1
    fi
}

function assert_docker_container {
	status=$(docker ps -a --filter name=$1 --format "table {{.Status}}\t{{.ID}}" |sed -n '2p' |awk '{print $1}')
	if [[ -n $status ]]; then
		echo "$1 already installed, status: $status"
		if [[ "$status" != "Up" ]]; then
			docker start $1
			assert_status
		fi
		exit 100
	fi
}

function install {
	bash $1
	STATUS=$?
	if [[ $STATUS -eq 100 ]]; then
		return 100
	elif [[ $STATUS -ne 0 ]]; then
		exit -1
	fi
}

function check_directory {
    if [[ -e $1 ]]; then
        return 1
    else
        return 0
    fi
}

function while_read_line {
	while read line; do
		echo $line
		echo $line |grep $1
		if [[ $? -eq 0 ]]; then
			break
		fi;
	done
}

function wait_docker_container {
	docker logs -f jenkins |while_read_line $1
}