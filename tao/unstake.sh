#!/bin/bash

log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date +"%FT%T.%3N")
    echo "$timestamp $level - $message" >> /root/duanyz/logs/unstake.log
}

script_path="/root/duanyz/unstake.exp"
unstake_output_dir="/root/duanyz/logs/unstake_output"

wallets=(
    "51 51-baiz02 5DA1em5gQmCdoMsc6QUMwhqLRE5byFULbePPc7isbhuX7Wc8 123456"
)

for wallet in "${wallets[@]}"; do
    netuid=$(echo "$wallet" | awk '{print $1}')
    wallet_name=$(echo "$wallet" | awk '{print $2}')
    hotkey=$(echo "$wallet" | awk '{print $3}')
    password=$(echo "$wallet" | awk '{print $4}')

    export netuid
    export wallet_name
    export hotkey
    export password
    log INFO "Netuid: ${netuid}, Hotkey: ${hotkey}, Wallet: ${wallet_name}, Password: ${password}"

    /usr/bin/expect ${script_path} > ${unstake_output_dir}/output_${wallet_name}.txt 2>&1

    Received=$(grep -A 4 "Received (τ)" ${unstake_output_dir}/output_${wallet_name}.txt | tail -n 1 | awk '{print $16}')
    if [[ -z $Received ]]; then
    log ERROR "No 'Received' value found for wallet: ${wallet_name}"
    continue
    fi

    resolt=$(curl --location 'https://api.umpool.io/api/v1/tao/unbond/save' --header 'Content-Type: application/json' --data '{"hotkey": "'$hotkey'","unbond": '${Received}'}')
    resolt_code=$(echo $resolt | jq -r '.code')
    if [[ $resolt_code -eq 200 ]]; then
        log INFO "Unbond successful for wallet: ${wallet_name}, Hotkey: ${hotkey}, Received: ${Received}"
    else
        log ERROR "Unbond failed for wallet: ${wallet_name}, Error code: ${resolt_code}"
    fi
done