#!/bin/bash

# fallback
# docker rm -f jenkins && rm -rf /data/app/jenkins && userdel jenkins

source ./init-helper.sh
assert_docker_container jenkins

# requirements
install java.sh
install maven.sh
install docker.sh
install nginx.sh

# add user
if [[ -n $(cat /etc/passwd |grep jenkins) ]]; then
	echo '>>> error user:jenkins already exists <<<'
	exit -1
fi
useradd jenkins -U -m
echo '4URqjiepx' | passwd --stdin jenkins
gpasswd -a jenkins docker
mkdir -p /data/app/jenkins
chown jenkins:docker /data/app/jenkins

docker run -d \
  -u root \
  -p 8000:8080 \
  -p 50000:50000 \
  --restart=always \
  -v /data/app/jenkins:/var/jenkins_home \
  -v /data/app/maven:/root/.m2 \
  -v /usr/share/maven-3:/usr/share/maven-3 \
  --env PATH=/usr/share/maven-3/bin:/usr/local/openjdk-8/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /usr/bin/docker:/usr/bin/docker \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  --name jenkins \
  jenkins/jenkins:lts

cp jenkins/jenkins.conf /data/app/nginx/
docker exec -it nginx service nginx reload

# 987d829a31114b32a1d0d1e4484b33e6
password=$(cat /data/app/jenkins/secrets/initialAdminPassword)

echo 'wait Completed initialization'
while true; do
  status=$(curl -s -I -o /dev/null -w %{http_code} http://jenkins.gffst.cn/login\?from\=%2F)
  if [[ $status -eq 200 ]]; then
    echo 'Completed initialization'
    break
  else
    sleep 3
  fi
done
