#!/bin/bash

yum install -y epel-release
yum install -y openvpn

if [[ ! -e /usr/lib/systemd/system/openvpn-daemon.service ]]; then
	cat <<EOF > /usr/lib/systemd/system/openvpn-daemon.service
[Unit]
Description=openvpn daemon
After=openvpn@.service

[Service]
Type=forking
ExecStart=/data/app/vpn/openvpn-daemon.sh
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
fi
if [[ ! -e /data/app/vpn/openvpn-daemon.sh ]]; then
	NAME=$(hostname| awk -F '.' '{print $(NF-1)}')
	cat <<EOF > /data/app/vpn/openvpn-daemon.sh
#!/bin/bash

openvpn --daemon --log-append /var/log/openvpn.log --config /data/app/vpn/$NAME.ovpn
EOF
	chmod +x /data/app/vpn/openvpn-daemon.sh
fi

systemctl enable openvpn-daemon.service
systemctl start openvpn-daemon.service
