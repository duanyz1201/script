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
    TOKEN=$(curl -s --max-time 3 'http://'${IP}'/user/login?username=admin&password=123456789'|jq -r '."JWT Token"')
    if [[ -z ${TOKEN} ]];then
        log_error "${IP} get token failed!"
        return 1
    fi
    if [[ ${TOKEN} == "null" ]];then
        log_error "${IP} get token failed!"
        return 1
    fi
    return 0
}

get_mac_addr() {
    get_token
    if [[ $? != 0 ]];then
        log_error "${IP} get token failed!"
        return 1
    fi
    mac_addr=$(curl -s --max-time 3 'http://'${IP}'/mcb/setting' \
  -H 'Authorization: Bearer '${TOKEN}'' | jq -r '.name')

    if [[ -z ${mac_addr} ]];then
        log_error "${IP} get mac addr failed!"
        return 1
    fi
}

delpools() {
    curl -s --max-time 3 'http://'${IP}'/mcb/delpools' -X 'PUT' -H 'Authorization: Bearer '${TOKEN}''
    if [[ ! $? == 0 ]];then
        log_error "${IP} Failed to delete mining pool"
        return 1
    fi
}

add_newpool() {
    get_mac_addr
    if [[ $? != 0 ]];then
        log_error "${IP} get mac addr failed!"
        return 1
    fi

    delpools
    if [[ $? != 0 ]];then
        log_error "${IP} delete pools failed!"
        return 1
    fi

    mac=$(echo ${mac_addr} | tr -d ':')
    newpool_info=$(curl -s --max-time 3 'http://'${IP}'/mcb/newpool' \
  -X 'PUT' \
  -H 'Authorization: Bearer '${TOKEN}'' \
  -H 'Content-Type: application/json' \
  --data-raw '{"url":"'${POOL}'","user":"'${ACCOUNT}'.'${mac}'","pass":""}')

    if [[ $(echo ${newpool_info} | jq -r '.[].dragid') == 0 ]];then
        echo "url:${POOL},user:${ACCOUNT}.${mac}"
    else
        echo "add newpool failed!"
        return 1
    fi
}

start_reboot() {
    get_token
    if [[ $? != 0 ]];then
        log_error "${IP} get token failed!"
        return 1
    fi
    curl -s --max-time 3 'http://'${IP}'/mcb/restart' -X 'PUT' -H 'Authorization: Bearer '${TOKEN}''
    if [[ $? == 0 ]];then
        log_info "${IP} reboot success"
    else
        log_error "${IP} reboot failed"
        return 1
    fi
}

run() {
    for ip in $(cat ${1})
    do
        IP="${ip}"
        add_newpool
        if [[ $? != 0 ]];then
            log_error "${IP} add newpool failed!"
            continue
        fi
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
        if [[ $? != 0 ]];then
            log_error "${IP} reboot failed!"
            continue
        fi
        sleep 1
    done
}

if [[ $# -lt 2 ]];then
    echo "Usage: $0 <ip_list> <action>"
    echo "action: run, display_mac, reboot"
    exit 1
fi

case $2 in
    run)
        run $1
        ;;
    display_mac)
        display_mac $1
        ;;
    reboot)
        reboot $1
        ;;
    *)
        echo "Invalid action: $2"
        echo "action: run, display_mac, reboot"
        exit 1
        ;;
esac