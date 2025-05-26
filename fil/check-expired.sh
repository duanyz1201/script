#!/usr/bin/env bash

MinerID="f01159754"
MinerID_conver="${MinerID/f/t}"
# start_sector="4867667"
end_height="4995820"

fcfs_path="/fcfs_srgj_f01159754_clear"

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

chain_head=$(lotus chain head |tail -n 1)
if [[ -z ${chain_head} ]];then
        echo "$(date '+%FT%T.%3N') Failed to get chain head!"
        exit 1
fi

get_Expiration() {
sector_id=${1}
if [[ -z ${sector_id} ]];then
        echo "$(date '+%FT%T.%3N') ${sector_id} is empty!" | tee -a ${logs_error}
        return 1
fi
if [[ ! ${sector_id} =~ ^[0-9]+$ ]];then
        echo "$(date '+%FT%T.%3N') ${sector_id} is not a number!" | tee -a ${logs_error}
        return 1
fi

result=$(curl -s --max-time 5 -X POST 'http://127.0.0.1:1234/rpc/v0' -H "Content-Type: application/json" --data '{
  "jsonrpc":"2.0",
  "method":"Filecoin.StateSectorGetInfo",
  "params":[
     "'${MinerID}'",
     '${sector_id}',
     [
       {
         "/": "'$chain_head'"
       }
     ]
  ],
  "id":7878
}')

if [[ -z "${result}" ]]; then
    echo "$(date '+%FT%T.%3N') ${sector_id} curl request failed!" | tee -a ${logs_error}
    return 1
fi

Expiration_height=$(echo ${result} | jq -r '.result.Expiration')
if [[ -z "${Expiration_height}" || "${Expiration_height}" == "null" ]]; then
    echo "$(date '+%FT%T.%3N') ${sector_id} Expiration field missing or invalid!" | tee -a ${logs_error}
    return 1
fi

if [[ -n ${Expiration_height} && ${Expiration_height} =~ ^[0-9]+$ ]];then
        if [[ ${Expiration_height} -lt ${end_height} ]];then
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
                echo "$(date '+%FT%T.%3N') MinerID: ${MinerID}, SectorID: ${1} Not expired" | tee -a ${logs_error}
        fi
else
        echo "$(date '+%FT%T.%3N') ${1} get Expiration failed!" | tee -a ${logs_error}
        return 1
fi
}

for i in $(cat ${1} | awk -F ',' '{print $1}')
do
        get_Expiration ${i}
done
