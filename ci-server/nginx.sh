#! /bin/sh

source ./init-helper.sh

install docker.sh

mkdir -p /data/middleware/nginx/www
mkdir -p /data/middleware/nginx/conf
mkdir -p /data/middleware/nginx/logs
assert_status
assert_docker_container nginx
cp nginx/index.html /data/middleware/nginx/www

cd nginx
docker build -t mynginx .
assert_status

docker run -d -P \
  -p 80:80 \
  -v /data/middleware/nginx/www:/usr/share/nginx/html:ro \
  -v /data/middleware/nginx/conf:/etc/nginx/conf.d:ro \
  -v /data/middleware/nginx/logs:/var/log/nginx \
  --name nginx \
  mynginx
assert_status