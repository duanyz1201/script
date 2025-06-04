#!/bin/bash

toparty="${1}"
subject="${2}"
body="${3}"
agentid="${4}"

token_dir="/tmp/send-wechat"
token_file="${token_dir}/token-${agentid}.log"
log_file="${token_dir}/send-wechat.log"

if [[ ! -e "${token_dir}" ]];then
        mkdir -p ${token_dir}
fi

corpid="wwcfc34b3af1eaf097"
date_time=$(date "+%Y-%m-%d %H:%M:%S")
current_time=$(date +%s)

declare -A secret
secret=(
        [1000002]="0ctPqc31s2DOFQUZNAcs5zmFW4ham3ZbJZXYlHVQY98"         #zabbix_P1
        [1000003]="kxWLYc5hqZfwa-L3GMnEZ8V_MiOmmUgENA7ER7hDIP0"         #Subspace
        [1000004]="hrrU8sT82o1L7b8m5e0qI0Sb1wnZzzJupgW3984dKzs"         #Google
        [1000005]="ZgCV7sdd35TpgCrZD3uQRveZfdN0AHX4rQq2X_ZK5Ik"         #服务器
        [1000006]="6wDH5DFh6co0JyzsZAY8lE43ZSaLIR4oXQrtkiaADQM"         #交换机
        [1000007]="klZVmoH2-Wq0gk5UmgR_gLfmDKOWLfniISfrDgg9Rps"         #VMware
        [1000008]="VRI4pCTbFHE1Elq9v6mR8lC98l_1OIUf1YaMM2uxZkc"         #SpaceMesh
        [1000009]="NPV61hxORinfj5Sditl4ZEB5nddHqm7SR0eKohB6geM"         #qubic
        [1000010]="GbouM_4DxZyGhgtJZsPXvW8dbZ0qGl3zomYtLObe0eU"         #进程监控
        [1000011]="lk4LLjL5QeTaxlLjzUaDau7iDSc_GPMpkIHpI5pYIPg"         #Node
)

get_token(){
        if [[ -f "${token_file}" ]];then
                expires_in=$(jq -r .expires_in ${token_file})
                create_time=$(jq -r .create_time ${token_file})
                extime=$((${expires_in}+${create_time}))
                if [[ ${current_time} -gt ${extime} ]];then
                        token_url="https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=${corpid}&corpsecret=${secret[$agentid]}"
                        response=$(curl -s ${token_url}|jq      '. + {create_time: '$current_time'}')
                        if [[ $(jq -r .errcode <<<"${response}") -eq 0 ]];then
                                echo ${response} > ${token_file}
                                echo "${date_time} INFO get_token: update ${agentid} token success" >> ${log_file}
                        else
                                echo "${date_time} ERROR get_token: update ${agentid} token failed ${response}" >> ${log_file}
                                exit 1
                        fi
                fi
        else
                token_url="https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=${corpid}&corpsecret=${secret[$agentid]}"
                response=$(curl -s ${token_url}|jq      '. + {create_time: '$current_time'}')
                if [[ $(jq -r .errcode <<<"${response}") -eq 0 ]];then
                        echo ${response} > ${token_file}
                        echo "${date_time} INFO get_token: get ${agentid} token success" >> ${log_file}
                else
                        echo "${date_time} ERROR get_token: get ${agentid} token failed ${response}" >> ${log_file}
                        exit 1
                fi
        fi
}

json_body(){
        jq -n --arg toparty "${toparty}" --arg agentid "${agentid}" --arg subject "${subject}" --arg body "${body}" '{
                toparty: $toparty,
                msgtype: "text",
                agentid: $agentid,
                text: {
                        content: "\($subject)\n\($body)"
                },
                safe: "0"
        }'
}

get_token

access_token=$(jq -r .access_token ${token_file})
post_url="https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=${access_token}"
response=$(curl -s -H "Content-Type: application/json" -X POST -d "$(json_body)" ${post_url})

if [[ $(jq -r .errcode <<<"${response}") -eq 0 ]];then
        echo "${date_time} INFO send_message: ${agentid} message send success" >> ${log_file}
else
        echo "${date_time} ERROR send_message: ${agentid} message send failed" >> ${log_file}
        exit 1
fi
