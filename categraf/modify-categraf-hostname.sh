#!/usr/bin/env bash

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

categraf_status=$(systemctl is-active categraf-new)
if [[ $? -ne 0 || $categraf_status != "active" ]];then
    log ERROR "categraf is not running!"
    exit 1
fi

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

if [[ ! -e "/etc/categraf/conf/config.toml" ]];then
    log ERROR "categraf config file not found!"
    exit 1
fi

need_restart=0

current_ip=$(grep '^ip' /etc/categraf/conf/config.toml |awk -F '"' '{print $2}')
if [[ -z ${current_ip} ]];then
    sed -i '/^\[global.labels\]/a ip = "$ip"' /etc/categraf/conf/config.toml
    if [[ $? -ne 0 ]];then
        log ERROR "categraf config file add ip failed!"
        exit 1
    fi
else
    if [[ ${current_ip} != "\$ip" ]];then
    sed -i 's/^ip = ".*"/ip = "\$ip"/' /etc/categraf/conf/config.toml
    if [[ $? -ne 0 ]];then
        log ERROR "categraf config file update ip failed!"
        exit 1
    fi
    need_restart=1
    fi
fi

current_name=$(grep '^hostname' /etc/categraf/conf/config.toml |awk -F '"' '{print $2}')
if [[ -z ${current_name} ]];then
    log ERROR "categraf config file name not found!"
    exit 1
fi
split_name=$(echo ${current_name} | awk -F '_' '{print $1"_"$2}')
if [[ -z ${split_name} ]];then
    log ERROR "categraf config file split_name not found!"
    exit 1
fi
new_name="${split_name}_${address}"
if [[ -z ${new_name} ]];then
    log ERROR "categraf config file new_name not found!"
    exit 1
fi

local_ip=$(ip route get 223.6.6.6 | head -n 1 | awk '{print $(NF-2)}')
if [[ $? -ne 0 || -z $local_ip ]];then
    log ERROR "get local ip failed!"
    local_ip="unknown"
fi

if [[ ${current_name} != ${new_name} ]];then
    sed -i "s/${current_name}/${new_name}/g" /etc/categraf/conf/config.toml
    if [[ $? -ne 0 ]];then
        log ERROR "categraf config file update name failed!"
        exit 1
    fi
    need_restart=1
fi

if [[ ${need_restart} -eq 1 ]];then
    systemctl restart categraf-new
    if [[ $? -ne 0 ]];then
        log ERROR "categraf restart failed!"
        exit 1
    fi
fi
log INFO "categraf config changed successfully!"