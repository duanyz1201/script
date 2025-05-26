#！/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root. Please use sudo."
	exit 1
fi

log() {
	local level=$1
	shift
	local message=$@
	local timestamp=$(date +"%FT%T.%3N")
	echo "$timestamp $level - $message"
}

check_and_create_dir() {
    dir=$1
    if [[ ! -d $dir ]]; then
        log INFO "dir $dir does not exist, creating..."
        mkdir -p $dir
    fi
}

check_process() {
	process_name="${1}"
	process_num=$(ps aux |grep "${process_name}"|grep -v grep -c)

	if [[ ${process_num} -ne 0 ]];then
		killall -9 ${process_name} >/dev/null 2>&1
		if [[ $? -ne 0 ]];then
			log ERROR "kill ${process_name} failed!"
			exit 1
		else
			log INFO "kill ${process_name} success"
		fi
	fi
}

dl_server="qp.duanyz.net:8088/dl"
NetworkTunnel_ProgramName="network-tunnel"
NetworkTunnel_dir="/etc/network-tunnel"
NetworkTunnel_log_dir="/var/log/installer"
check_and_create_dir "$NetworkTunnel_dir"
check_and_create_dir "$NetworkTunnel_log_dir"
check_process "network-tunnel"

wget -q -O ${NetworkTunnel_dir}/${NetworkTunnel_ProgramName} "http://${dl_server}/${NetworkTunnel_ProgramName}" 
if [[ $? -ne 0 ]];then
	log ERROR "download file failed!"
    rm -f ${NetworkTunnel_dir}/${NetworkTunnel_ProgramName}
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
name = "${agent_hostname}"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
#remotePort = 22
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
systemctl enable network-tunnel.service >/dev/null 2>&1
systemctl restart network-tunnel.service
if [[ $? -ne 0 ]];then
    log ERROR "network-tunnel install failed!"
    exit 1
else
    log INFO "network-tunnel install success"
fi