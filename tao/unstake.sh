#!/bin/bash

export COLUMNS=200

log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date +"%FT%T.%3N")
    echo "$timestamp $level - $message" >> /root/duanyz/logs/unstake.log
}

script_path="/root/duanyz/unstake.exp"
unstake_output_dir="/root/duanyz/logs/unstake_output"

online_url="https://api.umpool.io/api/v1/tao/unbond/save"
test_url="http://172.28.56.107:12001/api/v1/tao/unbond/save"

declare -A wallet_api_map=(
    ["zw-20"]="$online_url $test_url"
    ["sg-5"]="$online_url"
    ["51-baiz02"]="$online_url"
    ["chen"]="$online_url"
    ["51-baiz03"]="$online_url"
    ["sc-11-a100"]="$test_url"
    ["sc-7-h100"]="$test_url"
)

wallets=(
    "51 51-baiz02 5DA1em5gQmCdoMsc6QUMwhqLRE5byFULbePPc7isbhuX7Wc8 123456"
    "51 51-baiz03 5CAPKyuPdqYZFjd6nVQnpk1JuhAaEm3vaGvprNU6zHBnBf3Z 123456"
    "51 chen 5CzR9HVq2yUCvnrgDxM6zp4MvQRTQu7y2m4mQ4C3E6Aoceh3 A123.com"
    "64 sg-5 5DPB6bPAqBC7JMBMzdwyA4k4WsreoGpHkixZh1QZS7R9pFyr 123456"
    "64 zw-20 5Ev5zc4wGtZEheyT3PviYHMLi1yU7sovyrDSxUvdkKe4mHL1 123456"
    "64 sc-11-a100 5C5rp9HcVTUn963AET4VpsVA4azawYxrQnuF39hkTUEopYZ4 123456"
    "64 sc-7-h100 5DqTcmSHHBzy59EoJgZVQH5XsoiS4Sz4PVdX17pLWQHxzTyh 123456"
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
    if [[ $? -ne 0 ]]; then
        log ERROR "Expect script failed for wallet: ${wallet_name}"
        continue
    fi

    if ! grep -q "Finalized" ${unstake_output_dir}/output_${wallet_name}.txt; then
        log ERROR "Finalized not found in output for wallet: ${wallet_name}"
        continue
    fi

    Received=$(grep -A 4 "Received (τ)" ${unstake_output_dir}/output_${wallet_name}.txt | tail -n 1 | awk '{print $16}')
    if [[ -z $Received ]]; then
    log ERROR "No 'Received' value found for wallet: ${wallet_name}"
    continue
    fi

    api_urls=${wallet_api_map[$wallet_name]}
    if [[ -z $api_urls ]]; then
        log ERROR "No API URL found for wallet: ${wallet_name}"
        continue
    fi
    for api_url in $api_urls; do
        if [[ -z "$api_url" ]]; then
            log ERROR "Empty API URL for wallet: ${wallet_name}"
            continue
        fi
        log INFO "Wallet Name : $wallet_name, API URL: ${api_url}"

        result=$(curl --location ${api_url} --header 'Content-Type: application/json' --data '{"hotkey": "'$hotkey'","unbond": '${Received}'}')
        if [[ $? -ne 0 || -z $result ]]; then
            log ERROR "API request failed for wallet: ${wallet_name}, Hotkey: ${hotkey}"
            continue
        fi

        result_code=$(echo $result | jq -r '.code')
        if [[ $result_code -eq 200 ]]; then
            log INFO "Unbond successful for wallet: ${wallet_name}, Hotkey: ${hotkey}, Received: ${Received}"
        else
            log ERROR "Unbond failed for wallet: ${wallet_name}, Error code: ${result_code}"
        fi
    done
done