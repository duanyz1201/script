#!/usr/bin/env bash

mkdir -p /etc/categraf/scripts/logs
log_file="/etc/categraf/scripts/logs/get-oort-machine-info.log"

log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date +"%FT%T.%3N")
    echo "$timestamp $level - $message" >> $log_file
}

check_dependency() {
    command -v $1 >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        log ERROR "Dependency $1 is not installed."
        apt-get update >/dev/null 2>&1
        if [[ $1 == "sensors" ]];then
            apt-get install -y lm-sensors >/dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                log ERROR "Failed to install lm-sensors."
                exit 1
            fi
            sensors-detect --auto >/dev/null 2>&1
        else
            apt-get install -y $1 >/dev/null 2>&1
        fi

        if [[ $? -ne 0 ]]; then
            log ERROR "Failed to install $1."
            exit 1
        else
            log INFO "Successfully installed $1."
        fi
    fi  
}
check_dependency curl
check_dependency jq
check_dependency sensors

if [[ ! -e "/tmp/oort_status.json" ]];then
    log ERROR "oort_status.json not found!"
    oort_status="unknown"
    oort_version="unknown"
    node_address="unknown"
    owner_address="unknown"
else
    oort_status=$(cat /tmp/oort_status.json | jq -r '.status')
    if [[ $? -ne 0 || -z $oort_status ]];then
        log ERROR "get oort status failed!"
        oort_status="unknown"
    fi
    oort_version=$(cat /tmp/oort_status.json | jq -r '.version')
    if [[ $? -ne 0 || -z $oort_version ]];then
        log ERROR "get oort version failed!"
        oort_version="unknown"
    fi
    node_address=$(cat /tmp/oort_status.json | jq -r '.node_address')
    if [[ $? -ne 0 || -z $node_address ]];then
        log ERROR "get oort node_address failed!"
        node_address="unknown"
    fi
    owner_address=$(cat /tmp/oort_status.json | jq -r '.owner_address')
    if [[ $? -ne 0 || -z $owner_address ]];then
        log ERROR "get oort owner_address failed!"
        owner_address="unknown"
    fi
fi

sensors_result=$(sensors -j)
if [[ $? -ne 0 || -z $sensors_result ]];then
    log ERROR "get sensors info failed!"
    cpu_temp="0"
else
    cpu_temp=$(echo $sensors_result | jq -r '."coretemp-isa-0000"."Package id 0"."temp1_input"')
    if [[ $? -ne 0 || -z $cpu_temp ]];then
        log ERROR "get cpu temp failed!"
        cpu_temp="0"
    fi
fi

manufacturer=$(dmidecode -s baseboard-manufacturer)
if [[ $? -ne 0 || -z $manufacturer ]];then
    log ERROR "get manufacturer failed!"
    manufacturer="unknown"
fi
product=$(dmidecode -s baseboard-product-name)
if [[ $? -ne 0 || -z $product ]];then
    log ERROR "get product failed!"
    product="unknown"
fi

if [[ $manufacturer == "unknown" && $product == "unknown" ]];then
    model="unknown"
else
    model="${manufacturer}-${product}"
fi

local_ip=$(ip route get 223.6.6.6 | head -n 1 | awk '{print $(NF-2)}')
if [[ $? -ne 0 || -z $local_ip ]];then
    log ERROR "get local ip failed!"
    local_ip="unknown"
fi

echo "oort_machine,model=$model,status=$oort_status,version=$oort_version,node_address=$node_address,owner_address=$owner_address,ip=$local_ip cpu_temp=$cpu_temp"