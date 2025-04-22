#!/bin/bash

exec 2>/dev/null
# 检查是否具有 root 权限
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date +"%FT%T.%3N%")
    echo "$timestamp [$level] - $message" >> /etc/categraf/scripts/logs
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

chutes_miner_path="/usr/local/bin/chutes-miner"

declare -A hotkey_paths=(
    [sg-5]="/etc/categraf/scripts/tao-key/sg-5-hotkey"
    [zw-20]="/etc/categraf/scripts/tao-key/zw-20-hotkey"
    [ws-01]="/etc/categraf/scripts/tao-key/ws-01-hotkey"
    [ws-02]="/etc/categraf/scripts/tao-key/ws-02-hotkey"
    [sc-07]="/etc/categraf/scripts/tao-key/sc-07-hotkey"
    [sc-11]="/etc/categraf/scripts/tao-key/sc-11-hotkey"
    [4090-03-test]="/etc/categraf/scripts/tao-key/4090-03-test-hotkey"
)

for label in "${!hotkey_paths[@]}"
do
    for path in "${hotkey_paths[$label]}"
    do
        remote_inventory_response=$($chutes_miner_path remote-inventory --hotkey $path --raw-json)
        if [[ $? -ne 0 ]]; then
            log ERROR "Failed to get remote inventory for $label"
            exit 1
        fi
        if [[ -z $remote_inventory_response ]]; then
            log ERROR "Remote inventory response for $label is empty"
            exit 1
        fi
        node_num=$(echo "${remote_inventory_response}" | jq -r '[.[]|select(.device_index == 0)]|length')
        active_num=$(echo "${remote_inventory_response}" | jq -r '[.[]|select(.inst_verified_at != null)]|length')
        inactive_num=$(echo "${remote_inventory_response}" | jq -r '[.[]|select(.inst_verified_at == null)]|length')
        hotkey_address=$(cat $path | jq -r '.ss58Address')
        echo "tao_cluster_status,hotkey=${hotkey_address},cluster=${label} node_num=${node_num},active=${active_num},inactive=${inactive_num}"
    done
done