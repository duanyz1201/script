#!/bin/bash

POOL="stratum+tcp://8.218.72.24:4430"
ACCOUNT="chao576524532"

log_file="/root/logs/setting-asic.log"

log_info() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "${log_file}"
}

log_error() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "${log_file}"
}

get_token() {
    TOKEN=$(curl -s 'http://'${IP}'/user/login?username=admin&password=123456789'|jq -r '."JWT Token"')
    if [[ -z ${TOKEN} ]];then
        log_error "${IP} get token failed!"
        exit 1
    fi
}

get_mac_addr() {
    get_token
    mac_addr=$(curl -s 'http://'${IP}'/mcb/setting' \
  -H 'Authorization: Bearer '${TOKEN}'' | jq -r '.name')

    if [[ -z ${mac_addr} ]];then
        log_error "${IP} get mac addr failed!"
        exit 1
    fi
}

delpools() {
    curl -s 'http://'${IP}'/mcb/delpools' -X 'PUT' -H 'Authorization: Bearer '${TOKEN}''
    if [[ ! $? == 0 ]];then
        log_error "${IP} Failed to delete mining pool"
        exit 1
    fi
}

add_newpool() {
    get_mac_addr
    delpools

    mac=$(echo ${mac_addr} | tr -d ':')
    newpool_info=$(curl -s 'http://'${IP}'/mcb/newpool' \
  -X 'PUT' \
  -H 'Authorization: Bearer '${TOKEN}'' \
  -H 'Content-Type: application/json' \
  --data-raw '{"url":"'${POOL}'","user":"'${ACCOUNT}'.'${mac}'","pass":""}')

    if [[ $(echo ${newpool_info} | jq -r '.[].dragid') == 0 ]];then
        echo "url:${POOL},user:${ACCOUNT}.${mac}"
    else
        echo "add newpool failed!"
        exit 1
    fi
}

start_reboot() {
    get_token
    curl -s 'http://'${IP}'/mcb/restart' -X 'PUT' -H 'Authorization: Bearer '${TOKEN}''
    if [[ $? == 0 ]];then
        log_info "${IP} reboot success"
    else
        log_error "${IP} reboot failed"
    fi
}

run() {
    for ip in $(cat ${1})
    do
        IP="${ip}"
        add_newpool
    done
}

display_mac() {
    for ip in $(cat ${1})
    do
        IP="${ip}"
        get_mac_addr
        echo "$(echo ${ip} | tr '.' '_') $(echo ${mac_addr} | tr -d ':')"
    done
}

reboot() {
    for ip in $(cat ${1}) 
    do
        IP="${ip}"
        start_reboot
        sleep 1
    done
}

$*
