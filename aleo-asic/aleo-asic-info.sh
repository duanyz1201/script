#!/bin/bash

exec 2>/dev/null

start_time=$(date +%s)

log_file="/etc/categraf/scripts/logs/aleo-asic-info.log"

log_info() {
        echo "[INFO] [$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${log_file}"
}

log_error() {
        echo "[ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${log_file}"
}

log_info "Start checking..."

if [[ ! -f "$1" ]]; then
    echo "Usage: $0 ip_list_file"
    exit 1
fi

get_token() {
    local result token
    result=$(curl -s --max-time 0.2 --retry 2 'http://'${1}'/user/login?username=admin&password=123456789')

    token=$(echo ${result} | jq -r '."JWT Token"')
    if [[ -z ${token} ]];then
        log_error "Get Token Failed for ${1}"
        return 1
    fi
    echo "${token}"
}

get_state() {
    local token
    token=$(get_token ${1})
    if [[ -z "${token}" ]]; then
            return 1
    fi

    result=$(curl -s --max-time 0.2 --retry 2 'http://'${1}'/mcb/state' -H 'Authorization: Bearer '${token}'')
    echo ${result} | jq &>/dev/null
    if [[ $? != 0 ]];then
        log_error "get state info failed for ${1}"
        return 1
    fi

    setting_result=$(curl -s --max-time 0.2 --retry 2 'http://'${1}'/mcb/setting' -H 'Authorization: Bearer '${token}'')
    echo ${setting_result} | jq &>/dev/null
    if [[ $? != 0 ]];then
        log_error "get setting info failed for ${1}"
        return 1
    fi

    ip=$(echo ${result} | jq -r '.ip')
    mac=$(echo ${setting_result} | jq -r '.name' | tr -d ':')
    model=$(echo ${result} | jq -r '.model' | sed 's/ /_/g')
    version=$(echo ${result} | jq -r '.version')
    uptime=$(( $(echo ${result} | jq -r '.elapsed') * 60 ))
    powerplan=$(echo ${result} | jq -r '.powerplan')
    temp_box=$(echo ${result} | jq -r '.temp_box | split(" / ") | .[0]')
    hr5s=$(echo ${result} | jq -r '.hr5s' | awk '{printf "%.3f", $0}')
    hwer=$(echo ${result} | jq -r '.hwer')
    rjr=$(echo ${result} | jq -r '.rjr' | awk '{printf "%.3f", $0}')
    fan0=$(echo ${result} | jq -r '.fan | split(" / ") | .[0]')
    fan1=$(echo ${result} | jq -r '.fan | split(" / ") | .[1]')

    echo "aleo_asic,region=HA,mac=${mac},ip=${ip},model=${model},version=${version} uptime=${uptime},powerplan=${powerplan},temp_box=${temp_box},hr5s=${hr5s},hwer=${hwer},rjr=${rjr},fan0=${fan0},fan1=${fan1}"

    return 0
}

max_jobs=100
success_count=0
fail_count=0
total_count=0

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

while read -r i; do
    (
        if get_state "${i}"; then
            echo "success" > "${temp_dir}/${i}.status"
        else
            echo "fail" > "${temp_dir}/${i}.status"
        fi
    ) &

    if [[ $(jobs -r | wc -l) -ge $max_jobs ]]; then
        wait -n
    fi

    ((total_count++))
done < "${1}"

wait

success_count=$(grep -l "success" "${temp_dir}"/*.status | wc -l)
fail_count=$(grep -l "fail" "${temp_dir}"/*.status | wc -l)

end_time=$(date +%s)
took=$((end_time - start_time))

log_info "Total: ${total_count}, Success: ${success_count}, Fail: ${fail_count}, took: ${took}s"