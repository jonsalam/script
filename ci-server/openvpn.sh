# https://www.howtoforge.com/tutorial/how-to-install-openvpn-server-and-client-with-easy-rsa-3-on-centos-7/
new_client () {
	# Generates the custom client.ovpn
	{
	cat /etc/openvpn/client/client-common.txt
	echo "<ca>"
	cat /etc/openvpn/easy-rsa/3/pki/ca.crt
	echo "</ca>"
	echo "<cert>"
	sed -ne '/BEGIN CERTIFICATE/,$ p' /etc/openvpn/client/$1.crt
	echo "</cert>"
	echo "<key>"
	cat /etc/openvpn/client/"$1".key
	echo "</key>"
	} > /etc/openvpn/client/"$1".ovpn
}

if [[ -e /etc/openvpn/server.conf ]]; then
	while :
	do
		echo 'OpenVPN is already installed'
		echo
		echo "What do you want to do?"
		echo "   1) Add a new user"
		echo "   2) Revoke an existing user"
		echo "   3) Remove OpenVPN"
		echo "   4) Exit"
		read -p "Select an option: " option
		until [[ "$option" =~ ^[1-4]$ ]]; do
			echo "$option: invalid selection."
			read -p "Select an option: " option
		done
		case "$option" in
			1)
			read -p "client name [client01]: " unsanitized_client
			# Allow a limited set of characters to avoid conflicts
			client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")
			[[ -z "$client" ]] && client="client01"
			cd /etc/openvpn/easy-rsa/3/
			# Build Client Key
			# ./easyrsa --batch gen-req $client nopass
			# ./easyrsa --batch sign-req client $client
			./easyrsa build-client-full "$client" nopass
			# Optional: Generate the CRL Key
			./easyrsa gen-crl
			cp pki/issued/$client.crt /etc/openvpn/client/
			cp pki/private/$client.key /etc/openvpn/client/
			# Copy CRL Key
			rm -f /etc/openvpn/server/crl.pem
			cp pki/crl.pem /etc/openvpn/server/
			new_client "$client"
			echo
			echo "Finished!"
			echo
			echo "Your client configuration is available at: /etc/openvpn/client/$client.ovpn"
			echo "If you want to add more clients, just run this script again!"
			exit ;;
			2)
			number_of_clients=$(tail -n +2 /etc/openvpn/easy-rsa/3/pki/index.txt | grep -c "^V")
			if [[ "$number_of_clients" = 0 ]]; then
				echo
				echo "You have no existing clients!"
				exit
			fi
			echo
			echo "Select the existing client certificate you want to revoke:"
			tail -n +2 /etc/openvpn/easy-rsa/3/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
			read -p "Select one client: " client_number
			until [[ "$client_number" =~ ^[0-9]+$ && "$client_number" -le "$number_of_clients" ]]; do
				echo "$client_number: invalid selection."
				read -p "Select one client: " client_number
			done
			client=$(tail -n +2 /etc/openvpn/easy-rsa/3/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$client_number"p)
			echo
			read -p "Do you really want to revoke access for client $client? [y/N]: " revoke
			until [[ "$revoke" =~ ^[yYnN]*$ ]]; do
				echo "$revoke: invalid selection."
				read -p "Do you really want to revoke access for client $client? [y/N]: " revoke
			done
			if [[ "$revoke" =~ ^[yY]$ ]]; then
				cd /etc/openvpn/easy-rsa/3/
				./easyrsa --batch revoke "$client"
				./easyrsa gen-crl
				rm -f pki/reqs/"$client".req
				rm -f pki/private/"$client".key
				rm -f pki/issued/"$client".crt
				rm -f /etc/openvpn/server/crl.pem
				cp pki/crl.pem /etc/openvpn/server/
				echo
				echo "Certificate for client $client revoked!"
			else
				echo
				echo "Certificate revocation for client $client aborted!"
			fi
			exit ;;
			3)
			echo
			read -p "Do you really want to remove OpenVPN? [y/N]: " remove
			until [[ "$remove" =~ ^[yYnN]*$ ]]; do
				echo "$remove: invalid selection."
				read -p "Do you really want to remove OpenVPN? [y/N]: " remove
			done
			if [[ "$remove" =~ ^[yY]$ ]]; then
				# eth0
				net_card=$(ip route get 114.114.114.114 | awk 'NR==1 {print $(NF-2)}')
				firewall-cmd --permanent --remove-service=openvpn
				firewall-cmd --permanent --zone=trusted --remove-interface=tun0
				firewall-cmd --permanent --zone=trusted --remove-masquerade
				firewall-cmd --permanent --direct --remove-passthrough ipv4 -t nat -A POSTROUTING -s 10.10.1.0/24 -o $net_card -j MASQUERADE
				firewall-cmd --reload
				systemctl disable --now openvpn-server@server.service
				rm -rf /etc/openvpn/easy-rsa/
				rm -rf /etc/openvpn/server/
				rm -rf /etc/openvpn/client/
				rm -f /etc/systemd/system/openvpn-server@server.service.d/disable-limitnproc.conf
				rm -f /etc/sysctl.d/30-openvpn-forward.conf
				yum remove openvpn -y
				echo
				echo "OpenVPN removed!"
			else
				echo
				echo "Removal aborted!"
			fi
			exit
			;;
			4) exit;;
		esac
	done
else
	echo "What IPv4 address should the OpenVPN server bind to?"
	ip addr | grep inet | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | nl -s ') '
	read -p "IPv4 address [1]: " ip_number
	until [[ -z "$ip_number" || "$ip_number" =~ ^[0-9]+$ && "$ip_number" -le "$number_of_ips" ]]; do
		echo "$ip_number: invalid selection."
		read -p "IPv4 address [1]: " ip_number
	done
	[[ -z "$ip_number" ]] && ip_number="1"
	local_ip=$(ip addr | grep inet | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sed -n "$ip_number"p)
	public_ip=$(wget -4qO- "http://whatismyip.akamai.com/" || curl -4Ls "htyip.akamai.com/")
	echo "public_ip: $public_ip"
	echo -n "DNS: "
	grep -v '#' "/etc/resolv.conf" | grep nameserver | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | while read line; do
		echo -n "$line  "
	done
	echo

	read -p "client name [client01]: " unsanitized_client
	# Allow a limited set of characters to avoid conflicts
	client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")
	[[ -z "$client" ]] && client="client01"

	read -n1 -r -p "Press any key to continue..."

	# Step 1 - Install OpenVPN and Easy-RSA
	# easy-rsa: 3.0.6
	# openvpn : 2.4.8

	yum install epel-release -y
	yum install openvpn easy-rsa -y

	# Step 2 - Configure Easy-RSA 3

	cd /etc/openvpn/
	cp -r /usr/share/easy-rsa/ /etc/openvpn/

	# Step 3 - Build OpenVPN Keys

	cd /etc/openvpn/easy-rsa/3/
	# Initialization and Build CA
	./easyrsa init-pki
	./easyrsa --batch build-ca nopass
	# Build Server Key
	# ./easyrsa --batch gen-req server nopass
	# ./easyrsa --batch sign-req server server
	./easyrsa build-server-full server nopass
	# Build Client Key
	# ./easyrsa --batch gen-req $client nopass
	# ./easyrsa sign-req client $client
	./easyrsa build-client-full "$client" nopass
	# Optional: Generate the CRL Key
	./easyrsa gen-crl
	# Build Diffie-Hellman Key
	./easyrsa gen-dh
	# Copy Certificates Files
	cp pki/ca.crt /etc/openvpn/server/
	cp pki/issued/server.crt /etc/openvpn/server/
	cp pki/private/server.key /etc/openvpn/server/
	# Copy Client Key and Certificate
	cp pki/ca.crt /etc/openvpn/client/
	mv pki/issued/$client.crt /etc/openvpn/client/
	mv pki/private/$client.key /etc/openvpn/client/
	# Copy DH and CRL Key
	cp pki/dh.pem /etc/openvpn/server/
	cp pki/crl.pem /etc/openvpn/server/

	# Step 4 - Configure OpenVPN

	cd /etc/openvpn/
	echo '# OpenVPN Port, Protocol and the Tun
port 1194
proto udp
dev tun

# OpenVPN Server Certificate - CA, server key and certificate
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key

#DH and CRL key
dh /etc/openvpn/server/dh.pem
crl-verify /etc/openvpn/server/crl.pem

# Network Configuration - Internal network
# Redirect all Connection through OpenVPN Server
server 10.10.1.0 255.255.255.0
# push "redirect-gateway def1"
# push "172.21.0.0 255.255.255.0"

#Enable multiple client to connect with same Certificate key
duplicate-cn

# TLS Security
cipher AES-256-CBC
tls-version-min 1.2
tls-cipher TLS-DHE-RSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-256-CBC-SHA256:TLS-DHE-RSA-WITH-AES-128-GCM-SHA256:TLS-DHE-RSA-WITH-AES-128-CBC-SHA256
auth SHA512
auth-nocache

# Other Configuration
keepalive 20 60
persist-key
persist-tun
comp-lzo yes
daemon
user nobody
group nobody

# OpenVPN Log
log-append /var/log/openvpn.log
status /var/log/openvpn-status.log
verb 3
' > server.conf

	echo "push \"$local_ip 255.255.255.0\"" >> server.conf
	grep -v '#' "/etc/resolv.conf" | grep nameserver | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | while read line; do
		echo "push \"dhcp-option DNS $line\"" >> server.conf
	done

	# Step 5 - Enable Port-Forwarding and Configure Routing Firewalld

	# eth0
	net_card=$(ip route get 114.114.114.114 | awk 'NR==1 {print $(NF-2)}')
	systemctl start firewalld
	grep -Eq 'net.ipv4.ip_forward ?= ?1' /etc/sysctl.conf
	if [[ $? -eq 1 ]]; then
		echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf	
	fi
	sysctl -p
	firewall-cmd --permanent --add-service=openvpn
	firewall-cmd --permanent --zone=trusted --add-interface=tun0
	firewall-cmd --permanent --zone=trusted --add-masquerade
	firewall-cmd --permanent --direct --passthrough ipv4 -t nat -A POSTROUTING -s 10.10.1.0/24 -o $net_card -j MASQUERADE
	firewall-cmd --reload
	systemctl start openvpn@server
	systemctl enable openvpn@server

	# Step 6 - OpenVPN Client Setup

	cd /etc/openvpn/client
	echo "client
dev tun
proto udp

remote $public_ip 1194

cipher AES-256-CBC
auth SHA512
auth-nocache
tls-version-min 1.2
tls-cipher TLS-DHE-RSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-256-CBC-SHA256:TLS-DHE-RSA-WITH-AES-128-GCM-SHA256:TLS-DHE-RSA-WITH-AES-128-CBC-SHA256

resolv-retry infinite
compress lzo
nobind
persist-key
persist-tun
mute-replay-warnings
verb 3" > client-common.txt
	new_client "$client"
	echo
	echo "Finished!"
	echo
	echo "Your client configuration is available at: /etc/openvpn/client/$client.ovpn"
	echo "If you want to add more clients, just run this script again!"
fi