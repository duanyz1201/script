#!/usr/bin/env bash

run() {
curl -s -X 'DELETE' 'http://'${IP}':7500/api/proxies?status=offline'

curl -s http://${IP}:7500/api/proxy/tcp > ${1}-tcp-list.log

#cat ${1}-tcp-list.log |jq -r .proxies[].conf.remotePort|awk '{print $0" ansible_host='${IP}' ansible_port="$0}' > ${1}-ip-list
cat ${1}-tcp-list.log |jq -r '.proxies[]|"\(.name) \(.conf.remotePort)"' |awk '{print $1" ansible_host='${IP}' ansible_port="$2}' > ${1}-ip-list

rm -f ${1}-tcp-list.log
}

case ${1} in
    sh)
        IP="47.116.221.100"
        run sh
        ;;
    sg)
        IP="47.236.92.49"
        run sg
        ;;
    *)
        echo "Usage: $0 {sh|sg}"
        exit 1
        ;;
esac