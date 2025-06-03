#!/usr/bin/env bash

# 使用 cat 从标准输入读取内容并将其存储到变量中
input=$(cat)

# 打印存储在变量中的内容
echo "$input" > /tmp/1.log

token=$(curl -s -X POST 'http://172.28.56.119:16000/api/n9e/auth/login' -d '{"username": "readonly", "password": "readonly"}'|jq -r .dat.access_token)
voice_disable=$(curl -s -H "Authorization: Bearer ${token}" 'http://172.28.56.119:16000/api/n9e/notify-channel'|jq -r '.dat[]|select(.ident == "voice")|.hide')

if [[ ${voice_disable} = "true" ]];then
        exit 0
fi

voice="false"
severity=$(echo ${input} | jq '.event.severity')
is_recovered=$(echo ${input} | jq '.event.is_recovered')

if [[ ${severity} != 1 || ${is_recovered} = true ]];then
        exit 0
fi

for ch in $(echo ${input} | jq -r .event.notify_channels[])
do
        if [[ ${ch} = voice ]];then
                voice="true"
        fi
done

if [[ ${voice} = false ]];then
        exit 0
fi

host=$(echo ${input} | jq -r .tpls.voice | awk -F '___' '{print $1}')
RuleName=$(echo ${input} | jq -r .tpls.voice | awk -F '___' '{print $2}')

for phone in $(echo ${input} | jq -r .event.notify_users_obj[].phone)
do
        if [[ $phone ]];then
                bash /data/n9e/etc/script/send-tx-voice.sh "${phone}" "${host}" "${RuleName}"
        fi
        sleep 1
done