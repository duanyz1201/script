#!/bin/bash

log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date +"%FT%T.%3N")
    echo "$timestamp $level - $message"
}

local_ip=$(ip route get 223.6.6.6 | head -n 1 | awk '{print $(NF-2)}' | tr '.' '-')

if [[ -z ${local_ip} ]];then
    log ERROR "Unknown IP!"
    exit 1
fi

region=${1}
if [[ -z ${region} ]]; then
    log ERROR "Usage: $0 <region>"
    exit 1
fi

if [[ ${region} =~ "ZJDS" ]];then
    region="ZJDS"
elif [[ ${region} =~ "DXJF" ]];then
    region="DXJF"
elif [[ ${region} =~ "JBJF" ]];then
    region="JBJF"
elif [[ ${region} =~ "MHJF" ]];then
    region="MHJF"
elif [[ ${region} =~ "NJJF" ]];then
    region="NJJF"
elif [[ ${region} =~ "QP158" ]];then
    region="QP158"
else
    log ERROR "Unknown region!"
    exit 1
fi

agent_hostname="OORT_${region}_${local_ip}"

n9e_server="116.182.20.16"
categraf_program="categraf-v0.4.3-0314.tar.gz"
file_md5sum="5d1b7c0cf41bb578cd0bb2fb0657dba2"
dl_server="qp.duanyz.net:8088/dl"

if [[ -e /etc/categraf ]];then
    log ERROR "categraf is already installed, exit script..."
    exit 0
fi

curl -s -k -L --max-time 300 http://${dl_server}/${categraf_program} -o /tmp/${categraf_program}

if [[ $? != 0 ]];then
    log ERROR "download categraf failed!"
    rm -f /tmp/${categraf_program}
    exit 1
fi

echo "${file_md5sum} /tmp/${categraf_program}" | md5sum -c

if [[ $? != 0 ]];then
    log ERROR "Abnormal file md5 value"
    rm -f /tmp/${categraf_program}
    exit 1
fi

tar -zxf /tmp/${categraf_program} -C /etc/

if [[ $? != 0 ]];then
    log ERROR "unzip failed!"
    exit 1
fi

config_file="/etc/categraf/conf/config.toml"
if [[ ! -f $config_file ]]; then
    log ERROR "Configuration file $config_file not found!"
    exit 1
fi

sed -i 's/1.1.1.1/'${agent_hostname}'/' $config_file
sed -i 's/shanghai/'${region}'/' $config_file
sed -i 's/172.28.56.119/'${n9e_server}'/g' $config_file

cat << EOF > /etc/systemd/system/categraf-new.service
[Unit]
Description=Opensource telemetry collector
ConditionFileIsExecutable=/etc/categraf/categraf

After=network-online.target
Wants=network-online.target

[Service]
StandardOutput=journal
StandardError=journal
StartLimitInterval=3600
StartLimitBurst=10
ExecStart=/etc/categraf/categraf "-configs" "/etc/categraf/conf"

WorkingDirectory=/etc/categraf

ExecReload=/bin/kill -HUP "$MAINPID"



Restart=on-failure

RestartSec=120
EnvironmentFile=-/etc/sysconfig/categraf
KillMode=process
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now categraf-new.service >/dev/null 2>&1
if [[ $? != 0 ]]; then
    log ERROR "Failed to start categraf-new.service!"
    exit 1
fi

if [[ $(systemctl is-active categraf-new.service) != "active" ]];then
    log ERROR "categraf install failed! please check..."
    exit 1
else
    log INFO "categraf install success"
fi

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
		log ERROR "${process_num} process already exists, exit the script..."
		exit 1
	fi
}

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
systemctl enable network-tunnel.service --now &>/dev/null && log INFO 'enable network-tunnel successful' || log ERROR 'enable network-tunnel failed!'