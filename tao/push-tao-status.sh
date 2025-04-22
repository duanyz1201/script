#!/bin/bash

get_node_num() {
    local node_number
    cluster_name=$1
    node_number_response=$(curl -s --max-time 6 "http://172.28.56.119:8428/api/v1/query?query=tao_cluster_status_node_num%7Bcluster%3D%22${cluster_name}%22%7D")
    node_number=$(echo "${node_number_response}" | jq -r '.data.result[0].value[1]')
    if [[ -z "${node_number}" || ! "${node_number}" =~ ^[0-9]+$ ]]; then
        return 1
    else
        echo "${node_number}"
    fi
}

get_active_num() {
    local active_number
    cluster_name=$1
    active_number_response=$(curl -s --max-time 6 "http://172.28.56.119:8428/api/v1/query?query=tao_cluster_status_active%7Bcluster%3D%22${cluster_name}%22%7D")
    active_number=$(echo "${active_number_response}" | jq -r '.data.result[0].value[1]')
    if [[ -z "${active_number}" || ! "${active_number}" =~ ^[0-9]+$ ]]; then
        return 1
    else
        echo "${active_number}"
    fi
}

get_inactive_num() {
    local inactive_number
    cluster_name=$1
    inactive_number_response=$(curl -s --max-time 6 "http://172.28.56.119:8428/api/v1/query?query=tao_cluster_status_inactive%7Bcluster%3D%22${cluster_name}%22%7D")
    inactive_number=$(echo "${inactive_number_response}" | jq -r '.data.result[0].value[1]')
    if [[ -z "${inactive_number}" || ! "${inactive_number}" =~ ^[0-9]+$ ]]; then
        return 1
    else
        echo "${inactive_number}"
    fi
}


push_txt="sg-5
节点数：$(get_node_num sg-5)
活跃卡数：$(get_active_num sg-5)
不活跃卡数：$(get_inactive_num sg-5)

zw-20
节点数：$(get_node_num zw-20)
活跃卡数：$(get_active_num zw-20)
不活跃卡数：$(get_inactive_num zw-20)"

echo "${push_txt}"

curl -s 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=3104b1a7-8d98-4f9d-8a95-f44a8d29788f' \
   -H 'Content-Type: application/json' \
   -d '
   {
    	"msgtype": "text",
    	"text": {
        	"content": "'"${push_txt}"'"
    	}
   }'