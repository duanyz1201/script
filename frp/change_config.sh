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

network_tunnel_status=$(systemctl is-active network-tunnel)
if [[ $? -ne 0 || $network_tunnel_status != "active" ]];then
    log ERROR "network-tunnel is not running!"
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

if [[ ! -e "/etc/network-tunnel/network-tunnel.toml" ]];then
    log ERROR "network-tunnel.toml not found!"
    exit 1
fi

current_name=$(grep name /etc/network-tunnel/network-tunnel.toml |awk -F '"' '{print $2}')
if [[ -z ${current_name} ]];then
    log ERROR "network-tunnel.toml name not found!"
    exit 1
fi

split_name=$(echo ${current_name} | awk -F '_' '{print $1"_"$2}')
if [[ -z ${split_name} ]];then
    log ERROR "network-tunnel.toml split_name not found!"
    exit 1
fi

new_name="${split_name}_${address}"
if [[ -z ${new_name} ]];then
    log ERROR "network-tunnel.toml new_name not found!"
    exit 1
fi
if [[ ${current_name} != ${new_name} ]];then
    sed -i "s/${current_name}/${new_name}/g" /etc/network-tunnel/network-tunnel.toml
    if [[ $? -ne 0 ]];then
        log ERROR "network-tunnel.toml update name failed!"
        exit 1
    fi
    systemctl restart network-tunnel
    if [[ $? -ne 0 ]];then
        log ERROR "network-tunnel restart failed!"
        exit 1
    fi
fi
log INFO "network-tunnel config changed successfully!"
log INFO "network-tunnel name changed from ${current_name} to ${new_name}"