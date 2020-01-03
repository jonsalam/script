#! /bin/sh

source ./init-helper.sh
assert_command_exist java --version

yum install -y java-1.8.0-openjdk-devel