#!/usr/bin/env bash

log_file="/etc/categraf/scripts/logs/get-n9e-server-num.log"

log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date +"%FT%T.%3N")
    echo "$timestamp $level - $message" >> $log_file
}

Token=$(curl -s -X POST 'http://172.28.56.119:16000/api/n9e/auth/login' -d '{"username": "readonly", "password": "readonly"}'|jq -r .dat.access_token)
if [[ $? != 0 || -z $Token ]];then
    log ERROR "get token failed!"
    exit 1
fi

oort_alert=$(curl -s "http://172.28.56.119:16000/api/n9e/alert-cur-events/list?p=1&limit=30&bgid=16&rule_prods=host" -H "Authorization: Bearer $Token")
if [[ $? != 0 || -z $oort_alert ]];then
    log ERROR "get oort alert failed!"
    exit 1
else
    echo $oort_alert | jq -r '.dat.list[]|{target_ident, first_trigger_time}' > /usr/share/nginx/html/oort-alert-offline.log
fi

result=$(curl -s -H "Authorization: Bearer ${Token}" 'http://172.28.56.119:16000/api/n9e/targets?query=&gids=16&limit=10000&p=1')
if [[ $? != 0 || -z $result ]];then
    log ERROR "get n9e server num failed!"
    exit 1
fi

oortNodes=$(curl -s --max-time 6 --retry 2 'https://console.oortech.com/info_api/nodes/geo')
if [[ $? != 0 || -z $oortNodes ]];then
    log ERROR "get oort edge nodes failed!"
    exit 1
fi

superNode_num=$(echo $oortNodes | jq -r '[.data.superNodesCountry[].num]|add')
if [[ $? != 0 || -z $superNode_num ]];then
    log ERROR "get oort super nodes failed!"
    exit 1
fi

backupNode_num=$(echo $oortNodes | jq -r '[.data.backupNodes[].num]|add')
if [[ $? != 0 || -z $backupNode_num ]];then
    log ERROR "get oort backup nodes failed!"
    exit 1
fi

edgeNode_num=$(echo $oortNodes | jq -r '[.data.edgeNodes[].num]|add')
if [[ $? != 0 || -z $edgeNode_num ]];then
    log ERROR "get oort edge nodes failed!"
    exit 1
fi

# total_num=$(echo $result | jq -r '.dat.list|length')
idc_list=$(echo $result | jq -r '.dat.list[].tags_maps.region'|sort |uniq)

declare -A MachineNum
for idc in $idc_list;do
    num=$(echo $result | jq -r --arg idc "$idc" '[.dat.list[]|select(.tags_maps.region == $idc)]|length')
    MachineNum[$idc]=$num
done

for idc in $idc_list;do
    echo "oort_machine,idc=$idc num=${MachineNum[$idc]}"
done

echo "oort_machine,idc=edgeNodes num=$edgeNode_num"
echo "oort_machine,idc=superNodes num=$superNode_num"
echo "oort_machine,idc=backupNodes num=$backupNode_num"