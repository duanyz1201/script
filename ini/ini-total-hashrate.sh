#!/usr/bin/env bash

log_file="/etc/categraf/scripts/logs/ini-total-hashrate.log"

log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%FT%T.%3N")
    echo "$timestamp $level - $message" >> "${log_file}"
}

response=$(curl -s --max-time 6 --retry 2 'https://explorer-api.inichain.com/api/block/total_hashrate')
if [[ $? -ne 0 || -z "${response}" ]]; then
    log ERROR "Failed to fetch total hashrate"
    total_hashrate=0
fi

total_hashrate=$(echo "${response}" | jq -r '.total_hashrate')

echo "ini total_hashrate=${total_hashrate}"