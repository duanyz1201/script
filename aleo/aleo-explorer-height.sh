#!/bin/bash

exec 2>/dev/null

declare -A urlName
urlName=(
        [aleo]="https://api.explorer.provable.com/v1/mainnet/block/height/latest"
        [aleo123]="https://mainnet.aleo123.io/api/v5/mainnet/blocks/latest"

)

get_height() {
        result=$(curl -s --max-time 6 "${1}")
        if [[ -z "${result}" || ! "${result}" =~ ^[0-9]+$ ]];then
                return 1
        else
                echo "${result}"
        fi
}

for tag in "${!urlName[@]}"
do
        url="${urlName[$tag]}"
        height=$(get_height "${url}")
        echo "aleo_node_block,network=mainnet,source=${tag} height=${height:-0}"
done