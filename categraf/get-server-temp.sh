#!/bin/bash

USERNAME="root"
PASSWORD="calvin"
TIMEOUT=6
RETRY=3
LOG_FILE="/etc/categraf/scripts/logs/server_temp.log"

log() {
    local level=$1
    local message=$2
    echo "$(date '+%FT%T.%3N') ${level} $message" >> $LOG_FILE
}

IP=("172.20.1.103" "172.20.1.105")

curl_temp() {
    local ip=${1}
    if [[ -z $ip ]]; then
        log "ERROR" "IP address is empty"
        return 1
    fi

    local start_time=$(date +%s.%N)
    local response=$(curl -k -s --max-time $TIMEOUT --retry $RETRY -u "$USERNAME:$PASSWORD" "https://${ip}/redfish/v1/Chassis/System.Embedded.1/Sensors/Temperatures/iDRAC.Embedded.1%23SystemBoardInletTemp")
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to connect to $ip"
        return 1
    fi
    local end_time=$(date +%s.%N)
    local elapsed_time=$(echo "$end_time $start_time" | awk '{printf "%.2f", $1 - $2}')

    local temp=$(echo "$response" | jq '.ReadingCelsius')
    if [[ ! ${temp} =~ [0-9]+ ]]; then
        log "ERROR" "Failed to get temperature from $ip, curl_time: ${elapsed_time}s"
        return 1
    else
        echo "${temp}"
        log "INFO" "Temperature from $ip ${temp}°C, curl_time: ${elapsed_time}s"
    fi
}

for bmc_ip in "${IP[@]}"
do
    temp=$(curl_temp "${bmc_ip}")
    if [[ $? -ne 0 ]]; then
        continue
    fi
    echo "server_bmc_info,ip=${bmc_ip},type=inletTemp temp=${temp}"
    if [[ ${temp} -gt 40 ]]; then
        log "WARNING" "High temperature from $bmc_ip: ${temp}°C"
    fi
done