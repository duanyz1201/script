#!/bin/bash

file_name="${1}"
cluster_name="${2}"

if [[ -z ${1} && -z ${2} ]];then
    echo "Parameter not datedted"
    exit 1
fi

cat ${1} | jq --arg cluster_name "${2}" -r '.clusters[] | select (.name == $cluster_name)' &>/dev/null

if [[ $? -eq 0 ]];then
    echo "Parsing is successful, start checking the running status..."
else
    echo "Parsing failed"
    exit 1
fi

roles=$(cat ${1} | jq --arg cluster_name "${2}" -r '.clusters[] | select (.name == $cluster_name) | to_entries[] | .key')
cluster_info=$(cat ${1} | jq --arg cluster_name "${2}" -r '.clusters[] | select (.name == $cluster_name)')

test_tt() {
echo "========${role}========"
ips=$(echo ${cluster_info} | jq -r .${role}[])
for ip in ${ips}
do
    process_name=$(ssh -o LogLevel=ERROR ${ip} "ps -p \$(pgrep -fo ${1}) -o comm=")
    echo "${ip}: ${process_name}"
done
}

for role in ${roles}
do
    if [[ ${role} = name ]];then
        cluster_name=$(echo ${cluster_info} | jq -r .${role})
        echo "cluster_name: ${cluster_name}"
    elif [[ ${role} = ai3_node ]];then
        test_tt ai3-node
    elif [[ ${role} = nats_seed_nodes || ${role} = nats_nodes ]];then
        test_tt nats-server
    elif [[ ${role} = controller ]];then
        test_tt ai3-controller
    elif [[ ${role} = proof_server ]];then
        test_tt ai3-proof-server
    elif [[ ${role} = cache ]];then
        test_tt ai3-full-cache
        test_tt ai3-sharded-cache
    elif [[ ${role} = plot_server ]];then
        test_tt ai3-plot-server
    elif [[ ${role} = plot_client ]];then
        test_tt ai3-plot-client
    fi
done
