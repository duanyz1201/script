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
    local timestamp=$(date +"%FT%T.%3N")
    echo "$timestamp [$level] - $message" >> /etc/categraf/scripts/logs/check-tao-cluster-status.log
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
)

declare -A miner_api=(
    [sg-5]="http://98.98.124.203:32000"
    [zw-20]="http://103.129.53.118:32000"
    [ws-01]="http://163.171.253.25:32000"
    [ws-02]="http://163.171.193.6:32000"
    [sc-07]="http://203.175.15.189:32000"
    [sc-11]="http://203.175.15.190:32000"
)

for label in "${!hotkey_paths[@]}"
do
    for path in "${hotkey_paths[$label]}"
    do
        api_url=${miner_api[$label]}
        local_inventory_response=$($chutes_miner_path local-inventory --hotkey $path --miner-api $api_url --raw-json)
        if [[ $? -ne 0 ]]; then
            log ERROR "Failed to get local inventory for $label"
            continue
        fi
        if [[ -z $local_inventory_response ]]; then
            log ERROR "local inventory response for $label is empty"
            continue
        fi
        node_num=$(echo "${local_inventory_response}" | jq -r '[.[]]|length')
        gpu_num=$(echo "${local_inventory_response}" | jq -r '[.[]|.gpus[]]|length')
        active_gpu_num=$(echo "${local_inventory_response}" | jq -r '[.[]|.deployments[].gpus|length]|add // 0')
        inactive_gpu_num=$(( gpu_num - active_gpu_num ))
        active_num=$(echo "${local_inventory_response}" | jq -r '[.[]|.deployments[]|select(.active == true)|.gpus|length]|add // 0')
        inactive_num=$(echo "${local_inventory_response}" | jq -r '[.[]|.deployments[]|select(.active == false)|.gpus|length]|add // 0')
        hotkey_address=$(cat $path | jq -r '.ss58Address')
        echo "tao_cluster_status,hotkey=${hotkey_address},cluster=${label} node_num=${node_num},gpu_num=${gpu_num},inactive_gpu_num=${inactive_gpu_num},active=${active_num},inactive=${inactive_num}"
    done
done