#!/usr/bin/env bash

log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date +"%FT%T.%3N")
    echo "$timestamp $level - $message"
}

Token=$(curl -s -X POST 'http://172.28.56.119:16000/api/n9e/auth/login' -d '{"username": "readonly", "password": "readonly"}'|jq -r .dat.access_token)
if [[ $? != 0 || -z $Token ]];then
    log ERROR "get token failed!"
    exit 1
fi

oort_alert=$(curl -s "http://172.28.56.119:16000/api/n9e/alert-cur-events/list?p=1&limit=3000&bgid=16&rule_prods=host" -H "Authorization: Bearer $Token")
if [[ $? != 0 || -z $oort_alert ]];then
    log ERROR "get oort alert failed!"
    exit 1
else
    echo $oort_alert | jq '[.dat.list[] | {rule_name,target_ident,first_trigger_time,ip: (.tags[] | select(startswith("ip=")) | split("=")[1]),region: (.tags[] | select(startswith("region=")) | split("=")[1])}]' > /usr/share/nginx/html/oort-alert-offline.log
fi