#!/bin/bash

log_file="/root/logs/push-autonomys-balance.log"
date_time=$(date '+%Y-%m-%d %H:%M:%S')


declare -A wallet_address
wallet_address=(
    [公司]="sudkrB27a6qw1Q2FFqM8yUbkJMH4A6nfaUKpLQherhqEZ9tEM"
    [1号节点]="sudhTvKGFJD6YhPaTgFi1YeLqzHFDG2LuunnvjxBxxypsY85y"
    [2号节点]="suebhEcSGRn9zjL5eQmTj8BDWex6TRAmqLYKDqQeAiLejq1Cv"
    [官方程序]="sueANRwsgQYrzRJer8JuWntmo36AcLGqgeAvG4KPg1bJa4NEP"
    [陈迪峰]="sucGYpDqfTkkDAeLbV4a7f7yxbMsJziVmmcW7qTQkMML5M1xb"
)

declare -A balance

for label in "${!wallet_address[@]}"
do
    for address in "${wallet_address[$label]}"
    do
        results=$(curl -s "http://172.28.56.110:17000/api/n9e/proxy/1/api/v1/query?&query=autonomys_account_balance%7Btype%3D%22free%22%2Caddress%3D%22${address}%22%7D%2F1e18")

        if [[ ! $? -eq 0 ]];then
            echo "${date_time}: Balance query failed" &>> ${log_file}
            exit 1
        fi

        result=$(echo ${results} | jq -r '.data.result[].value[1]' | awk '{printf "%.2f\n", $1}')

        balance[$label]+="${result}"
        echo "${date_time}: ${label}:   ${result}" >> ${log_file}
    done
done

for label in "${!wallet_address[@]}"
do
    wallet_balance+="${label}:   ${balance[$label]}\n"
done

subject="$date_time
------钱包余额------"
text=$(echo -e "${wallet_balance}")

echo ${subject}
echo "${text}"

bash /root/script/send-wechat-chihua.sh "4" "${subject}" "${text}" "1000017"
#bash /root/script/send-wechat.sh "1" "${subject}" "${text}" "1000003"