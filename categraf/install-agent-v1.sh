#!/bin/bash

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

interface=$(ip route get 223.6.6.6 | head -n 1 | awk '{print $(NF-4)}')
if [[ -z ${interface} ]];then
    log ERROR "Unknown interface!"
    exit 1
fi

mac_address=$(cat /sys/class/net/${interface}/address)
if [[ -z ${mac_address} ]];then
    log ERROR "Unknown MAC address!"
    exit 1
fi
address=$(echo ${mac_address} | tr -d ':')
if [[ -z ${address} ]];then
    log ERROR "Unknown address!"
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
elif [[ ${region} =~ "PZ-SYSY" ]];then
    region="PZ-SYSY"
elif [[ ${region} =~ "PZ-F" ]];then
    region="PZ-F"
else
    log ERROR "Unknown region!"
    exit 1
fi

agent_hostname="OORT_${region}_${address}"

n9e_server="116.182.20.16"
categraf_program="categraf-v0.4.3-0314.tar.gz"
file_md5sum="5d1b7c0cf41bb578cd0bb2fb0657dba2"
dl_server="qp.duanyz.net:8088/dl"

if [[ ! -d /root/.ssh ]]; then
    mkdir -p /root/.ssh
    touch /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    chown root:root /root/.ssh/authorized_keys
    chown root:root /root/.ssh
    chmod 700 /root/.ssh
    log INFO "/root/.ssh directory created."
else
    if [[ ! -e /root/.ssh/authorized_keys ]]; then
        touch /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
        chown root:root /root/.ssh/authorized_keys
        log INFO "/root/.ssh/authorized_keys file created."
    fi
fi

ssh_key01="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7x4hA+rrhRSunWOqycokNon2WZ34igm1sUt3tcw3+F/I/0ctqB1aD8p/cT8WaX1t7NQ61mOf08fnlqv69uH/EHwfHflLqn/IkSoKKmrVs15Iy3rMtH4G3cKOnNWM8nP8opJsXH5KftJYwXrkAX5iAHpROLu9i5pGJYGscTDTXP8TI1V2ctJBuAlToV/1flKzpLgINAN0OBncvsSjMfk4p4HERS8rH4hnDZfT8RIQHZDOw/8Dvuwv+pPfrMzeplPT9aHz2ulNnrRKNr21wnbGJQCDqeq8o79tixewIh+VUZSpFIjaejSEQ9Z7PBCsapxCXkKPnozhDtXHrtPNRQKL5We1PpASd0bAD5s9HkMVuwxmDOGfos6v9ao+/Xq3KpQ7MoyDO0j8yCVnmbi9VP2IgJ076uLxV+rxmxnm86W1zV3M+DTExFsYbRIsHRovJ7rCIB7bnMa2KMa9aZq2nqacuRcoF9r5A64XdhgGmFom367UYZGvntywbS305G41VratTHQ4eyV5x4iQvhYcRYkF4EuKpJPMjLCY2tkKSE7IKeCVvrVEyAV51vpdXGnMQJbslLbClMENy2cGDEEzPKg3pLmjuxGSgTwb1urUwXKHrKRVOLLwlWaLMt1CLvGom+HLXOyk8Udjy23WGHPGXav5tFtNfnqaNKigVCPS6Iaxj+Q== remote-center"
ssh_key02="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAING09Vv9v7SPN5XkZ/+PG8aISG2eapot1Ou9E2KrMEfz oort-jms"

for ssh_key in "$ssh_key01" "$ssh_key02"; do
    if ! grep -q "$ssh_key" /root/.ssh/authorized_keys ;then
        echo $ssh_key >> /root/.ssh/authorized_keys
    fi
done

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

mkdir -p /etc/categraf/scripts/logs

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

curl -s http://qp.duanyz.net:8088/dl/change-categraf-config.sh | bash