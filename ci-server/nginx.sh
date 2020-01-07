#!/bin/bash

source ./init-helper.sh

install docker.sh

mkdir -p /data/app/nginx/{www,conf,logs}
assert_status
assert_docker_container nginx
cp nginx/index.html  /data/app/nginx/www
cp nginx/favicon.ico /data/app/nginx/www

cd nginx
docker rm -f mynginx
docker build -t mynginx .
assert_status

docker run -d -P \
  --net=host \
  -v /data/app/nginx/www:/usr/share/nginx/html:ro \
  -v /data/app/nginx/conf:/etc/nginx/conf.d:ro \
  -v /data/app/nginx/logs:/var/log/nginx \
  --restart=always \
  --name nginx \
  mynginx

assert_status