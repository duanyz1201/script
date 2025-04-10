#!/bin/bash

ip=$(ip addr|awk -F '[ /]+' '/inet/{print $3}'|grep -oP '^192.(168)\S+'|head -1)
log_dir="/root/logs"
n3_dir="/root/project/network3"
n3_dl_url="http://192.168.30.99/moort-node-v2.2.0.tar.gz"


check_and_create_dir() {
    dir=$1
    if [[ ! -d $dir ]]; then
        echo "dir $dir does not exist, creating..."
        mkdir -p $dir
    fi
}

#check_and_create_dir $n3_dir
check_and_create_dir $log_dir

match_dl_server() {
    random_num=$((RANDOM % 1))

    if [[ $ip ]];then
        ip_prefix=$(echo $ip|awk -F '.' '{print $1"."$2}')
        if [[ "$ip_prefix" = "192.168" ]];then
            dl_servers=("192.168.2.208")
            dl_server=${dl_servers[$random_num]}
        else
            echo "unknown ip prefix"
            exit 1
        fi
    else
        echo "unknown ip addr: $ip"
        exit 1
    fi
}

match_dl_server

check_port() {
     port="$1"
     port_num=$(netstat -tunlp|grep ${port} -c)

     if [[ $port_num -gt 0 ]];then
	     echo "Port $1 already exists"
	     exit 1
     fi
}

check_dependency() {
    command -v $1 &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "$1 is not installed, installing..."
        apt-get update &>/dev/null
        apt-get install -y $1 &>/dev/null
        if [[ $? -eq 0 ]]; then
            echo "$1 installed successfully"
        else
            echo "Failed to install $1, please check"
            exit 1
        fi
    fi
}

check_dependency jq

check_process() {
	process_name="${1}"
	process_num=$(ps aux |grep "${process_name}"|grep -v grep -c)

	if [[ ${process_num} -ne 0 ]];then
		echo "${process_num} process already exists, exit the script..."
		exit 1
	fi
}

start_network3() {

	check_port 8080
	check_process "node --ifname wg0"

	wget -q "${n3_dl_url}" -P /tmp/

	if [[ $? -ne 0 ]];then
		echo "download file failed"
		exit 1
	else
		rm -f /root/project/network3/version*
		tar -zxf /tmp/moort-node-v2.2.0.tar.gz --strip-components=1 -C ${n3_dir}
		if [[ $? -ne 0 ]];then
			echo "unzip failed"
			exit 1
		fi
	fi

	killall -9 unattended-upgrade

cat << EOF > /etc/systemd/system/network3.service
[Unit]
Description = network3
After = network-online.target syslog.target
Wants = network-online.target

[Service]
Type = oneshot
RemainAfterExit = yes
WorkingDirectory = /root/project/network3
ExecStart = /root/project/network3/manager.sh up

[Install]
WantedBy = multi-user.target
EOF

systemctl daemon-reload
systemctl restart network3.service
systemctl enable network3.service &>/dev/null && echo 'enable network3 successful' || echo 'enable network3 failed!'

cd ${n3_dir}
#./manager.sh up &>/dev/null
./manager.sh key|tail -n 1

	process_num=$(ps aux |grep "node --ifname wg0"|grep -v grep -c)
	if [[ ${process_num} -eq 1 ]];then
		echo "network3 start success"
	else
		echo "network3 start failed"
		exit 1
	fi
}

start_dmc() {
	if [[ "$(id -u)" -ne 0 ]];then
		echo "Please run this script as root user"
		exit 1
	fi

    docker version &>/dev/null && echo 'docker installed...' || { echo 'docker not install'; exit 1; }
	killall -9 unattended-upgrade

	#apt-get update >/dev/null && echo 'apt update successful' || { echo 'apt update failed!'; exit 1; }
	#timedatectl set-timezone UTC
	#apt-get install -y openvswitch-switch apt-transport-https ca-certificates curl software-properties-common >/dev/null && echo 'Packages installed successfully' || { echo 'Package installation failed!'; exit 1; }
	#install -m 0755 -d /etc/apt/keyrings
	#curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	#mv /usr/share/keyrings/docker-archive-keyring.gpg /etc/apt/trusted.gpg.d
	#add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" >/dev/null && echo 'add-apt-repository successfully' || { echo 'add-apt-repository failed!'; exit 1; }
	#apt-get update >/dev/null && echo 'apt update successful' || { echo 'apt update failed!'; exit 1; }
	#apt-get install -y docker-ce docker-ce-cli containerd.io glibc-source >/dev/null && echo 'docker install successfully' || { echo 'docker install failed!'; exit 1; }
	#
	#if [ -d /usr/src/glibc/ ]; then
    #		cd /usr/src/glibc/
    #		tar -xf glibc-2.31.tar.xz &>/dev/null
	#else
    #		echo "/usr/src/glibc/ directory does not exist"
    #	exit 1
	#fi

	#apt-get install -y openjdk-11-jre-headless >/dev/null && echo 'openjdk install successfully' || { echo 'openjdk install failed!'; exit 1; }
	systemctl stop ufw
	systemctl disable ufw &>/dev/null && echo 'disable ufw successful' || { echo 'disable ufw failed!'; exit 1; }

	wget -q -O /tmp/vofo-images.tar http://${dl_server}/vofo-images.tar
	if [[ $? -ne 0 ]];then
		echo "download vofo-images.tar failed"
		exit 1
	else
		docker load < /tmp/vofo-images.tar &> /tmp/install_dmc.log
		if [[ $? -ne 0 ]];then
			echo "load images error"
			exit 1
		fi
	fi
 
	echo 'install dmc......'
	#curl -s http://dl.fogworks.io/maxio/online_20.04/install_maxio.sh | bash &> /tmp/install_dmc.log
    curl -s http://8.217.105.129/maxio/online_oort/install_maxio_mp.sh | bash &> /tmp/install_dmc.log

	if [[ -f /opt/facmgr/service/docker-compose-vault.yml ]];then
		#sed -i 's/127.0.0.1:8080:8080/127.0.0.1:8090:8090/' /opt/facmgr/service/docker-compose-vault.yml
		systemctl restart facmgr
		is_enable=$(systemctl is-enabled facmgr)
		if [[ ${is_enable} = enabled ]];then
			echo 'DMC install successfully'
		fi
	else
		echo 'DMC install failed!'
		exit 1
	fi
}

install_NetworkTunnel() {
	NetworkTunnel_ProgramName="network-tunnel"
	NetworkTunnel_dir="/etc/network-tunnel"
	NetworkTunnel_log_dir="/var/log/installer"

	check_and_create_dir "$NetworkTunnel_dir"
	check_and_create_dir "$NetworkTunnel_log_dir"
	check_process "network-tunnel"

	mac_addr=$(ip link show enp1s0 |tail -n 1|awk '{print $2}')
	if [[ ! ${mac_addr} =~ ^([0-9A-Fa-f]{2}[:\-]){5}([0-9A-Fa-f]{2})$ ]];then
		echo "Invalid MAC address"
		exit 1
	fi

	wget -q -O ${NetworkTunnel_dir}/${NetworkTunnel_ProgramName} "http://${dl_server}/${NetworkTunnel_ProgramName}" 
	if [[ $? -ne 0 ]];then
		echo "download file failed!"
		exit 1
	else
		chmod +x ${NetworkTunnel_dir}/${NetworkTunnel_ProgramName}
	fi

cat << EOF > ${NetworkTunnel_dir}/network-tunnel.toml
serverAddr = "47.116.221.100"
serverPort = 7000
auth.method = "token"
auth.token = "yWBqx696i9a72udLQpxs"

loginFailExit = false

log.to = "${NetworkTunnel_log_dir}/network-tunnel.log"
log.level = "info"
log.maxDays = 3

[[proxies]]
name = "${mac_addr}"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
# remotePort = 22
EOF

cat << EOF > /etc/systemd/system/network-tunnel.service
[Unit]
Description = network tunnel client
After = network-online.target syslog.target
Wants = network-online.target

[Service]
Type = simple
ExecStart = ${NetworkTunnel_dir}/${NetworkTunnel_ProgramName} -c ${NetworkTunnel_dir}/network-tunnel.toml
Restart = always
RestartSec = 5s

[Install]
WantedBy = multi-user.target
EOF

systemctl daemon-reload
systemctl enable network-tunnel.service --now &>/dev/null && echo 'enable network-tunnel successful' || echo 'enable network-tunnel failed!'
}

download_categraf() {
    wget -q -O /tmp/categraf-v0.2.9.tgz http://${dl_server}/categraf-v0.2.9.tgz
    if [ $? -ne 0 ]; then
        echo "download categraf-v0.2.9.tgz error"
        return 1
    fi

    pidof categraf >/dev/null && pkill categraf


    [ -d /usr/local/categraf ] && rm -fr /usr/local/categraf

    tar xf /tmp/categraf-v0.2.9.tgz -C /usr/local/

    rm -f /tmp/categraf-v0.2.9.tgz

    \mv /usr/local/categraf/conf/categraf.service /etc/systemd/system/

    mac_addr=$(ip link show enp1s0 |tail -n 1|awk '{print $2}')
    if [[ ! ${mac_addr} =~ ^([0-9A-Fa-f]{2}[:\-]){5}([0-9A-Fa-f]{2})$ ]];then
            echo "Invalid MAC address"
            return 1
    fi
    ident=`echo "$mac_addr"|sed 's/\://g'`
    sed -i "s/replace_hostname/$ident/" /usr/local/categraf/conf/config.toml

    systemctl daemon-reload
    systemctl enable categraf &>/dev/null
    systemctl start categraf

    sleep 3
    pidof categraf &>/dev/null && echo 'install categraf successful' || echo 'install categraf failed!'
}


case $1 in
	start_dmc)
		start_dmc
		;;
	start_network3)
		start_network3
		;;
	install_NetworkTunnel)
		install_NetworkTunnel
		;;
	download_categraf)
		download_categraf
		;;
	all)
		start_dmc
		install_NetworkTunnel
		download_categraf
#		start_network3
		;;
	*)
		echo "Usage: $0 {start_dmc|start_network3}"
		;;
esac
