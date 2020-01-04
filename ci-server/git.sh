#!/bin/bash

source ./init-helper.sh
assert_command_exist git --version

yum install -y git