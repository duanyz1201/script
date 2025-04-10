#!/bin/bash

MinerID="f01159754"
MinerID_conver="${MinerID/f/t}"
start_sector="0"
end_sector="4822540"

fcfs_path="/fcfs_srgj_f01159754"

logs_info="${MinerID}-expire-info.log"
logs_error="${MinerID}-expire-error.log"
logs_expire_sectors_list="${MinerID}-expire-sectors-list.log"

if [[ -z ${1} || ! -f ${1} ]];then
        echo "Usage: $0 <sector_list_file>"
        exit 1
fi

> ${logs_info}
> ${logs_error}
> ${logs_expire_sectors_list}

get_Expiration() {
result=$(curl -s --max-time 5 -X POST 'http://127.0.0.1:1234/rpc/v0' -H "Content-Type: application/json" --data '{
  "jsonrpc":"2.0",
  "method":"Filecoin.StateSectorGetInfo",
  "params":[
     "'${MinerID}'",
     '${1}',
     [
       {
         "/": "bafy2bzacedynnzr2nkysmifuy3cssc2k3l6t2ni4as2yv6gllzuaqwevkwlb6"
       },
       {
         "/": "bafy2bzacedynnzr2nkysmifuy3cssc2k3l6t2ni4as2yv6gllzuaqwevkwlb6"
       }
     ]
  ],
  "id":7878
}')

Expiration_height=$(echo ${result} | jq -r '.result.Expiration')
if [[ -n ${Expiration_height} || ${Expiration_height} =~ ^[0-9]+$ ]];then
        if [[ ${Expiration_height} -lt ${end_sector} ]];then
                echo "${fcfs_path}/sealed/s-${MinerID_conver}-${1}" | tee -a ${logs_info}
                echo "${fcfs_path}/cache/s-${MinerID_conver}-${1}/p_aux" | tee -a ${logs_info}
                echo "${fcfs_path}/cache/s-${MinerID_conver}-${1}/sc-02-data-tree-r-last-0.dat" | tee -a ${logs_info}
                echo "${fcfs_path}/cache/s-${MinerID_conver}-${1}/sc-02-data-tree-r-last-1.dat" | tee -a ${logs_info}
                echo "${fcfs_path}/cache/s-${MinerID_conver}-${1}/sc-02-data-tree-r-last-2.dat" | tee -a ${logs_info}
                echo "${fcfs_path}/cache/s-${MinerID_conver}-${1}/sc-02-data-tree-r-last-3.dat" | tee -a ${logs_info}
                echo "${fcfs_path}/cache/s-${MinerID_conver}-${1}/sc-02-data-tree-r-last-4.dat" | tee -a ${logs_info}
                echo "${fcfs_path}/cache/s-${MinerID_conver}-${1}/sc-02-data-tree-r-last-5.dat" | tee -a ${logs_info}
                echo "${fcfs_path}/cache/s-${MinerID_conver}-${1}/sc-02-data-tree-r-last-6.dat" | tee -a ${logs_info}
                echo "${fcfs_path}/cache/s-${MinerID_conver}-${1}/sc-02-data-tree-r-last-7.dat" | tee -a ${logs_info}
                echo "${fcfs_path}/cache/s-${MinerID_conver}-${1}/t_aux" | tee -a ${logs_info}
                echo "${1}" | tee -a ${logs_expire_sectors_list}
        else
                echo "MinerID: ${MinerID}, SectorID: ${1} Not expired" | tee -a ${logs_error}
        fi
else
        echo "get Expiration failed!" | tee -a ${logs_error}
        return 1
fi
}

for i in $(cat ${1} | awk -F ':' '{print $1}')
do
        get_Expiration ${i}
done
