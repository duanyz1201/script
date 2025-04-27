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

get_inactive_gpu_num() {
    local inactive_gpu_number
    cluster_name=$1
    inactive_gpu_number_response=$(curl -s --max-time 6 "http://172.28.56.119:8428/api/v1/query?query=tao_cluster_status_inactive_gpu_num%7Bcluster%3D%22${cluster_name}%22%7D")
    inactive_gpu_number=$(echo "${inactive_gpu_number_response}" | jq -r '.data.result[0].value[1]')
    if [[ -z "${inactive_gpu_number}" || ! "${inactive_gpu_number}" =~ ^[0-9]+$ ]]; then
        return 1
    else
        echo "${inactive_gpu_number}"
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

for label in sg-5 zw-20 sc-07 sc-11 ws-01 ws-02; do
    
    node_num=$(get_node_num "${label}")
    inactive_gpu_num=$(get_inactive_gpu_num "${label}")
    active_num=$(get_active_num "${label}")
    inactive_num=$(get_inactive_num "${label}")

push_txt+="集群: ${label}
节点数: ${node_num}
未分配模型卡数: ${inactive_gpu_num}
已验证: ${active_num}
未验证: ${inactive_num}
------------------------\n"
done

echo "${push_txt%*\\n}"

curl -s 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=3104b1a7-8d98-4f9d-8a95-f44a8d29788f' \
   -H 'Content-Type: application/json' \
   -d '
   {
    	"msgtype": "text",
    	"text": {
        	"content": "'"${push_txt}"'"
    	}
   }'