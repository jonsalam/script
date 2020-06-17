#!/bin/bash

# --------- 环境变量: Jenkins相关 ---------
# /var/jenkins_home
[[ -z "$JENKINS_HOME" ]] && echo "--- 缺少环境变量: JENKINS_HOME ---" && exit 1
# /var/jenkins_home/workspace/dev/komapo-user
[[ -z "$WORKSPACE" ]] && echo "--- 缺少环境变量: WORKSPACE ---" && exit 1
# http://jenkins.gffst.cn/job/dev/job/komapo-user/3/promotion/promotions/promotionBuild/18/
[[ -z "$BUILD_URL" ]] && echo "--- 缺少环境变量: BUILD_URL ---" && exit 1
# --------- 环境变量: Spring相关 ---------
# spring.profiles.active
[[ -z "$ACTIVE_PROFILE" ]] && echo "--- 缺少环境变量: ACTIVE_PROFILE ---" && exit 1
# --------- 环境变量: 镜像相关 ---------
# komapo
[[ -z "$DOCKER_NAMESPACE" ]] && echo "--- 缺少环境变量: DOCKER_NAMESPACE ---" && exit 1
[[ -z "$DOCKER_URL" ]] && echo "--- 缺少环境变量: DOCKER_URL ---" && exit 1
[[ -z "$DOCKER_USERNAME" ]] && echo "--- 缺少环境变量: DOCKER_USERNAME ---" && exit 1
[[ -z "$DOCKER_PASSWORD" ]] && echo "--- 缺少环境变量: DOCKER_PASSWORD ---" && exit 1
# --------- 环境变量: 部署相关 ---------
# ("x.x.x.x")
[[ -z "$SERVER_IPS" ]] && echo "--- 缺少环境变量: SERVER_IPS ---" && exit 1
# 8080
[[ -z "$SERVER_PORT" ]] && echo "--- 缺少环境变量: SERVER_PORT ---" && exit 1

# --------- 变量定义 ---------
echo "JAVA_OPTS=$JAVA_OPTS"
[[ -z "$TIME_OUT" ]] && TIME_OUT="60"
# komapo-user
PROJECT_NAME=$(echo $WORKSPACE | awk -F '/' '{print $NF}')
echo "PROJECT_NAME=$PROJECT_NAME"
# /komapo-user-service
echo "SERVICE_DIR=$SERVICE_DIR"
# 3
BUILD_NO=$(echo $BUILD_URL | grep -Eo "$PROJECT_NAME/[0-9]+" | sed "s/$PROJECT_NAME\///")
echo "BUILD_NO=$BUILD_NO"
# 容器名称: komapo-user
CONTAINER_NAME=$(echo $PROJECT_NAME | tr '[A-Z]' '[a-z]')
echo "CONTAINER_NAME=$CONTAINER_NAME"
# 用于缓存镜像远程地址, /var/jenkins_home/jobs/dev/jobs/komapo-user/builds/3/imageRemote
IMAGE_TAG_CACHE=$JENKINS_HOME/jobs/dev/jobs/$PROJECT_NAME/builds/$BUILD_NO/imageRemote
echo "IMAGE_TAG_CACHE=$IMAGE_TAG_CACHE"
# 用于缓存镜像远程地址, /var/jenkins_home/jobs/dev/jobs/komapo-user/builds/3/projectVersion
PROJECT_VERSION_CACHE=$JENKINS_HOME/jobs/dev/jobs/$PROJECT_NAME/builds/$BUILD_NO/projectVersion
echo "PROJECT_VERSION_CACHE=$PROJECT_VERSION_CACHE"
# /var/jenkins_home/workspace/dev/komapo-user/komapo-user-service/target/classes/git.properties
if [[ -z "$SERVICE_DIR" ]]; then
  GIT_PROPERTIES_FILE=$WORKSPACE/target/classes/git.properties
else
  GIT_PROPERTIES_FILE=$WORKSPACE/$SERVICE_DIR/target/classes/git.properties
fi
echo "GIT_PROPERTIES_FILE=$GIT_PROPERTIES_FILE"
# 版本号: 0.0.1-SNAPSHOT
PROJECT_VERSION=$(grep 'git.build.version=' $GIT_PROPERTIES_FILE | awk -F= '{print $2}')
echo "PROJECT_VERSION=$PROJECT_VERSION"
# 镜像的远程地址
IMAGE_TAG=$DOCKER_URL/$DOCKER_NAMESPACE/$PROJECT_NAME:$PROJECT_VERSION
echo "IMAGE_TAG=$IMAGE_TAG"

# --------- 构建阶段 ---------
if [[ ! -f $IMAGE_TAG_CACHE ]]; then
  # --------- 移除本机旧的容器和镜像 ---------
  if [[ $(docker ps --filter name=$CONTAINER_NAME | sed -n 2p) ]]; then
    echo "--- 0. 移除本机容器 ---"
    docker stop $CONTAINER_NAME
    docker container rm -f $CONTAINER_NAME
  fi
  IMAGE_ID=$(docker images | grep $DOCKER_URL/$DOCKER_NAMESPACE/$PROJECT_NAME | awk '{print $3}')
  if [[ -n "$IMAGE_ID" ]]; then
    echo "--- 0. 移除本机镜像 ---"
    docker rmi -f $IMAGE_ID
  fi
  echo "--- 1. 正在构建镜像 ---"
  if [[ -z "$SERVICE_DIR" ]]; then
    DOCKERFILE="src/main/docker/Dockerfile"
    JAR_FILE="target/$PROJECT_NAME-$PROJECT_VERSION.jar"
  else
    DOCKERFILE=$SERVICE_DIR/src/main/docker/Dockerfile
    JAR_FILE=$SERVICE_DIR/target/$SERVICE_DIR-$PROJECT_VERSION.jar
  fi
  echo "DOCKERFILE=$DOCKERFILE"
  echo "JAR_FILE=$JAR_FILE"
  docker build . \
    -f $DOCKERFILE \
    --build-arg JAR_FILE=$JAR_FILE \
    --build-arg SERVER_PORT=$SERVER_PORT \
    -t $IMAGE_TAG
  if [ $? -ne 0 ]; then
    echo "--- 1 镜像构建失败 ---"
    exit 1
  fi
  echo "--- 1. 镜像构建成功 ---"
  docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD $DOCKER_URL
  echo "--- 1. 正在上传镜像 ---"
  docker push $IMAGE_TAG
  # 删除本地的镜像
  echo "--- 1. 删除本地的镜像 ---"
  docker rmi -f $IMAGE_TAG
  # 向本地文件中写入镜像远程地址
  echo $IMAGE_TAG > $IMAGE_TAG_CACHE
  # 向本地文件中写入版本号
  echo $PROJECT_VERSION > $PROJECT_VERSION_CACHE
else
  # --------- 拉取镜像 ---------
  echo "--- 1. 镜像已构建过 ---"
  [[ ! -f $IMAGE_TAG_CACHE ]] || [[ ! -f $PROJECT_VERSION_CACHE ]] && echo "--- 未找到$IMAGE_TAG_CACHE or $PROJECT_VERSION_CACHE文件 ---" && exit 1
  # 读取本地文件中的镜像远程地址
  IMAGE_TAG=$(cat $IMAGE_TAG_CACHE)
  PROJECT_VERSION=$(cat $PROJECT_VERSION_CACHE)
fi

# --------- 推送阶段 ---------
echo "--- 容器名称: $CONTAINER_NAME ---"
for i in $(seq 0 $((${#SERVER_IPS[*]} - 1))); do
  IP=${SERVER_IPS[${i}]}
  echo "--- 2. 正在推送 $IP, ${i+1}/${#SERVER_IPS[*]} ---"
  # --------- login jenkins@1.1.1.1 ---------
  ssh -i $JENKINS_HOME/.ssh/id_rsa jenkins@$IP <<REMOTE_SHELL
  echo "--- removing container ---"
  docker stop $CONTAINER_NAME
  docker container rm -f $CONTAINER_NAME
  echo "--- removing image ---"
  docker rmi -f $IMAGE_TAG
  echo "--- pulling image ---"
  docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD $DOCKER_URL
  docker pull $IMAGE_TAG
  echo "--- starting container ---"
  docker run -d \
      -u root \
      --net=host \
      --restart=always \
      -e JAVA_OPTS="-Dspring.profiles.active=$ACTIVE_PROFILE -Duser.timezone=Asia/Shanghai $JAVA_OPTS" \
      --name $CONTAINER_NAME \
      $IMAGE_TAG
  [[ \$? -ne 0 ]] && echo "--- start container failed ---" && exit 1
  UP=0
  echo "check http://$IP:$SERVER_PORT/$PROJECT_NAME/actuator/health"
  for i in \$(seq $TIME_OUT -1 1); do
    curl -s http://$IP:$SERVER_PORT/$PROJECT_NAME/actuator/health | jq .status | grep -q "UP"
    if [[ \$? -eq 0 ]]; then
      UP=1
      break
    fi
    sleep 1
  done
  if [[ \$UP -eq 1 ]]; then
    echo "--- started container ---"
  else
    echo "--- start failed container ---"
    exit 1
  fi
  echo "--- started container ---"
REMOTE_SHELL
  if [[ $? -ne 0 ]]; then
    echo "--- 2. 推送失败 $IP, ${i+1}/${#SERVER_IPS[*]} ---"
    exit 1
  fi
  echo "--- 2. 推送成功 $IP, ${i+1}/${#SERVER_IPS[*]} ---"
done
