#!/usr/bin/env bash

log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date +"%FT%T.%3N")
    echo "$timestamp $level - $message" >> "${log_file}"
}

log_file="/etc/categraf/scripts/logs/lotus-height-diff.log"
init_Timestamp="1598306400"
curr_Timestamp=$(date +%s)
Height=$(( ($curr_Timestamp - $init_Timestamp) / 30))

# lotus_height_diff
# 0   ok
# -1  null value
# -2  unknown value
# -3  lotus daemon not running

if ! pgrep -x lotus >/dev/null;then
    echo "lotus_height diff=-3"
    log ERROR "lotus daemon not running, diff=-3"
    exit 0
fi

curr_Height=$(curl -s --max-time 5 -X POST -H "Content-Type: application/json" --data '{ "jsonrpc":"2.0","method":"Filecoin.ChainHead","params":[],"id":1 }' 'http://127.0.0.1:1234/rpc/v0'|jq '.result.Height')

log INFO "ExpectedHeight=${Height} CurrentHeight=${curr_Height}"

if [[ "$curr_Height" != 'null' && "$curr_Height" != '0' && ! -z "${curr_Height}" ]];then
        Height_diff=$(( Height - curr_Height ))
        echo "lotus_height diff=${Height_diff}"
        log INFO "lotus_height_diff=${Height_diff}"
else
    if [[ -z ${curr_Height} ]];then
        Height_diff="-1"
        echo "lotus_height diff=${Height_diff}"
        log ERROR "lotus_height_diff=${Height_diff}"
    else
        Height_diff="-2"
        echo "lotus_height diff=${Height_diff}"
        log ERROR "lotus_height_diff=${Height_diff}"
    fi
fi