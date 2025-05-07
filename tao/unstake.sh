#!/bin/bash

wallets=(
    "5DPB6bPAqBC7JMBMzdwyA4k4WsreoGpHkixZh1QZS7R9pFyr sg-5 123456"
)

for wallet in "${wallets[@]}"; do
    hotkey=$(echo "$wallet" | awk '{print $1}')
    wallet_name=$(echo "$wallet" | awk '{print $2}')
    password=$(echo "$wallet" | awk '{print $3}')

    export hotkey
    export wallet_name
    export password
    echo "Hotkey: ${hotkey}, Wallet: ${wallet_name}, Password: ${password}"

   # /usr/bin/expect ./unstake.exp > output_${wallet_name}.txt 2>&1

   # Received=$(grep -A 4 "Received (Τ)" output_${wallet_name}.txt | tail -n 1 | awk '{print $18}')

   # echo "Wallet: ${wallet_name}, Hotkey: ${hotkey}, Received: ${Received}"
done