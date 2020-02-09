#!/bin/bash

# fallback
# docker rm -f jenkins && rm -rf /data/app/jenkins && rm -f jenkins/jenkins.cookie && userdel -rf jenkins

source ./init-helper.sh
assert_docker_container jenkins

EMAIL=jonsalam@163.com
PASSWORD=V4OKEThXor
SOURCE_PORT1=8000
TARGET_PORT1=8080

# requirements
install java.sh
install maven.sh
install docker.sh
install nginx.sh
yum install -y jq

grep -q jenkins /etc/passwd
if [[ $? -eq 0 ]]; then
  echo '>> error: user[jenkins] already exists <<'
  exit -1
fi
useradd jenkins -U -m
echo '4URqjiepx' | passwd --stdin jenkins
gpasswd -a jenkins docker
mkdir -p /data/app/jenkins
chown jenkins:docker /data/app/jenkins

docker run -d \
  -u root \
  -p ${SOURCE_PORT1}:${TARGET_PORT1} \
  --restart=always \
  -v /data/app/jenkins:/var/jenkins_home \
  -v /data/app/maven/repository:/root/.m2/repository \
  -v /data/app/maven/maven-3:/usr/share/maven-3 \
  -e PATH=/usr/share/maven-3/bin:/usr/local/openjdk-8/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  -e JAVA_OPTS=-Duser.timezone=Asia/Shanghai \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /usr/bin/docker:/usr/bin/docker \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  --name jenkins \
  jenkins/jenkins:lts

cp jenkins/jenkins.conf /data/app/nginx/conf
docker exec -it nginx service nginx reload
sleep 1

rm -f jenkins/jenkins.cookie
echo 'wait completed initialization 1/4'
while true; do
  status=$(curl -s -I -o /dev/null -w %{http_code} 'http://jenkins.gffst.cn/' -c jenkins/jenkins.cookie)
  if [[ $status -eq 403 ]]; then
    break
  else
    echo -n '-'
    sleep 5
  fi
done
while true; do
  status=$(curl -s -I -o /dev/null -w %{http_code} 'http://jenkins.gffst.cn/login?from=/')
  if [[ $status -eq 200 ]]; then
    echo -e '\ncompleted initialization 1/4'
    break
  else
    echo -n '-'
    sleep 5
  fi
done

cookie=$(sed -n '5p' jenkins/jenkins.cookie)
key=$(echo $cookie |awk {'print $6'})
val=$(echo $cookie |awk {'print $7'})

Jenkins_Crumb=$(curl 'http://jenkins.gffst.cn/login?from=/' -s \
  -H 'Host: jenkins.gffst.cn' \
  -H 'Upgrade-Insecure-Requests: 1' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.117 Safari/537.36' \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
  -H 'Referer: http://jenkins.gffst.cn/' \
  -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,fr;q=0.7' \
  -H "Cookie: $key=$val" \
  --compressed \
  | grep -Eo "[a-zA-Z0-9]{64,64}" )
password=$(cat /data/app/jenkins/secrets/initialAdminPassword)

echo 'input admin password'
rm -f jenkins/jenkins.cookie
curl 'http://jenkins.gffst.cn/j_acegi_security_check' -s -i \
  -c jenkins/jenkins.cookie \
  -H 'Host: jenkins.gffst.cn' \
  -H 'Cache-Control: max-age=0' \
  -H 'Origin: http://jenkins.gffst.cn' \
  -H 'Upgrade-Insecure-Requests: 1' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.117 Safari/537.36' \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
  -H 'Referer: http://jenkins.gffst.cn/login?from=%2F' \
  -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,fr;q=0.7' \
  -H "Cookie: $key=$val" \
  --data "from=%2F&j_username=admin&j_password=$password&Jenkins-Crumb=$Jenkins_Crumb&json=%7B%22from%22%3A+%22%2F%22%2C+%22j_username%22%3A+%22admin%22%2C+%22j_password%22%3A+%22$password%22%2C+%22%24redact%22%3A+%22j_password%22%2C+%22Jenkins-Crumb%22%3A+%22$Jenkins_Crumb%22%7D" \
  --compressed \
  | grep -q 'Location: http://jenkins.gffst.cn/loginError'
if [[ $? -eq 0 ]]; then
  echo '>>> error: input admin password <<<'
  exit -1
fi
cookie=$(sed -n '5p' jenkins/jenkins.cookie)
key=$(echo $cookie |awk {'print $6'})
val=$(echo $cookie |awk {'print $7'})

echo 'wait security check 2/4'
Jenkins_Crumb=$(curl 'http://jenkins.gffst.cn/' -s \
  -H 'Host: jenkins.gffst.cn' \
  -H 'Upgrade-Insecure-Requests: 1' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.117 Safari/537.36' \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
  -H 'Referer: http://jenkins.gffst.cn/' \
  -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,fr;q=0.7' \
  -H "Cookie: $key=$val" \
  --compressed \
  | grep -Eo "[a-zA-Z0-9]{64,64}" )
while true; do
  curl 'http://jenkins.gffst.cn/updateCenter/connectionStatus?siteId=default' -s \
    -H 'Host: jenkins.gffst.cn' \
    -H 'Accept: application/json, text/javascript, */*; q=0.01' \
    -H 'X-Requested-With: XMLHttpRequest' \
    -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.117 Safari/537.36' \
    -H 'Referer: http://jenkins.gffst.cn/' \
    -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,fr;q=0.7' \
    -H "Cookie: $key=$val" \
    --compressed  \
    | jq '.data.internet' \
    | grep -q 'OK'
  if [[ $? -eq 0 ]]; then
    echo -e '\nsecurity checked 2/4'
    break
  else
    echo -n '-'
    sleep 5
  fi
done

echo 'wait install plugins 3/4'
curl 'http://jenkins.gffst.cn/pluginManager/installPlugins' -s \
  -H 'Host: jenkins.gffst.cn' \
  -H 'Accept: application/json, text/javascript, */*; q=0.01' \
  -H 'Origin: http://jenkins.gffst.cn' \
  -H 'X-Requested-With: XMLHttpRequest' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.88 Safari/537.36' \
  -H "Jenkins-Crumb: $Jenkins_Crumb" \
  -H 'Content-Type: application/json' \
  -H 'Referer: http://jenkins.gffst.cn/' \
  -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,fr;q=0.7' \
  -H "Cookie: $key=$val" \
  --data-binary "{\"dynamicLoad\":true,\"plugins\":[\"cloudbees-folder\",\"antisamy-markup-formatter\",\"build-timeout\",\"credentials-binding\",\"timestamper\",\"ws-cleanup\",\"git\",\"ssh-slaves\",\"matrix-auth\",\"pam-auth\",\"ldap\",\"email-ext\",\"mailer\",\"localization-zh-cn\"],\"Jenkins-Crumb\":\"$Jenkins_Crumb\"}" \
  --compressed \
  | jq '.status' \
  | grep -q 'ok'
if [[ $? -eq 1 ]]; then
  echo '>>> error <<<'
  exit -1
fi
while true; do
  curl 'http://jenkins.gffst.cn/updateCenter/installStatus' -s \
    -H 'Host: jenkins.gffst.cn' \
    -H 'Accept: application/json, text/javascript, */*; q=0.01' \
    -H 'X-Requested-With: XMLHttpRequest' \
    -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.88 Safari/537.36' \
    -H 'Referer: http://jenkins.gffst.cn/' \
    -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,fr;q=0.7' \
    -H "Cookie: $key=$val" \
    --compressed \
    |jq '.data.jobs[].installStatus' \
    |grep -Eq 'Pending|Installing'
  if [[ $? -eq 1 ]]; then
    echo -e '\ninstalled plugins 3/4'
    break
  else
    echo -n '-'
    sleep 15
  fi
done

echo 'create admin user 4/4'
Jenkins_Crumb=$(curl 'http://jenkins.gffst.cn/setupWizard/setupWizardFirstUser' -s \
  -H 'Host: jenkins.gffst.cn' \
  -H 'Upgrade-Insecure-Requests: 1' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.117 Safari/537.36' \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
  -H 'Referer: http://jenkins.gffst.cn/' \
  -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,fr;q=0.7' \
  -H "Cookie: $key=$val" \
  --compressed \
  | grep -Eo "[a-zA-Z0-9]{64,64}" )
rm -f jenkins/jenkins.cookie
result=$(curl 'http://jenkins.gffst.cn/setupWizard/createAdminUser' -s \
  -c jenkins/jenkins.cookie \
  -H 'Host: jenkins.gffst.cn' \
  -H 'Accept: application/json, text/javascript, */*; q=0.01' \
  -H 'Origin: http://jenkins.gffst.cn' \
  -H 'X-Requested-With: XMLHttpRequest' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.88 Safari/537.36' \
  -H "Jenkins-Crumb: $Jenkins_Crumb" \
  -H 'Referer: http://jenkins.gffst.cn/' \
  -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,fr;q=0.7' \
  -H "Cookie: $key=$val" \
  --data "username=admin&password1=$PASSWORD&password2=$PASSWORD&fullname=&email=$EMAIL&Jenkins-Crumb=$Jenkins_Crumb&json={\"username\":\"admin\",\"password1\":\"$PASSWORD\",\"$redact\":[\"password1\",\"password2\"],\"password2\":\"$PASSWORD\",\"fullname\":\"\",\"email\":\"$EMAIL\",\"Jenkins-Crumb\":\"$Jenkins_Crumb\"}&core:apply=&Submit=Save" \
  --compressed)
echo $result |jq '.status' |grep 'ok'
if [[ $? -eq 1 ]]; then
  echo ">>> error: $result <<<"
  exit -1
fi
cookie=$(sed -n '5p' jenkins/jenkins.cookie)
key=$(echo $cookie |awk {'print $6'})
val=$(echo $cookie |awk {'print $7'})
Jenkins_Crumb=$(echo $result |jq -r '.data.crumb')
sleep 1
curl 'http://jenkins.gffst.cn/setupWizard/configureInstance' -o /dev/null \
  -H 'Host: jenkins.gffst.cn' \
  -H 'Accept: application/json, text/javascript, */*; q=0.01' \
  -H 'Origin: http://jenkins.gffst.cn' \
  -H 'X-Requested-With: XMLHttpRequest' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.88 Safari/537.36' \
  -H "Jenkins-Crumb: $Jenkins_Crumb" \
  -H 'Referer: http://jenkins.gffst.cn/' \
  -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,fr;q=0.7' \
  -H "Cookie: $key=$val" \
  --data "rootUrl=http://jenkins.gffst.cn/&Jenkins-Crumb=$Jenkins_Crumb&json={\"rootUrl\":\"http://jenkins.gffst.cn/\",\"Jenkins-Crumb\":\"$Jenkins_Crumb\"}" \
  --compressed
echo 'created admin user 4/4'
echo 'jenkins install completed'

docker restart jenkins
append_final_tip "----jenkins----"
append_final_tip "username: admin"
append_final_tip "password: $PASSWORD"
append_final_tip "please reset the password!!!"
# close port
IPTABLE_RULE=$(iptables -L DOCKER -n --line-number|grep $TARGET_PORT1)
l=$(echo "$IPTABLE_RULE" |awk '{print $1}')
s=$(echo "$IPTABLE_RULE" |awk '{print $5}')
d=$(echo "$IPTABLE_RULE" |awk '{print $6}')
append_final_tip "you may run under commands manually"
append_final_tip "iptables -R DOCKER $l -p tcp -m tcp -s $s -d $d --dport $TARGET_PORT1 -j REJECT"
append_final_tip

rm -f jenkins/jenkins.cookie