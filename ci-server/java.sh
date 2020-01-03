#! /bin/sh

source ./init-helper.sh
assert_command_exist java -version

yum install -y java-1.8.0-openjdk-devel
HOME=$(which java |xargs ls -lrt |awk '{print $NF}' |xargs ls -lrt |awk '{print $NF}' |awk -F '/' '{for (i=1;i<=NF-4;i++) printf("%s/", $i); print $(NF-3)}')

echo "JAVA_HOME=$HOME" >> /etc/profile
echo PATH='$PATH':$JAVA_HOME/bin >> /etc/profile
assert_status

source /etc/profile
source /$(whoami)/.bashrc
