#!/bin/bash

source ./init-helper.sh

install java.sh
install maven.sh
install docker.sh

assert_docker_container jenkins
