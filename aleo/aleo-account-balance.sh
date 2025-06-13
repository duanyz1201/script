#!/usr/bin/env bash

log_file="/etc/categraf/scripts/logs/aleo-account-balance.log"

log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%FT%T.%3N")
    echo "$timestamp $level - $message" >> "${log_file}"
}

account="aleo1308gq2pfn0y3hgm722wysx4ks8szxc0yw02dj4cn76ul2n3ae5rqu89c6m"
# account="aleo1qeyuw2vq3lmukd3z6ryevq75lvkfutxj3743693m5dadghczqsqsrshe0r"
node_url="http://58.221.165.122:3030/mainnet/program/credits.aleo/mapping/account/"

response=$(curl -s --max-time 6 --retry 2 "${node_url}${account}")
if [[ $? -ne 0 || -z "${response}" ]]; then
    log INFO "Failed to fetch account balance"
    balance=-1
fi

if [[ "${response}" == null ]]; then
    log INFO "balance = null"
    balance=0
else
    balance=$(echo "${response}" | jq -r | sed 's/u64//' | awk '{printf "%.6f\n", $1 / 1000000}')
    if [[ $? -ne 0 || -z "${balance}" ]]; then
        log INFO "Failed to parse balance"
        balance=-1
    else
        log INFO "Balance fetched successfully: ${balance}"
    fi
fi

echo aleo_account,account="${account}" balance="${balance}"