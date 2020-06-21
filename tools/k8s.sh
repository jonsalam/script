#! /bin/bash

set -euxo pipefail

TYPE=$1
[[ -z "$TYPE" ]] && echo '请输入类型：master或者slave'
IP=$2
[[ -z "$IP" ]] && echo '请输入IP地址' && exit 1

function append {
	FILE=$1
	REGX=$2
	if [[ -n "$3" ]]; then
		TEXT=$3
	else
		TEXT=$REGX
	fi

	if [[ -e $FILE ]]; then
		if [[ $(grep -Eq "$REGX" $FILE) -eq 1 ]]; then
			echo "$TEXT" >> $FILE
		fi
	else
		echo "$TEXT" >> $FILE
	fi
}

function docker_tag {
	IMAGE_NAME=$1
	# curl -fsSL "https://hub.docker.com/v2/repositories/$IMAGE_NAME/tags?page_size=1&page=1" |jq -r '.results[0].name'
	kubeadm config images list |grep $(awk $IMAGE_NAME -F '/' '{print $2}') |awk -F ':' '{print $2}'
}

function aliyun_docker_pull {
	IMAGE_NAME=$1
	REPO=$(echo $IMAGE_NAME |awk -F '/' '{print $1}')
	NAME=$(echo $IMAGE_NAME |awk -F '/' '{print $2}')
	TAG=$(kubeadm config images list |grep $NAME |awk -F ':' '{print $2}')
	if [[ $(docker images |grep -q $IMAGE_NAME:$TAG) -eq 0 ]]; then
		docker pull registry.aliyuncs.com/google_containers/$NAME:$TAG
		docker tag registry.aliyuncs.com/google_containers/$NAME:$TAG $IMAGE_NAME:$TAG
		docker rmi registry.aliyuncs.com/google_containers/$NAME:$TAG
	fi
}

function docker_pull {
	IMAGE_NAME=$1
	NEW_IMAGE_NAME=$2
	NAME=$(echo $NEW_IMAGE_NAME |awk -F '/' '{print $2}')
	if [[ $(docker images |grep -q $NEW_IMAGE_NAME) -eq 0 ]]; then
		TAG=$(kubeadm config images list |grep $NAME |awk -F ':' '{print $2}')
		docker pull $IMAGE_NAME:$TAG
		docker tag $IMAGE_NAME:$TAG $NEW_IMAGE_NAME:$TAG
		docker rmi $IMAGE_NAME:$TAG
	fi
}

echo '===='
echo '关闭 selinux'
if [[ "$(getenforce)" != "Disabled" ]]; then
	setenforce 0
fi
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

echo '===='
echo '关闭防火墙'
systemctl stop firewalld
systemctl disable firewalld

echo '===='
echo '关闭swap'
swapoff -a
sed -i 's/^.*swap/# &/' /etc/fstab

echo '===='
echo '修改网卡配置'
append /etc/sysctl.conf 'net.ipv4.ip_forward *= *1'                 'net.ipv4.ip_forward=1'
append /etc/sysctl.conf 'net.bridge.bridge-nf-call-iptables *= *1'  'net.bridge.bridge-nf-call-iptables=1'
append /etc/sysctl.conf 'net.bridge.bridge-nf-call-ip6tables *= *1' 'net.bridge.bridge-nf-call-ip6tables=1'
sysctl -p

echo '===='
echo '修改内核模块'
append /etc/sysconfig/modules/ipvs.modules 'modprobe *-- *ip_vs'             'modprobe -- ip_vs'
append /etc/sysconfig/modules/ipvs.modules 'modprobe *-- *ip_vs_rr'          'modprobe -- ip_vs_rr'
append /etc/sysconfig/modules/ipvs.modules 'modprobe *-- *ip_vs_wrr'         'modprobe -- ip_vs_wrr'
append /etc/sysconfig/modules/ipvs.modules 'modprobe *-- *ip_vs_sh'          'modprobe -- ip_vs_sh'
append /etc/sysconfig/modules/ipvs.modules 'modprobe *-- *nf_conntrack_ipv4' 'modprobe -- nf_conntrack_ipv4'
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4

echo '===='
echo '安装docker'
yum install -y yum-utils device-mapper-persistent-data lvm2 jq
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io
if [[ $(docker info |grep -i cgroup |grep -q cgroupfs) -eq 0 ]]; then
	if [[ -e /etc/docker/daemon.json ]]; then
		if [[ $(jq 'has("exec-opts")' /etc/docker/daemon.json) = 'true' ]]; then
			if [[ $(grep -q 'native.cgroupdriver=cgroupfs' /etc/docker/daemon.json) -eq 0 ]]; then
				sed -i 's/"native.cgroupdriver=cgroupfs"/"native.cgroupdriver=systemd"/' /etc/docker/daemon.json
			fi
		else
			cat /etc/docker/daemon.json |jq --unbuffered '."exec-opts" |= . + ["native.cgroupdriver=systemd"]' |tee /etc/docker/daemon.json
		fi
	else
		cat <<EOF > /etc/docker/daemon.json
{
    "registry-mirrors": [
        "http://hub-mirror.c.163.com"
    ],
    "exec-opts": [
    	"native.cgroupdriver=systemd"
    ]
}
EOF
	fi
fi
systemctl daemon-reload
systemctl restart docker
systemctl enable docker

docker_pull kubeimage/kube-apiserver-amd64          k8s.gcr.io/kube-apiserver
docker_pull kubeimage/kube-controller-manager-amd64 k8s.gcr.io/kube-controller-manager
docker_pull kubeimage/kube-scheduler-amd64          k8s.gcr.io/kube-scheduler
docker_pull kubeimage/kube-proxy-amd64              k8s.gcr.io/kube-proxy
aliyun_docker_pull k8s.gcr.io/pause
aliyun_docker_pull k8s.gcr.io/etcd
aliyun_docker_pull k8s.gcr.io/coredns

echo '===='
echo '安装kubelet'
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
       http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
yum install -y kubelet kubeadm kubectl
systemctl enable kubelet
systemctl start kubelet

if [[ "$TYPE" = 'master' ]]; then
	kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$IP
    mkdir -p $HOME/.kube
    cp /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
	HOSTNAME=$(hostname |awk -F '.localdomain' '{print $1}')
	sed -i -r "s/https?:\/\/$IP/$HOSTNAME/" $HOME/.kube/config

	kubectl apply -f https://gitee.com/mirrors/flannel/raw/master/Documentation/kube-flannel.yml
fi
